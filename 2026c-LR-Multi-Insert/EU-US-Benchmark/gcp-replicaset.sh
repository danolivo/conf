#!/bin/bash
#
# Sets up logical replication between two GCP VM instances:
#   Publisher:  danolivo-eu  (europe-west1-d)
#   Subscriber: danolivo-usa (us-west1-b)
#
# Assumes:
#   - gcloud CLI configured, SSH works without password
#   - ~/pgdev is the PostgreSQL source repo on each VM
#   - pre, mk, paths.sh scripts are available on each VM (same as local)
#   - Run this script from your local machine
#
set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────
PUB_VM="danolivo-eu"
PUB_ZONE="europe-west1-d"
SUB_VM="danolivo-usa"
SUB_ZONE="us-west1-b"

DBNAME="danolivo"
DBUSER="danolivo"
DBPASS='bZx7!mQ2nL9w'
PGPORT=5432

# Remote PostgreSQL source directory
PGDEV="\$HOME/pgdev"
# Data directories (created by this script, not by pre)
PUB_PGDATA="\$HOME/pgdev/pgdata_publisher"
SUB_PGDATA="\$HOME/pgdev/pgdata_subscriber"

# ── Helpers ────────────────────────────────────────────────────────
# SCRIPTS_DIR is discovered at startup (see below).
build_remote_env() {
    echo "
export PATH=$SCRIPTS_DIR:\$PATH
cd $PGDEV
. paths.sh
"
}

ssh_pub() { gcloud compute ssh "$PUB_VM" --zone="$PUB_ZONE" --command="$(build_remote_env)"$'\n'"$1"; }
ssh_sub() { gcloud compute ssh "$SUB_VM" --zone="$SUB_ZONE" --command="$(build_remote_env)"$'\n'"$1"; }

# ── Ensure VMs are running ─────────────────────────────────────────
ensure_vm_running() {
    local vm=$1 zone=$2
    local status
    status=$(gcloud compute instances describe "$vm" --zone="$zone" \
        --format='get(status)')
    case "$status" in
        RUNNING)
            echo "$vm ($zone): already running."
            ;;
        TERMINATED|STOPPED|SUSPENDED|STAGING)
            echo "$vm ($zone): status is $status — starting..."
            gcloud compute instances start "$vm" --zone="$zone" --quiet
            echo "$vm ($zone): started."
            ;;
        *)
            echo "FATAL: $vm ($zone) is in unexpected state: $status" >&2
            exit 1
            ;;
    esac
}

echo "=== Checking VM status ==="
ensure_vm_running "$PUB_VM" "$PUB_ZONE"
ensure_vm_running "$SUB_VM" "$SUB_ZONE"

# Wait for SSH to become available after a cold start
wait_for_ssh() {
    local vm=$1 zone=$2
    local max_attempts=30
    echo -n "  $vm: "
    for i in $(seq 1 $max_attempts); do
        if gcloud compute ssh "$vm" --zone="$zone" --command="true" \
            --ssh-flag="-o ConnectTimeout=10" \
            --ssh-flag="-o StrictHostKeyChecking=no" 2>/dev/null; then
            echo "OK (attempt $i)"
            return 0
        fi
        echo -n "."
        sleep 5
    done
    echo " FAILED after $max_attempts attempts"
    echo "FATAL: cannot SSH into $vm ($zone)" >&2
    exit 1
}

echo "Waiting for SSH on both VMs..."
wait_for_ssh "$PUB_VM" "$PUB_ZONE"
wait_for_ssh "$SUB_VM" "$SUB_ZONE"

# ── Discover where mk/pgc/pre scripts live on the remote VMs ──────
echo "Locating build scripts on $PUB_VM..."
SCRIPTS_DIR=$(gcloud compute ssh "$PUB_VM" --zone="$PUB_ZONE" \
    --command="find \$HOME -maxdepth 3 -name mk -type f 2>/dev/null | head -1 | xargs dirname")
if [ -z "$SCRIPTS_DIR" ] || [ "$SCRIPTS_DIR" = "." ]; then
    echo "FATAL: could not locate 'mk' on $PUB_VM" >&2
    exit 1
fi
echo "Scripts directory on remote VMs: $SCRIPTS_DIR"

# ── Discover external IPs ──────────────────────────────────────────
PUB_HOST=$(gcloud compute instances describe "$PUB_VM" \
    --zone="$PUB_ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
SUB_HOST=$(gcloud compute instances describe "$SUB_VM" \
    --zone="$SUB_ZONE" --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
echo "Publisher external IP:  $PUB_HOST"
echo "Subscriber external IP: $SUB_HOST"

# ── Run 'pre' on both machines (build, init, configure, start) ─────
# 'pre' handles: kill old processes, mk (build), initdb, basic config,
# listen_addresses, pg_hba for external access, pg_ctl start, createdb,
# ALTER USER ... PASSWORD.
echo "=== Running 'pre' on publisher ==="
ssh_pub "cd $PGDEV && pre" &
PUB_PRE_PID=$!
echo "=== Running 'pre' on subscriber ==="
ssh_sub "cd $PGDEV && pre" &
SUB_PRE_PID=$!
wait $PUB_PRE_PID || { echo "FATAL: 'pre' failed on publisher"; exit 1; }
echo "Publisher: pre completed."
wait $SUB_PRE_PID || { echo "FATAL: 'pre' failed on subscriber"; exit 1; }
echo "Subscriber: pre completed."

# ── Verify external connectivity to both nodes ────────────────────
echo "=== Verifying external connections ==="
export PGPASSWORD="$DBPASS"

echo -n "  Publisher ($PUB_HOST): "
if psql -h "$PUB_HOST" -p "$PGPORT" -U "$DBUSER" -d "$DBNAME" -c "SELECT 1" >/dev/null 2>&1; then
    echo "OK"
else
    echo "FAILED"
    echo "FATAL: cannot connect to publisher at $PUB_HOST:$PGPORT from this machine" >&2
    echo "Check that GCP firewall allows TCP/$PGPORT inbound and pg_hba.conf is correct." >&2
    exit 1
fi

echo -n "  Subscriber ($SUB_HOST): "
if psql -h "$SUB_HOST" -p "$PGPORT" -U "$DBUSER" -d "$DBNAME" -c "SELECT 1" >/dev/null 2>&1; then
    echo "OK"
else
    echo "FAILED"
    echo "FATAL: cannot connect to subscriber at $SUB_HOST:$PGPORT from this machine" >&2
    echo "Check that GCP firewall allows TCP/$PGPORT inbound and pg_hba.conf is correct." >&2
    exit 1
fi

unset PGPASSWORD

# ── Create bench tables ───────────────────────────────────────────
TABLE_DDL="
CREATE TABLE IF NOT EXISTS bench_copy (
    id bigint PRIMARY KEY,
    val double precision,
    payload text,
    ts timestamptz
);
CREATE TABLE IF NOT EXISTS bench_insert (LIKE bench_copy INCLUDING ALL);
"

echo "=== Creating tables on publisher ==="
ssh_pub "psql -p $PGPORT -U $DBUSER -d $DBNAME -c \"$TABLE_DDL\""

echo "=== Creating tables on subscriber ==="
ssh_sub "psql -p $PGPORT -U $DBUSER -d $DBNAME -c \"$TABLE_DDL\""

# ── Publication & Subscription ─────────────────────────────────────
echo "=== Creating publication on publisher ==="
ssh_pub "psql -p $PGPORT -U $DBUSER -d $DBNAME -c \
    \"CREATE PUBLICATION bench_pub FOR ALL TABLES\""

echo "=== Creating subscription on subscriber ==="
CONNINFO="host=$PUB_HOST port=$PGPORT dbname=$DBNAME user=$DBUSER password=$DBPASS"
ssh_sub "psql -p $PGPORT -U $DBUSER -d $DBNAME -c \
    \"CREATE SUBSCRIPTION bench_sub CONNECTION '$CONNINFO' PUBLICATION bench_pub WITH (streaming = false, multi_insert = true)\""

echo ""
echo "=== Done! ==="
echo "Publisher:  $PUB_VM ($PUB_HOST:$PGPORT)"
echo "Subscriber: $SUB_VM ($SUB_HOST:$PGPORT)"
echo ""
echo "Connect from your machine:"
echo "  export PGPASSWORD='$DBPASS'"
echo "  psql -h $PUB_HOST -p $PGPORT -U $DBUSER -d $DBNAME   # publisher"
echo "  psql -h $SUB_HOST -p $PGPORT -U $DBUSER -d $DBNAME   # subscriber"
echo ""
echo "Quick replication check:"
echo "  psql -h $SUB_HOST -p $PGPORT -U $DBUSER -d $DBNAME -c 'SELECT * FROM pg_stat_subscription'"

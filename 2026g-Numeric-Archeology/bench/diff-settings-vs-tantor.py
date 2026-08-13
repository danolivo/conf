#!/usr/bin/env python3
"""
Compare a pgdev cluster's live settings against the Tantor SE 1C install.

Tantor's real configuration lives in postgresql.auto.conf (applied with ALTER
SYSTEM), not postgresql.conf, so both are read and auto.conf wins.

Values are compared after asking the target server for its own units, because
that is where hand comparison goes wrong: Tantor writes shared_buffers as
'8GB' while pg_settings reports 1048576 in units of 8kB, and eyeballing those
as equal is exactly the mistake this script exists to prevent.

Usage: diff-settings-vs-tantor.py PSQL PORT [TANTOR_DATA_DIR]
"""
import re
import subprocess
import sys

PSQL = sys.argv[1]
PORT = sys.argv[2]
TDIR = sys.argv[3] if len(sys.argv) > 3 else \
    "/var/lib/postgresql/tantor-se-1c-17/data"

# Documented, deliberate exclusions -- see conf.d/10-1c.conf on the target.
SE_ONLY = {
    "default_statistics_target_temp_tables",
    "enable_delayed_temp_file",
    "enable_filter_predicates_reordering",
    "enable_index_path_selectivity",
}
BROKEN_AT_SOURCE = {"temp_tablespaces"}
# Ours, not theirs, and each one is a difference to remember when comparing.
OURS = {"jit", "io_method", "port"}

SIZE = {"kb": 1024, "mb": 1024 ** 2, "gb": 1024 ** 3, "tb": 1024 ** 4,
        "b": 1, "8kb": 8192, "16kb": 16384, "32kb": 32768, "64kb": 65536}
TIME = {"us": 1e-3, "ms": 1, "s": 1000, "min": 60000, "h": 3600000,
        "d": 86400000}


def sh(cmd):
    p = subprocess.run(cmd, shell=True, text=True, capture_output=True)
    if p.returncode != 0:
        sys.exit(f"failed: {cmd}\n{p.stderr}")
    return p.stdout


def read_conf(path):
    """name -> raw value, later assignments winning, as the server does."""
    out = {}
    for line in sh(f"sudo cat {path} 2>/dev/null").splitlines():
        line = line.split("#", 1)[0].strip()
        m = re.match(r"^([A-Za-z_.0-9]+)\s*=\s*(.+)$", line)
        if not m:
            continue
        val = m.group(2).strip().strip("'")
        out[m.group(1)] = val
    return out


def to_number(val, unit):
    """Normalise a config value into the parameter's own unit, or None."""
    val = val.strip().strip("'")
    m = re.match(r"^(-?[\d.]+)\s*([A-Za-z]*)$", val)
    if not m:
        return None
    num = float(m.group(1))
    suffix = m.group(2).lower()
    unit = (unit or "").lower()

    if unit in SIZE:
        base = SIZE[suffix] if suffix in SIZE else (SIZE[unit] if not suffix else None)
        if base is None:
            return None
        return num * base / SIZE[unit]
    if unit in TIME:
        base = TIME[suffix] if suffix in TIME else (TIME[unit] if not suffix else None)
        if base is None:
            return None
        return num * base / TIME[unit]
    if suffix:                      # value has a unit but the parameter has none
        return None
    return num


def main():
    tantor = read_conf(f"{TDIR}/postgresql.conf")
    tantor.update(read_conf(f"{TDIR}/postgresql.auto.conf"))   # auto.conf wins
    if not tantor:
        sys.exit(f"no settings read from {TDIR} -- wrong path, or no sudo?")

    rows = sh(f"sudo -u postgres {PSQL} -p {PORT} -d postgres -Atc "
              '"select name || \'|\' || setting || \'|\' || coalesce(unit,\'\') '
              'from pg_settings"')
    # Keyed lower-case: pg_settings spells a few parameters in mixed case
    # (DateStyle, TimeZone, IntervalStyle) while a config file may use any case,
    # and the server itself is case-insensitive about parameter names.
    live = {}
    for line in rows.splitlines():
        parts = line.split("|")
        if len(parts) == 3:
            live[parts[0].lower()] = (parts[0], parts[1], parts[2])

    same, diff, missing, excluded = [], [], [], []
    for name, want in sorted(tantor.items()):
        if name in SE_ONLY:
            excluded.append((name, want, "Tantor SE extension, absent here"))
            continue
        if name in BROKEN_AT_SOURCE:
            excluded.append((name, want, "broken at the source; Tantor itself "
                                         "falls back to pg_default"))
            continue
        if name.lower() not in live:
            missing.append((name, want))
            continue
        _, got, unit = live[name.lower()]
        a, b = to_number(want, unit), to_number(got, unit)
        if a is not None and b is not None:
            equal = abs(a - b) < 1e-9
        else:
            equal = want.strip().strip("'").lower() == got.strip().lower()
        note = " (ours, deliberate)" if name in OURS else ""
        (same if equal else diff).append(
            (name, want, got + (f" {unit}" if unit else "") + note))

    def show(title, items, cols):
        print(f"\n## {title}: {len(items)}")
        if not items:
            return
        w = max(len(i[0]) for i in items)
        for i in items:
            print("  " + i[0].ljust(w) + "  " + "  ".join(str(c) for c in i[1:]))

    print(f"Tantor settings read: {len(tantor)}  "
          f"(postgresql.conf + postgresql.auto.conf, auto.conf winning)")
    show("MATCH", same, 2)
    show("DIFFER", diff, 2)
    show("NOT PRESENT in this build", missing, 1)
    show("EXCLUDED on purpose", excluded, 2)

    print(f"\nverdict: {len(same)} match, {len(diff)} differ, "
          f"{len(missing)} absent, {len(excluded)} excluded on purpose")
    return 0


if __name__ == "__main__":
    sys.exit(main())

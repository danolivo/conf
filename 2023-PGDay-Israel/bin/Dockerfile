FROM postgres:15.0-bullseye
COPY ./sr_plan/sr_plan.so /usr/lib/postgresql/15/lib/
COPY ./sr_plan/sr_plan.control /usr/share/postgresql/15/extension/
COPY ./sr_plan/sr_plan--0.1.sql /usr/share/postgresql/15/extension/
COPY ./sr_plan/sr_plan--0.1--0.2.sql /usr/share/postgresql/15/extension/
COPY ./sr_plan/add_srplan.sh /docker-entrypoint-initdb.d/

EXPOSE 5432
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["postgres"]

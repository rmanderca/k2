
exec drop_package('statzilla_version');
exec drop_package('statzilla_b');
@statzilla_patch.sql
@statzilla_schema.sql
@statzilla_pkgh.sql
@statzilla_pkgb.sql
@statzilla_trg.sql
@statzilla_get_oracle_metrics.sql
@statzilla_scheduler_jobs.sql

select 'Statzilla install complete.' message from dual;

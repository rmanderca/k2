

@arcsql_schema_support.sql
@arcsql_schema.sql 
@arcsql_send_email_prc.sql
@arcsql_pkgh.sql 
@arcsql_pkgb.sql 
alter package arcsql compile;
show errors
alter package arcsql compile body;
show errors
@arcsql_seed_data.sql
@arcsql_jobs.sql
@arcsql_default_setting.sql
commit;

select 'ARCSQL install complete.' MESSAGE from dual;



exec saas_auth_pkg.add_system_user('k2', 'k2@builtonapex.com');

@k2_utl_pkgh.sql 
@k2_utl_pkgb.sql

@k2_schema.sql
@k2_pkgh.sql 
@k2_pkgb.sql 

@k2_alert_schema.sql
@k2_alert_pkgh.sql 
@k2_alert_pkgb.sql

@k2_token_schema.sql
@k2_token_pkgh.sql
@k2_token_pkgb.sql

@k2_contact_schema.sql
@k2_contact_pkgh.sql
@k2_contact_pkgb.sql

@k2_api_pkgh.sql
@k2_api_pkgb.sql
@k2_api.sql

@k2_stat_schema.sql
@k2_stat_pkgh.sql
@k2_stat_pkgb.sql
@k2_stat_triggers.sql
@k2_stat_schedules.sql
@k2_stat_api_pkgh.sql
@k2_stat_api_pkgb.sql
@k2_stat_api.sql

@k2_metrics_pkgh.sql
@k2_metrics_pkgb.sql
@k2_metrics_schedules.sql

select 'K2 install complete.' message from dual;
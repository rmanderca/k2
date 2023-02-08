
-- Patch added Dec 2022
update saas_auth set account_type='system' where user_name='k2';

exec saas_auth_pkg.add_system_user(p_user_name=>'k2', p_email=>app_config.app_email);

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

@k2_json_schema.sql
@k2_json_pkgh.sql
@k2_json_pkgb.sql

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
@k2_stat_get_oracle_metrics.sql

select 'K2 install complete.' message from dual;
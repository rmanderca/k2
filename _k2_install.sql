
/*
WARNING: THIS FILE NOT TYPICALLY RUN DIRECTLY. IT IS RUN FROM ONE OF THE FILES IN THE ./install.
*/

declare 
   n number;
begin 
   select count(*) into n from user_source where name='K2_APP';
   if n = 0 then 
      execute immediate 'create or replace package k2_app as 
    version number := 0;
end;
';
   end if;
end;
/

@./config/&k2_app_dir/&k2_env_dir/secret_arcsql_cfg.sql
@./config/&k2_app_dir/&k2_env_dir/secret_k2_config.sql
@./config/&k2_app_dir/&k2_env_dir/secret_saas_auth_config.sql 
@./config/&k2_app_dir/&k2_env_dir/secret_app_config.sql
@./lib/arcsql/arcsql_install.sql
@./lib/saas_auth/saas_auth_schema.sql 

/*
Stazilla (moved to k2_stat).
*/

exec drop_table('stat_calc_type');
exec drop_table('stat_profile');
exec drop_table('stat_bucket');
exec drop_table('stat');
exec drop_table('stat_property');
exec drop_table('stat_in');
exec drop_table('stat_archive');
exec drop_sequence('seq_stat_work_id');
exec drop_table('stat_work');
exec drop_table('stat_avg_val_hist_ref');
exec drop_table('stat_percentiles_ref');
exec drop_table('stat_detail');
exec drop_package('statzilla');
exec drop_scheduler_job('statzilla_process_buckets_job');
exec drop_scheduler_job('statzilla_get_oracle_metrics_job');
exec drop_scheduler_job('statzilla_refresh_references_job');

/*
APEX_UTL2 contains generic utilities for APEX.
*/

@./lib/apex_utl2/apex_utl2_install.sql
exec drop_package('apex_utl2_config');

/*
K2 lib is similiar in function to apex_utl2 but code here is more specific to the framework.
*/

@./lib/k2/k2_install.sql

/*
Authorization code. Uses the login and verification pages.
*/

@./lib/saas_auth/saas_auth_install.sql 

@./lib/k2/k2_metrics_pkgh.sql
@./lib/k2/k2_metrics_pkgb.sql

@./lib/k2/k2_schedules.sql

create or replace package k2_app as 
    version number := 20221209;
end;
/

-- uninstall: exec drop_scheduler_job('k2_stat_process_buckets_job');
begin
   if not does_scheduler_job_exist('k2_stat_process_buckets_job') then 
      dbms_scheduler.create_job (
         job_name        => 'k2_stat_process_buckets_job',
         job_type        => 'PLSQL_BLOCK',
         job_action      => 'begin k2_stat.process_buckets; commit; end;',
         start_date      => systimestamp,
         repeat_interval => 'freq=minutely;interval=1',
         enabled         => true);
   end if;
   commit;
end;
/

-- uninstall: exec drop_scheduler_job('k2_stat_get_oracle_metrics_job');
begin
   if not does_scheduler_job_exist('k2_stat_get_oracle_metrics_job') then 
      dbms_scheduler.create_job (
         job_name        => 'k2_stat_get_oracle_metrics_job',
         job_type        => 'PLSQL_BLOCK',
         job_action      => 'begin k2_stat_get_oracle_metrics; commit; end;',
         start_date      => systimestamp,
         repeat_interval => 'freq=minutely;interval=5',
         enabled         => false);
   end if;
   if k2_config.enable_k2_stat_get_oracle_metrics then 
      dbms_scheduler.enable('k2_stat_get_oracle_metrics_job');
   else 
      dbms_scheduler.disable('k2_stat_get_oracle_metrics_job');
   end if;
   commit;
end;
/

-- uninstall: exec drop_scheduler_job('k2_stat_refresh_references_job');
begin
   if not does_scheduler_job_exist('k2_stat_refresh_references_job') then 
      dbms_scheduler.create_job (
         job_name        => 'k2_stat_refresh_references_job',
         job_type        => 'PLSQL_BLOCK',
         job_action      => 'begin k2_stat.refresh_all_references; commit; end;',
         start_date      => systimestamp,
         repeat_interval => 'freq=hourly;interval=8',
         enabled         => false);
   end if;
   if k2_config.enable_k2_stat then 
      dbms_scheduler.enable('k2_stat_refresh_references_job');
   else 
      dbms_scheduler.disable('k2_stat_refresh_references_job');
   end if;
   commit;
end;
/







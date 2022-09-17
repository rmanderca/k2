-- uninstall: exec drop_scheduler_job('statzilla_process_buckets');
begin
   if not does_scheduler_job_exist('statzilla_process_buckets_job') then 
      dbms_scheduler.create_job (
         job_name        => 'statzilla_process_buckets_job',
         job_type        => 'PLSQL_BLOCK',
         job_action      => 'begin statzilla.process_buckets; end;',
         start_date      => systimestamp,
         repeat_interval => 'freq=minutely;interval=1',
         enabled         => false);
   end if;
   if k2_config.enable_statzilla then 
      dbms_scheduler.enable('statzilla_process_buckets_job');
   else 
      dbms_scheduler.disable('statzilla_process_buckets_job');
   end if;
end;
/

-- uninstall: exec drop_scheduler_job('statzilla_get_oracle_metrics');
begin
   if not does_scheduler_job_exist('statzilla_get_oracle_metrics_job') then 
      dbms_scheduler.create_job (
         job_name        => 'statzilla_get_oracle_metrics_job',
         job_type        => 'PLSQL_BLOCK',
         job_action      => 'begin statzilla_get_oracle_metrics; end;',
         start_date      => systimestamp,
         repeat_interval => 'freq=minutely;interval=1',
         enabled         => false);
   end if;
   if k2_config.enable_statzilla_get_oracle_metrics then 
      dbms_scheduler.enable('statzilla_get_oracle_metrics_job');
   else 
      dbms_scheduler.disable('statzilla_get_oracle_metrics_job');
   end if;
end;
/





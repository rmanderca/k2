
exec drop_scheduler_job('k2_metric_process_buckets_job'); 
exec drop_scheduler_job('k2_metric_process_datasets_job_v2');

-- uninstall: exec drop_scheduler_job('k2_metric_process_datasets_job');
begin
   if not does_scheduler_job_exist('k2_metric_process_datasets_job') then 
      dbms_scheduler.create_job (
         job_name        => 'k2_metric_process_datasets_job',
         job_type        => 'PLSQL_BLOCK',
         job_action      => 'begin k2_metric.process_datasets_job; commit; end;',
         start_date      => systimestamp,
         repeat_interval => 'freq=minutely;interval=1',
         enabled         => true);
   end if;
   commit;
end;
/

-- uninstall: exec drop_scheduler_job('k2_metric_get_oracle_metrics_job');
begin
   if not does_scheduler_job_exist('k2_metric_get_oracle_metrics_job') then 
      dbms_scheduler.create_job (
         job_name        => 'k2_metric_get_oracle_metrics_job',
         job_type        => 'PLSQL_BLOCK',
         job_action      => 'begin k2_metric_get_oracle_metrics; commit; end;',
         start_date      => systimestamp,
         repeat_interval => 'freq=minutely;interval=5',
         enabled         => false);
   end if;
   commit;
end;
/

-- uninstall: exec drop_scheduler_job('k2_metric_refresh_references_job');
begin
   if not does_scheduler_job_exist('k2_metric_refresh_references_job') then 
      dbms_scheduler.create_job (
         job_name        => 'k2_metric_refresh_references_job',
         job_type        => 'PLSQL_BLOCK',
         job_action      => 'begin k2_metric.refresh_all_references; commit; end;',
         start_date      => systimestamp,
         repeat_interval => 'freq=hourly;interval=8',
         enabled         => false);
   end if;
   commit;
end;
/







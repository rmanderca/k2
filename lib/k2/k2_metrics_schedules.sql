-- uninstall: exec drop_scheduler_job('k2_get_metrics_job');
begin
   if not does_scheduler_job_exist('k2_get_metrics_job') then 
      dbms_scheduler.create_job (
         job_name        => 'k2_get_metrics_job',
         job_type        => 'PLSQL_BLOCK',
         job_action      => 'begin k2_metrics.get_metrics; commit; end;',
         start_date      => systimestamp,
         repeat_interval => 'freq=minutely;interval=5',
         enabled         => true);
   end if;
   commit;
end;
/

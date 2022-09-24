
-- | app_scheduler_jobs.sql - Use this file to create the scheduler jobs for your application.


/*

-- uninstall: exec drop_scheduler_job('foo');
begin
  if not does_scheduler_job_exist('foo') then 
     dbms_scheduler.create_job (
       job_name        => 'foo',
       job_type        => 'PLSQL_BLOCK',
       job_action      => 'begin bar.bin; end;',
       start_date      => systimestamp,
       repeat_interval => 'freq=minutely;interval=5',
       enabled         => false);
   end if;
   -- Consider using a config variable to keep your job enabled or disabled.
   if app_config.enable_job_foo then 
   	dbms_scheduler.enable('k2_get_metrics_job');
	else 
   	dbms_scheduler.disable('k2_get_metrics_job');
	end if;
	commit;
end;
/

*/

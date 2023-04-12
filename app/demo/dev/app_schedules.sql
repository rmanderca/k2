
-- | app_schedules.sql - Use this file to create the scheduler jobs for your application.


-- uninstall: exec drop_procedure('app_tasks_5m');
create or replace procedure app_tasks_5m as 
begin 
   arcsql.debug('app_tasks_5m: ');

   if arcsql.is_truthy(app_job.disable_all) then
      return;
   end if;

   -- Requires ALTER SYSTEM privs to work!
   -- arcsql.kill_sessions(p_username=>user, p_last_call_et=>300);
   -- delete from arcsql_log where log_time < systimestamp-1 and log_type like 'debug%';
exception
   when others then
      arcsql.log_err('app_tasks_5m: '||dbms_utility.format_error_stack);
      raise;
end;
/

begin
  drop_scheduler_job('app_tasks_5m_job');
  if not does_scheduler_job_exist('app_tasks_5m_job') then 
     dbms_scheduler.create_job (
       job_name        => 'app_tasks_5m_job',
       job_type        => 'PLSQL_BLOCK',
       job_action      => 'begin app_tasks_5m; end;',
       start_date      => systimestamp,
       repeat_interval => 'freq=minutely;interval=5',
       enabled         => true);
   end if;
end;
/

-- uninstall: exec drop_scheduler_job('saas_auth_automation_daily');
begin
  if not does_scheduler_job_exist('saas_auth_automation_daily') then 
     dbms_scheduler.create_job (
       job_name        => 'saas_auth_automation_daily',
       job_type        => 'PLSQL_BLOCK',
       job_action      => 'begin saas_auth_pkg.automation_daily; end;',
       start_date      => systimestamp,
       repeat_interval => 'freq=daily;byhour=23;byminute=55',
       enabled         => true);
   end if;
end;
/


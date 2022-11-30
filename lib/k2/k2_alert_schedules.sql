

begin
  if not does_scheduler_job_exist('k2_alert_check') then 
     -- Checks to see if any existing alerts need to auto-close or re-notify.
     dbms_scheduler.create_job (
       job_name        => 'k2_alert_check',
       job_type        => 'PLSQL_BLOCK',
       job_action      => 'begin k2_alert.check_alerts; end;',
       start_date      => systimestamp,
       repeat_interval => 'freq=minutely;interval=1',
       enabled         => true);
   end if;
end;
/
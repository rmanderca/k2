


begin
  if not does_scheduler_job_exist('stripe_parse_data_requests') then 
     dbms_scheduler.create_job (
       job_name        => 'stripe_parse_data_requests',
       job_type        => 'PLSQL_BLOCK',
       job_action      => 'begin stripe.parse_data_requests; end;',
       start_date      => systimestamp,
       repeat_interval => 'freq=minutely;interval=1',
       enabled         => true);
   end if;
end;
/


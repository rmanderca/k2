


exec drop_scheduler_job('stripe_process_webhooks');

begin
  if not does_scheduler_job_exist('stripe_process_webhooks') then 
     dbms_scheduler.create_job (
       job_name        => 'stripe_process_webhooks',
       job_type        => 'PLSQL_BLOCK',
       job_action      => q'<begin stripe.process_webhooks; exception when others then arcsql.log_err('stripe_process_webhooks: '||dbms_utility.format_error_stack); raise; end;>',
       start_date      => systimestamp,
       repeat_interval => 'freq=minutely;interval=1',
       enabled         => true);
   end if;
end;
/


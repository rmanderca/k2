

-- uninstall: exec drop_package('app_config');
create or replace package app_config as 
   
   version number := 0;

   -- Used to determine which env we are working in. Usually dev, tst, prd.
   env varchar2(12) := 'dev';

   app_name varchar2(120) := 'K2 Default App (dev)';

   -- Email address you want app owner notifications to get sent to. This is required even if email is disabled!
   -- Why is this required? We need to build a system user and that user must have an email to create a row in saas_auth table!
   app_email varchar2(120) := 'k2@mydefaultapp.com';

   -- Email address most emails will be sent from.
   app_from_email varchar2(120) := null;

   -- Disables the app_send_email proc which disables all emails. Truthy values work here.
   disable_email varchar2(120) := 'n';

   -- Route all emails to this address instead of using the address for the account. Used for dev/test usually.
   email_override varchar2(120) := null;

end;
/

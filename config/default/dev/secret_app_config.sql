
/* 

### The app_config package header

The app_config package contains application variable settings.

You can add your own custom variables here if you want. It is probably a better idea to create your own package header for that and name it {your_app_name}_config and add a reference to the new file in ./app/dev/{app_name}_install.sql.

*/

-- uninstall: exec drop_package('app_config');
create or replace package app_config as 
   
   version number := 20230223;

   -- Used to determine which env we are working in. Usually dev, tst, prd.
   env varchar2(16) := 'dev';

   app_name varchar2(256) := 'K2 (dev)';

   -- Email address you want app owner notifications to get sent to. This is required even if email is disabled!
   -- Why is this required? We need to build a system user and that user must have an email to create a row in saas_auth table!
   app_owner_email varchar2(256) := 'team@mycompany.com';

   -- Email address most emails will be sent from.
   app_from_email varchar2(256) := 'app@mycompany.com';

   -- Disables the app_send_email proc which disables all emails. Truthy values work here.
   disable_email varchar2(256) := 'n';

   -- Route all emails to this address instead of using the address for the account. Used for dev/test usually.
   email_override varchar2(256) := null;

   -- Add an account for testing to avoid the registration process. Needs to be an email address.
   app_test_user varchar2(256) := 'test@mycompany.com';
   -- Super common error to get an invalid password here and see an error when your app_users.sql script runs during install.
   app_test_pass varchar2(256) := 'X2randomX2pass!';

end;
/

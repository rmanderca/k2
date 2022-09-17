

-- uninstall: exec drop_package('app_config');
create or replace package app_config as 
   
   version number := 0;

   -- Primary email and sms used to add to the default ARCSQL admin contact group.
   admin_email varchar2(120) := 'donotreply@notmydomain.com';
   -- Should be an email address which gets sent to SMS.
   admin_sms varchar2(120)   := '5555555555@txt.att.net';

end;
/

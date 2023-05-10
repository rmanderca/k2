
-- uninstall: drop package saas_auth_config;
create or replace package saas_auth_config as 

   -- Set to a default timezone to use in cases when you don't know time zone.
   default_timezone varchar2(128) := 'US/Eastern';

   -- Determines if http or https for links generated by the auth service.
   saas_auth_protocol varchar2(16) := 'https';

   saas_auth_salt varchar2(256) := 'SAAS_AUTH_SALT';

   -- Limits the rate of auth requests within any 10 minute window.
   -- Null to disable.
   auth_request_rate_limit number := 1000;

   -- Enable auth notifications if your pages use them.
   flash_notifications boolean := true;

   -- Days user can auto login for if they select the checkbox on login form.
   -- Set to zero or null to disable and hide the checkbox.
   enable_auto_login_days number := 30;

   password_minimum_length number := 8;
   password_minimum_upper number := 1;
   password_minimum_lower number := 1;
   password_minimum_digit number := 1;

end;
/

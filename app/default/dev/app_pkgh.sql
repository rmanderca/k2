
-- uninstall: exec drop_package('app');
-- uninstall: exec drop_package('app_config');
create or replace package app as
   procedure foo;
end;
/
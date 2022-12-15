

-- uninstall: exec drop_package('app_dev');
create or replace package app_dev as 
   -- Used in some lib schema files to drop tables everytime it is run.
   drop_tables boolean := false;
end;
/

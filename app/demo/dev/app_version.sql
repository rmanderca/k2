
-- uninstall: exec drop_package('app_version');
create or replace package app_version as 
    version number := 20220830;
end;
/

-- uninstall: exec drop_package('statzilla_version');
create or replace package statzilla_version as 
    version number := 20220830;
end;
/
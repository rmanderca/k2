

-- uninstall: exec drop_package('app_config');
create or replace package app_config as 
   
   version number := 0;
   public_user_name varchar2(120) := 'post.e.than@gmail.com';

end;
/

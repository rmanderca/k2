
-- uninstall: exec drop_package('k2_access_key');
create or replace package k2_access_key as 

procedure save_access_key_row (
   p_access_key_row in access_key%rowtype);

function get_access_key_row (
   p_access_key_key in varchar2)
   return access_key%rowtype;

procedure create_access_key (
   p_access_key_key in varchar2,
   p_user_id in number);

end;
/

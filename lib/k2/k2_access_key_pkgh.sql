
-- uninstall: exec drop_package('k2_access_key');
create or replace package k2_access_key as 

procedure save_access_key_row (
   p_access_key_row in access_keys%rowtype);

function get_access_key_row (
   p_access_key_key in varchar2)
   return access_keys%rowtype;

procedure create_access_key (
   p_access_key_key in varchar2,
   p_user_id in number);

procedure assert_access_key_exists(
   p_access_key_key in varchar2);

end;
/

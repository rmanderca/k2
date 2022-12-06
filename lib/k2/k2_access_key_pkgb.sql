
create or replace package body k2_access_key as 

procedure save_access_key_row (
   p_access_key_row in access_keys%rowtype) is 
begin
   update access_keys set row=p_access_key_row where access_key_key=p_access_key_row.access_key_key;
   update access_keys set updated = systimestamp where access_key_key=p_access_key_row.access_key_key;
end;

function get_access_key_row (
   p_access_key_key in varchar2)
   return access_keys%rowtype is 
   r access_keys%rowtype;
begin
   select * into r from access_keys where access_key_key = p_access_key_key;
   return r;
end;

procedure create_access_key (
   p_access_key_key in varchar2,
   p_user_id in number) is 
begin
   insert into access_keys (
      access_key_key,
      access_key,
      user_id) values (
      p_access_key_key,
      sys_guid(),
      p_user_id);
end;

end;
/

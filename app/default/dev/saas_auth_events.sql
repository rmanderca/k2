

-- uninstall: exec drop_procedure('on_create_account');
create or replace procedure on_create_account (
   p_user_id in number) as 
   -- Do stuff when a new account is added to the saas_auth table.
begin
   arcsql.debug('on_create_account: '||p_user_id); 
   -- saas_app.on_create_account(p_user_id=>p_user_id);
end;
/


-- uninstall: exec drop_procedure('on_delete_account');
create or replace procedure on_delete_account (
   p_user_id in number) as 
   -- Do stuff when a row is deleted from the saas_auth table.
begin
   arcsql.debug('on_delete_account: '||p_user_id);
end;
/


-- uninstall: exec drop_procedure('on_login');
create or replace procedure on_login (
   p_user_id in number) as 
   -- Do stuff when a user successfully logs in.
begin
   arcsql.debug('on_login: '||p_user_id); 
   -- saas_app.on_login(p_user_id=>p_user_id);
end;
/
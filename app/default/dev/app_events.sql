-- uninstall: exec drop_procedure('after_create_account');
create or replace procedure after_create_account (p_user_id in number) as 
begin
   arcsql.debug('after_create_account: '||p_user_id); 
   -- insert into app_user (app_user_id) values (p_user_id);
end;
/

-- Replaced with before and after delete account.
exec drop_procedure('on_delete_account');

-- uninstall: exec drop_procedure('before_delete_user');
create or replace procedure before_delete_user (p_user_id in number) as 
begin
   arcsql.debug('before_delete_user: '||p_user_id); 
end;
/

-- uninstall: exec drop_procedure('after_delete_user');
create or replace procedure after_delete_user (p_user_id in number) as 
begin
   arcsql.debug('after_delete_user: '||p_user_id); 
end;
/

-- uninstall: exec drop_procedure('on_login');
create or replace procedure on_login (p_user_id in number) as 
begin
   arcsql.debug('on_login: '||p_user_id); 
end;
/

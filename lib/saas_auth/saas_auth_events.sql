

-- This procedure will get called anytime a new account is created.

-- uninstall: exec drop_procedure('on_create_account');
create or replace procedure on_create_account (p_user_id in number) as 
begin
   k2.debug('on_create_account: '||p_user_id); 
   null;
end;
/

-- Replaced with before and after delete account.
exec drop_procedure('on_delete_account');

-- uninstall: exec drop_procedure('before_delete_user');
create or replace procedure before_delete_user (p_user_id in number) as 
begin
   k2.debug('before_delete_user: '||p_user_id); 
   null;
end;
/

-- uninstall: exec drop_procedure('after_delete_user');
create or replace procedure after_delete_user (p_user_id in number) as 
begin
   k2.debug('after_delete_user: '||p_user_id); 
   null;
end;
/

-- uninstall: exec drop_procedure('on_login');
create or replace procedure on_login (p_user_id in number) as 
begin
   k2.debug('on_login: '||p_user_id); 
   null;
end;
/


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

/*

### on_page_load (procedure)

Runs when a a page loads if configured!

Add the code below to a Page Load - Dynamic Action which Executes Server-side Code.

```
k2.fire_event_proc('on_page_load');
```

*/

-- uninstall: exec drop_procecure('on_page_load');
create or replace procedure on_page_load as 
begin 
   arcsql.debug('on_page_load: ');
   k2.process_cookies;
end;
/

/*

### initialize_session (procedure)

Runs when a session initializes if configured!

You need to add the code below Edit Security Attributes - Database Session - Initialize PL/SQL code

```
begin
   k2.fire_event_proc('initialize_session');
end;
```

*/

create or replace procedure initialize_session as 
begin 
   arcsql.debug('initialize_session');
   saas_auth_pkg.auto_login;
end;
/

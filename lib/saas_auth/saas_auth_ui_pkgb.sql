

create or replace package body saas_auth_ui as

/*

### get_auto_login_url (function)

Creates a token with a randomly generated key, retrieves the token's details, generates a URL to the login page of the application with the token added as a parameter, saves the token's details to the tokens table, and returns the URL.

*/

function get_auto_login_url (
   p_user_id in number)
   return varchar2 is
   v_token tokens%rowtype;
begin 
   v_token.token := k2_token.create_token (
      p_token_key=>sys_guid(),
      p_token_type=>'auto_login_link',
      p_user_id=>p_user_id);

   v_token := k2_token.get_token_row(p_token=>v_token.token);
   
   v_token.token_url :=  k2.monkey_patch_remove_app_root_url(apex_page.get_url (
      p_application=>k2.app_id,
      p_page=>'login',
      p_clear_cache=>20001,
      p_items=>'P20001_AUTO_LOGIN_TOKEN,P20001_REGION',
      p_values=>v_token.token||',AUTO_LOGIN',
      p_plain_url=>true));
   
   k2_token.save_token_row(v_token);
   
   return v_token.token_url;
end;

/*

### set_auto_login (procedure)

Enables or disables automatic login for a user. If p_checkbox_value is 'Y', a new token is created and added to a cookie. Otherwise, any existing automatic login tokens for the user are deleted.

*/

procedure set_auto_login (
   p_checkbox_value in varchar2 default 'N') is 
   v_user_id number := saas_auth_pkg.user_id;
   v_token tokens.token%type;
begin 
   arcsql.assert_not_null(v_user_id);
   if p_checkbox_value = 'Y' then 
      v_token := k2_token.create_token (
         p_token_key=>sys_guid(),
         p_token_type=>'auto_login',
         p_user_id=>v_user_id);
      k2.add_cookie(
         p_name=>'auto_login_'||k2.app_id,
         p_value=>v_token,
         p_expires=>sysdate+saas_auth_config.enable_auto_login_days,
         p_user_id=>v_user_id);
    else 
       delete from tokens where token_type='auto_login' and user_id=v_user_id;
    end if;
end;

/*

### logout (procedure)

Logs out current APP_SESSION for APP_ID. 

WARNING: I think this may throw a rollback so anything that does work and calls this needs to commit first!

Do not call post_logout, it will run automatically.

*/

procedure logout is -- | 
begin 
   arcsql.debug('logout: ');
   apex_authentication.logout(v('APP_SESSION'), v('APP_ID'));
exception 
   when others then
      arcsql.log_err('logout: '||dbms_utility.format_error_stack);
      raise;
end;

/*

### create_account (procedure)

Creates an account if it passes checks and does not exist.

New accounts default to 'inactive'. You will need to set to 'active' right away or when they verify email.

*/

-- ToDo: Not sure about requested pricing plan, maybe there is a better way, or more generic.
function create_account ( 
   p_email_address in varchar2,
   p_full_name in varchar2,
   p_password in varchar2,
   p_requested_pricing_plan in varchar2 default null)
   return number is
   n number;
   r saas_auth%rowtype;
   v_user_id number;
   v_email_address varchar2(256) := lower(p_email_address);
begin 
   arcsql.debug('create_account: '||v_email_address);

   saas_auth_pkg.assert_password_passes_complexity_check(p_password=>p_password);
   saas_auth_pkg.assert_valid_email_format(p_email_address=>v_email_address);

   select count(*) into n from saas_auth
    where user_name=lower(v_email_address);
    
   insert into saas_auth (
      user_name,
      full_name,
      email, 
      uuid,
      last_session_id,
      password,
      account_status,
      requested_pricing_plan) values (
      -- For now user name is email
      v_email_address,
      p_full_name,
      v_email_address, 
      sys_guid(),
      v('APP_SESSION'),
      arcsql.str_random(12)||'x!',
      'inactive',
      p_requested_pricing_plan) returning user_id into v_user_id;
   saas_auth_pkg.set_password (
      p_user_id=>v_user_id,
      p_password=>p_password);
   k2.fire_event_proc(p_proc_name=>'after_create_account', p_parm=>v_user_id);
   return v_user_id;
end; 

/*

### set_account_status (procedure)

Sets the user account status to active, inactive, or locked.

* **p_user_name** - User name.
* **p_account_status** - Must be one of active, inactive, or locked.

*/

procedure set_account_status (
   p_user_name in varchar2,
   p_account_status in varchar2) is
begin 
   if lower(p_account_status) not in ('active', 'inactive', 'locked') then 
      raise_application_error(-20001, 'set_account_status: Invalid account status: '||lower(p_account_status));
   end if;
   update saas_auth 
      set account_status=lower(p_account_status)
    where user_name=lower(p_user_name);
end;

/*

### get_account_status (function)

Returns the value of account_status in saas_auth table for given user.

* **p_user_name** - User name.

*/

function get_account_status (
   p_user_name in varchar2)
   return varchar2 is
   u saas_auth%rowtype;
begin 
   arcsql.debug('get_account_status: '||p_user_name);
   arcsql.assert_not_null(p_user_name);
   u := saas_auth_pkg.get_saas_auth_row(p_user_name=>p_user_name);
   return u.account_status;
end;

procedure assert_user_name_exists (
   p_user_name in varchar2) is 
begin
   if not saas_auth_pkg.does_user_name_exist(p_user_name=>p_user_name) then 
      raise_application_error(-20001, 'assert_user_name_exists: The user name does not exist: '||p_user_name);
   end if;
end;

procedure assert_user_name_does_not_exist (
   p_user_name in varchar2) is 
begin
   if saas_auth_pkg.does_user_name_exist(p_user_name=>p_user_name) then 
      raise_application_error(-20001, 'assert_user_name_does_not_exist: This user name already exists: '||p_user_name);
   end if;
end;

end;
/

create or replace package body saas_auth_pkg as

-- ToDo: Safeguards for too many requests, brute force...
-- ToDo: Document available fire_ events.
-- ToDo: Implement locked account
-- ToDo: Replace use of date with timestamp.
-- ToDo: Review all error handlers which get back to the user.

procedure raise_error (
   p_message in varchar2) is 
begin
   arcsql.debug('raise_error: '||p_message);
   apex_error.add_error (
      p_message          => p_message,
      p_display_location => apex_error.c_inline_in_notification );
   raise_application_error(-20001, 'An error occurred processing this request.');
end;

/*

### get_saas_auth_row (function)

Return a row from SAAS_AUTH using the user_id.

* **p_user_id** - The customer_id of the desired row.

Error is raised when no data found.

*/

function get_saas_auth_row ( -- | 
   p_user_id in number)
   return saas_auth%rowtype is 
   r saas_auth%rowtype;
begin
   select * into r from saas_auth where user_id=p_user_id;
   return r;
end; 

/*

### get_saas_auth_row (function)

Return a row from SAAS_AUTH using the user_name.

* **p_user_name** - User name.

Error is raised when no data found.

*/

function get_saas_auth_row ( 
   p_user_name in varchar2)
   return saas_auth%rowtype is 
   r saas_auth%rowtype;
begin
   arcsql.debug('get_saas_auth_row: '||p_user_name);
   arcsql.assert_not_null(p_user_name);
   select * into r from saas_auth where user_name=lower(p_user_name);
   return r;
exception 
   when others then
      arcsql.log_err('get_saas_auth_row: '||dbms_utility.format_error_stack);
      raise;
end; 

procedure set_session_time_zone ( -- | Sets the time zone for user when logging in.
   p_user_id in number) is 
   s saas_auth%rowtype;
   v_offset varchar2(12);
begin 
   arcsql.debug('set_session_time_zone: user_id='||p_user_id);
   arcsql.assert_not_null(p_user_id);
   s := get_saas_auth_row(p_user_id=>p_user_id);
   select tz_offset(s.timezone_name) into v_offset from dual;
   apex_util.set_session_time_zone(p_time_zone=>v_offset);
exception 
   when others then
      arcsql.log_err('set_session_time_zone: '||dbms_utility.format_error_stack);
      raise;
end;

/*

### register_login (procedire)

Updates saas_auth row for user anytime a login occurs. Sets the time zone.

* **p_user_id** - User ID

*/

procedure register_login ( -- | 
   p_user_id in varchar2) is 
   n number;
begin 
   arcsql.debug('register_login: user='||p_user_id);
   update saas_auth 
      set last_login=sysdate,
          login_count=login_count+1,
          last_session_id=v('APP_SESSION'),
          failed_login_count=0
    where user_id=p_user_id;
   set_session_time_zone(p_user_id);
exception 
   when others then
      arcsql.log_err('register_login: '||dbms_utility.format_error_stack);
      raise; 
end;

/*

### login (procedire)

Logs a user in using user name.

* **p_user_name** - User name

Password does not matter here, it just needs to be provided. This will have no effect on the user's pass.

*/

procedure login ( -- | Login with username only.
   p_user_name in varchar2) is 
begin 
   apex_authentication.post_login (
      p_username=>lower(p_user_name), 
      p_password=>utl_raw.cast_to_raw(dbms_random.string('a',12)||'x!'));
end;

procedure login ( 
   p_user_id in number) is 
   v_user saas_auth%rowtype;
begin 
   v_user := get_saas_auth_row(p_user_id=>p_user_id);
   apex_authentication.post_login (
      p_username=>v_user.user_name,
      p_password=>utl_raw.cast_to_raw(dbms_random.string('a',12)||'x!'));
end;

procedure auto_login is 
   v_token tokens%rowtype;
   v_cookie_value varchar2(256);
   v_user saas_auth%rowtype;
begin 
   arcsql.debug('auto_login: '||v('APP_USER')||', '||v('APP_SESSION'));
   if lower(v('APP_USER')) not in ('nobody', 'guest', 'unknown', 'anonymous') then 
      return;
   end if;
   v_cookie_value := k2.get_cookie('auto_login_'||k2.app_id);
   if v_cookie_value is not null then
      if k2_token.is_valid_token(p_token=>v_cookie_value) then
         v_token := k2_token.get_token_row(p_token=>v_cookie_value);
         v_user := get_saas_auth_row(p_user_id=>v_token.user_id);
         arcsql.log_security_event(p_text=>'auto_login: '||v_user.user_name, p_key=>'saas_auth');
         if v_user.account_status = 'active' then 
            apex_authentication.post_login (
               p_username=>v_user.user_name, 
               p_password=>utl_raw.cast_to_raw(dbms_random.string('x',12)));
            register_login(p_user_id=>v_user.user_id);
         end if;
      end if;
   end if;
exception 
   when others then
      arcsql.log_err('auto_login: '||dbms_utility.format_error_stack);
      raise;
end;

function get_current_time_for_user ( -- | Return a timestamp for the current time using tz for the user.
   p_user_id in number) 
   return timestamp is -- | Returns null if a timezone name can't be identified. Good idea to set saas_auth_config.default_timezone to avoid that.
   v_timezone_name saas_auth.timezone_name%type;
   t timestamp;
begin 
   select timezone_name into v_timezone_name
     from saas_auth 
    where user_id=p_user_id;
   if v_timezone_name is null then 
      v_timezone_name := saas_auth_config.default_timezone;
   end if;
   if v_timezone_name is not null then 
      execute immediate 'select systimestamp at time zone '''||v_timezone_name||''' from dual' into t;
   end if;
   return t;
exception 
   when others then
      arcsql.log_err('get_current_time_for_user: '||dbms_utility.format_error_stack);
      raise;
end;

function does_user_name_exist ( -- | Return true if the user name exists. Does not see some accounts!
   p_user_name in varchar2) return boolean is
   n number;
begin 
   arcsql.debug('does_user_name_exist: '||lower(p_user_name));
   select count(*) into n 
     from saas_auth
    where user_name=lower(p_user_name);
   return n = 1;
end;

procedure raise_user_name_not_found ( -- | Raise an error if user name does not exist.
   p_user_name in varchar2 default null) is 
begin 
   if not does_user_name_exist(p_user_name=>p_user_name) then
      arcsql.log_security_event(p_text=>'raise_user_name_not_found: '||p_user_name, p_key=>'saas_auth');
      raise_application_error(-20001, 'raise_user_name_not_found: '||p_user_name);
   end if;
end;

function get_uuid (p_user_id in number) -- | Return a user's uuid.
   return varchar2 is 
   v_uuid saas_auth.uuid%type;
begin 
   select uuid into v_uuid 
     from saas_auth
    where user_id=p_user_id;
   return v_uuid;
exception 
   when others then
      arcsql.log_err('get_uuid: '||dbms_utility.format_error_stack);
      raise;
end;

procedure assert_password_passes_complexity_check ( -- | Raises error if password does not adhere to defined specifications.
   p_password in varchar2) is 
begin 
   -- arcsql.debug_secret('assert_password_passes_complexity_check: '||p_password);
   if not arcsql.str_complexity_check(text=>p_password, chars=>saas_auth_config.password_minimum_length) then 
      raise_error('Password needs to be at least '||saas_auth_config.password_minimum_length||' characters.');
   end if;
   if not arcsql.str_complexity_check(text=>p_password, uppercase=>saas_auth_config.password_minimum_upper) then 
      raise_error('Password needs at least '||saas_auth_config.password_minimum_upper||' upper-case character(s).');
   end if;
   if not arcsql.str_complexity_check(text=>p_password, lowercase=>saas_auth_config.password_minimum_lower) then 
      raise_error('Password needs at least '||saas_auth_config.password_minimum_lower||' lower-case character(s).');
   end if;
   if not arcsql.str_complexity_check(text=>p_password, digit=>saas_auth_config.password_minimum_digit) then 
      raise_error('Password needs at least '||saas_auth_config.password_minimum_digit||' digit(s).');
   end if;
exception 
   when others then
      arcsql.log_err('assert_password_passes_complexity_check: '||dbms_utility.format_error_stack);
      raise;
end;

function get_hashed_password ( -- | Returns SHA256 hash we will store in the password field.
   p_secret_string in varchar2) return raw is
begin
   return arcsql.encrypt_sha256(saas_auth_config.saas_auth_salt || p_secret_string);
exception 
   when others then
      arcsql.log_err('get_hashed_password: '||dbms_utility.format_error_stack);
      raise;
end;

procedure post_logout is -- | Run as part of the custom authenticaton scheme.
begin 
   arcsql.debug('post_logout: user='||v('APP_USER'));
   delete from tokens where token_type='auto_login' and user_id=saas_auth_pkg.user_id;
   k2.fire_event_proc(p_proc_name=>'on_logout', p_parm=>saas_auth_pkg.user_id);
exception 
   when others then
      arcsql.log_err('post_logout: '||dbms_utility.format_error_stack);
      raise;
end;

procedure set_password ( -- | Sets a user password. 
   p_user_id in number,
   p_password in varchar2) is 
   hashed_password varchar2(128);
   v_uuid saas_auth.uuid%type;
begin 
   arcsql.debug('set_password: '||p_user_id);
   assert_password_passes_complexity_check(p_password);
   v_uuid := get_uuid(p_user_id=>p_user_id);
   hashed_password := get_hashed_password(p_secret_string=>v_uuid||p_password);
   -- Set arcsql_cfg.allow_debug_secret = true if you want to see this in the logs.
   arcsql.debug_secret('v_uuid='||v_uuid||', password='||p_password||', hashed_password='||hashed_password);
   update saas_auth
      set password=hashed_password
    where user_id=p_user_id;
exception 
   when others then
      arcsql.log_err('set_password: '||dbms_utility.format_error_stack);
      raise;
end;

procedure raise_too_many_auth_requests is -- | Raises error if too many authorization requests are being made.
begin 
   arcsql.debug('raise_too_many_auth_requests: ');
   if saas_auth_config.auth_request_rate_limit is null then 
      return;
   end if;
   -- If there have been more than 20 requests in the past minute raise an error.
   if arcsql.get_request_count(p_request_key=>'saas_auth', p_min=>10) > saas_auth_config.auth_request_rate_limit then
      arcsql.log_security_event(p_text=>'raise_too_many_auth_requests: '||arcsql.get_request_count(p_request_key=>'saas_auth', p_min=>10), p_key=>'saas_auth');
      raise_error('Authorization request rate has been exceeded.');
      apex_util.pause(1);
   end if;
end;

procedure assert_account_is_inactive ( -- | Raise an error if the account is not in 'inactive' status.
   p_user_id in number) is 
   r saas_auth%rowtype;
begin 
   r := get_saas_auth_row(p_user_id=>p_user_id);
   if r.account_status != 'inactive' then 
      arcsql.log_security_event('assert_account_is_inactive: Failed: '||p_user_id);
      raise_application_error(-20001, 'An error occurred processing this request.');
   end if;
end;

procedure set_timezone_name ( -- Called when user logs in to set the current timezone name.
   p_user_name in varchar2,
   p_timezone_name in varchar2) is 
   v_offset varchar2(12);
begin 
   arcsql.debug('set_timezone_name: user='||p_user_name||', '||p_timezone_name);
   if p_timezone_name is null then 
      arcsql.log_err('set_timezone_name: Timezone name is null: user='||p_user_name);
      return;
   end if;
   select tz_offset(p_timezone_name) into v_offset from dual;
   update saas_auth 
      set timezone_name=p_timezone_name,
          timezone_offset=v_offset
    where user_name=lower(p_user_name);
   set_session_time_zone(to_user_id(p_user_name=>p_user_name));
exception 
   when others then
      arcsql.log_err('set_timezone_name: '||dbms_utility.format_error_stack);
      raise;
end;

function to_user_id ( -- | Returns user id using user name.
   p_user_name in varchar2) return number is
   r saas_auth%rowtype;
begin
   select * into r from saas_auth where user_name=lower(p_user_name);
   return r.user_id;
end;

procedure raise_does_not_appear_to_be_an_email_format ( -- | Raises an error if the string does not look like an email.
   p_email_address in varchar2) is 
begin 
   if not arcsql.str_is_email(p_email_address) then 
      raise_error('Email does not appear to be a valid email address.');
   end if;
end;

procedure delete_user ( -- | Delete user account by id. Throw an error if the user_id is invalid.
   p_user_id in number) is 
begin 
   arcsql.debug('delete_user: '||p_user_id);
   k2.fire_event_proc(p_proc_name=>'before_delete_user', p_parm=>p_user_id);
   delete from saas_auth 
    where user_id=p_user_id;
   k2.fire_event_proc(p_proc_name=>'after_delete_user', p_parm=>p_user_id);
   arcsql.log_security_event(p_text=>'delete_user: '||p_user_id, p_key=>'saas_auth');
exception 
   when others then
      -- arcsql.log_err('delete_user: '||dbms_utility.format_error_stack);
      raise;
end;

procedure add_system_user ( -- | Add an user account for a system user.
   p_user_name in varchar2,
   p_email_address in varchar2) is 
   n number;
begin 
   select count(*) into n from saas_auth where user_name=lower(p_user_name);
   if n = 0 then 
      insert into saas_auth (
         user_name,
         email, 
         password,
         account_type) values (
         lower(p_user_name),
         lower(p_email_address), 
         arcsql.str_random(12)||'!',
         'system');
   end if;
end;

procedure assert_account_is_allowed_to_login ( -- | Works via the normal custom_auth login process to ensure the account can login.
   p_user_id in number) is 
   n number;
begin
   select count(*) into n 
     from saas_auth 
    where user_id=p_user_id 
      and account_type not in ('system')
      and account_status in ('active');
   if n = 0 then 
      raise_application_error(-20001, 'assert_account_is_allowed_to_login: False');
   end if;
end;

procedure assert_valid_email_format ( -- | Throw an error if the email address format looks invalid.
   p_email_address in varchar2) is 
begin
   if not arcsql.str_is_email(p_email_address) then 
      raise_error('Invalid email address: '|| p_email_address);
   end if;
end;

/*

### add_account (function)

Adds a new account and returns the user id.

* **p_email_address** - Email address for the user.
* **p_full_name** - Full name of the user.
* **p_password** - Password for the user.
* *p_account_status* - Status of the account. Default is 'inactive'.

Error is raised when no data found.

*/

function add_account (
   p_email_address in varchar2,
   p_full_name in varchar2,
   p_password in varchar2,
   p_account_status in varchar2 default 'inactive') 
   return number is 
   v_user_id number;
begin 
   insert into saas_auth (
      user_name,
      full_name,
      email, 
      uuid,
      last_session_id,
      password,
      account_status) values (
      -- For now user name is email
      lower(p_email_address),
      p_full_name,
      lower(p_email_address), 
      sys_guid(),
      v('APP_SESSION'),
      arcsql.str_random(12)||'x!',
      p_account_status) returning user_id into v_user_id;
   set_password (
      p_user_id=>v_user_id,
      p_password=>p_password);
   k2.fire_event_proc(p_proc_name=>'after_create_account', p_parm=>v_user_id);
   return v_user_id;
end;

/*

### add_account (procedure)

See add account function.

*/

procedure add_account (
   p_email_address in varchar2,
   p_full_name in varchar2,
   p_password in varchar2,
   p_account_status in varchar2 default 'inactive') is 
   v_user_id number;
begin 
   v_user_id := add_account (
      p_email_address=>p_email_address,
      p_full_name=>p_full_name,
      p_password=>p_password,
      p_account_status=>p_account_status);
end;

function custom_auth ( -- | Custom authorization function registered as APEX authorization scheme.
   p_username in varchar2,
   p_password in varchar2) return boolean is
   r saas_auth%rowtype;
   v_password                    saas_auth.password%type;
   v_user_name                   saas_auth.user_name%type := lower(p_username);
   v_user_id                     saas_auth.user_id%type;

begin
   arcsql.debug('custom_auth: user='||v_user_name);
   arcsql.count_request(p_request_key=>'saas_auth');
   raise_too_many_auth_requests;
   raise_user_name_not_found(v_user_name);

   v_user_id := to_user_id(p_user_name=>v_user_name);

   assert_account_is_allowed_to_login(v_user_id);

   r := get_saas_auth_row(p_user_id=>v_user_id);

   v_password := get_hashed_password(p_secret_string=>r.uuid||p_password);

   arcsql.debug_secret('v_password='||v_password||', v_stored_password='||r.password);
   if v_password=r.password then
      arcsql.debug('custom_auth: true');
      register_login(v_user_id);
      return true;
   end if;

   -- Things have failed if we get here.
   update saas_auth 
      set last_failed_login=sysdate,
          failed_login_count=failed_login_count+1,
          last_session_id=v('APP_SESSION')
    where user_id=r.user_id;
   arcsql.debug('custom_auth: false');
   return false;
   -- ToDo: May want to add fire_failed_login event here.
exception 
   when others then
      arcsql.log_err('custom_auth: '||dbms_utility.format_error_stack);
      return false;
end;

-- ToDo: Port this to fire_proc thing.
procedure post_auth is
   cursor package_names is 
   -- Looks for any procedure name called "post_auth" in any user owned
   -- packages and executes the procedure. This allows you to write your
   -- own post_auth events. Ideally it would be nice to pass the user name.
   select name from user_source 
    where lower(text) like '% post_auth;%'
      and name not in ('SAAS_AUTH_PKG')
      and type='PACKAGE';
begin
   arcsql.debug('post_auth: saas_auth_pkg');
   for n in package_names loop 
      arcsql.debug('post_auth: '||n.name||'.post_auth');
      execute immediate 'begin '||n.name||'.post_auth; end;';
   end loop;
end;

function is_admin ( -- | Return true if account type is admin or system.
   p_user_id in number) return boolean is
   n number;
begin
   select count(*) into n
    from saas_auth
   where account_type in ('admin', 'system');
   return n = 1;
end;

function user_id 
   return number is 
   v_app_user varchar2(128);
begin
   arcsql.debug('user_id: '||v('APP_USER')||', '||g_app_user);
   v_app_user := nvl(trim(v('APP_USER')), g_app_user);
   if saas_auth_pkg.does_user_name_exist(p_user_name=>v_app_user) then
      return to_user_id(p_user_name => v_app_user);
   else 
      -- Often use this func when session may not be authenticated and we would get errors if we try to use to_user_id and not authenticated.
      return null;
   end if;
end;

end;
/


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

procedure fire_user_event (
   p_event_name in varchar2,
   p_user_id in number) is 
   n number;
begin 
   arcsql.debug('fire_user_event: '||p_event_name);
   select count(*) into n from user_source
    where name = upper(p_event_name)
      and type='PROCEDURE';
   if n > 0 then 
      execute immediate 'begin '||p_event_name||'('||p_user_id||'); end;';
   end if;
end;

function get_saas_auth_row ( -- | Return a row from saas_auth using the user_id.
   p_user_id in number)
   return saas_auth%rowtype is 
   r saas_auth%rowtype;
begin
   select * into r from saas_auth where user_id=p_user_id;
   return r;
end; 

procedure logout is -- | Used to log a user out if called from the UI.
   -- WARNING: I think this may throw a rollback so anything that does work and calls this needs to commit first!
begin 
   arcsql.debug('logout: ');
   apex_authentication.logout(v('APP_SESSION'), v('APP_ID'));
   -- Do not call fire_on_logout here! post_logout will run automatically and it will get called.
exception 
   when others then
      arcsql.log_err('logout: '||dbms_utility.format_error_stack);
      raise;
end;

procedure set_session_time_zone ( -- | Sets the time zone for user when logging in.
   p_user_id in number) is 
   s saas_auth%rowtype;
   v_offset varchar2(12);
begin 
   arcsql.debug('set_session_time_zone: user_id='||p_user_id);
   s := get_saas_auth_row(p_user_id=>p_user_id);
   select tz_offset(s.timezone_name) into v_offset from dual;
   apex_util.set_session_time_zone(p_time_zone=>v_offset);
exception 
   when others then
      arcsql.log_err('set_session_time_zone: '||dbms_utility.format_error_stack);
      raise;
end;

procedure register_login ( -- | Updates saas_auth row for user anytime a login occurs.
   p_user_id in varchar2) is 
   n number;
begin 
   arcsql.debug('file_login_event: user='||p_user_id);
   update saas_auth 
      set auth_token_expire=sysdate,
          last_login=sysdate,
          login_count=login_count+1,
          last_session_id=v('APP_SESSION'),
          failed_login_count=0
    where user_id=p_user_id;
   set_session_time_zone(p_user_id);
exception 
   when others then
      arcsql.log_err('register_login: '||dbms_utility.format_error_stack);
      raise; 
   /*
   | This procedure looks for the on_login procedure and calls it if it exists.
   | Apps should create a custom on_login procedure to capture login events.
   */
end;

procedure login ( -- | Login with username only.
   p_user_name in varchar2) is 
begin 
   apex_authentication.post_login (
      p_username=>lower(p_user_name), 
      p_password=>utl_raw.cast_to_raw(dbms_random.string('a',12)||'x!'));
end;

procedure generate_new_auth_token ( -- | Generate new auth token for the user.
      p_user_id in number,
      p_expire_minutes in number
      ) is
   new_token varchar2(120);
begin 
   arcsql.debug('generate_new_auth_token: '||p_user_id);
   new_token := sys_guid();
   update saas_auth 
      set auth_token=new_token,
          auth_token_expire=sysdate+(p_expire_minutes/1440)
    where user_id=p_user_id; 
   if sql%rowcount=0 then
      raise_application_error(-20001,'User id not found!');
   end if;
exception 
   when others then
      arcsql.log_err('generate_new_auth_token: '||dbms_utility.format_error_stack);
      raise; 
end;

procedure set_auto_login ( -- | Called from login form. Enables or disables auto login based on value of check box.
   p_auto_login varchar2 default 'N') 
   is 
   v_auto_token varchar2(120) := sys_guid();
begin 
   arcsql.debug('set_auto_login: '||p_auto_login);
   if nvl(saas_auth_config.enable_auto_login_days, 0) = 0 then 
      return;
   end if;
   if v('APP_USER') = 'nobody' then 
      -- If login failed this proc still gets called. We don't want it to run.
      return;
   end if;
   if p_auto_login = 'Y' then 
      update saas_auth 
         set auto_token_expire=sysdate+saas_auth_config.enable_auto_login_days,
             auto_token=v_auto_token
       where user_name=lower(v('APP_USER'));
      k2.add_cookie(
         p_name=>'auto_token', 
         p_value=>v_auto_token,
         p_expires=>sysdate+saas_auth_config.enable_auto_login_days,
         p_user_name=>v('APP_USER'));
   else
      update saas_auth 
         set auto_token_expire=null,
             auto_token=null
       where user_name=lower(v('APP_USER'));
   end if;
exception 
   when others then
      arcsql.log_err('set_auto_login: '||dbms_utility.format_error_stack);
      raise;
end;

function get_auto_token_from_cookie -- | Return the value of the auto_token cookie.
   return varchar2 is 
begin 
   arcsql.debug('get_auto_token_from_cookie: ');
   return k2.get_cookie('auto_token');
exception 
   when others then
      arcsql.log_err('get_auto_token_from_cookie: '||dbms_utility.format_error_stack);
      raise;
end;

function is_able_to_auto_login_with_auto_token -- | Return true if conditions allow logging in with an auto login token.
   return boolean is 
   n number;
   t saas_auth.auto_token%type;
begin 
   arcsql.debug('is_able_to_auto_login_with_auto_token: '||v('APP_USER')||', '||v('APP_SESSION'));
   if v('APP_USER') != 'nobody' then 
      arcsql.debug2('App user is not nobody: '||v('APP_USER'));
      -- User is already logged in as someone
      return false;
   end if;
   t := get_auto_token_from_cookie;
   if t is null then 
      arcsql.debug2('auto_token cookie is null.');
      return false;
   end if;
   select count(*) into n 
     from saas_auth 
    where auto_token=t
      and (auto_token_expire > sysdate or auto_token_expire is null);
   if n = 0 then 
      arcsql.debug2('Auto login token not valid for this device or expired.');
      return false;
   end if;
   if apex_custom_auth.session_id_exists then 
      arcsql.debug2('Session id exists.');
   else 
      arcsql.debug2('Session id does not exist.');
   end if;
   return true;
exception 
   when others then
      arcsql.log_err('is_able_to_auto_login_with_auto_token: '||dbms_utility.format_error_stack);
      raise;
end;

procedure auto_login is -- | Triggers an auto login if a valid token in in query string or cookie.
   v_user_id number;
   v_token saas_auth.auto_token%type;
   r saas_auth%rowtype;
begin 
   arcsql.debug('auto_login: '||v('APP_USER')||', '||v('APP_SESSION'));

   if lower(owa_util.get_cgi_env('QUERY_STRING')) like '%auth\_token%' escape '\' then 
      return;
   end if;

   -- We will attempt to auto login using token in cookie.

   if not is_able_to_auto_login_with_auto_token then 
      return;
   end if;

   v_token := get_auto_token_from_cookie;

   -- ToDo: Need to return a nice error if the token has expired or redirect to login page.
   select user_id into v_user_id
     from saas_auth
    where auto_token=v_token
      and auto_token_expire > sysdate
      and account_status='active';

   r := get_saas_auth_row(p_user_id=>v_user_id);
   
   arcsql.log_security_event(p_text=>'auto_login: '||r.user_name, p_key=>'saas_auth');
   apex_authentication.post_login (
      p_username=>r.user_name, 
      p_password=>utl_raw.cast_to_raw(dbms_random.string('x',12)));
   register_login(p_user_id=>v_user_id);
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

function get_email_override_when_set ( -- | Returns the override address if set otherwise returns the original address.
   p_email varchar2) return varchar2 is 
begin 
   return nvl(trim(app_config.email_override), p_email);
end;  

procedure assert_password_passes_complexity_check ( -- | Raises error if password does not adhere to defined specifications.
   p_password in varchar2) is 
begin 
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

procedure fire_on_logout_event ( -- | Fired at the end of the post_logout procedure. Call the on_logout procedure if it exists. Passes user_id to it.
   p_user_id in varchar2) is 
   n number;
begin 
   select count(*) into n from user_source 
    where name = 'ON_LOGOUT'
      and type='PROCEDURE';
   if n > 0 then 
      arcsql.debug('fire_on_logout_event: '||p_user_id);
      execute immediate 'begin on_logout('||p_user_id||'); end;';
   end if;
exception 
   when others then
      arcsql.log_err('fire_on_logout_event: '||dbms_utility.format_error_stack);
      raise;
end;

procedure post_logout is -- | Run as part of the custom authenticaton scheme.
begin 
   arcsql.debug('post_logout: user='||v('APP_USER'));
   update saas_auth
      set auto_login=null,
          auto_token=null 
    where user_name=lower(v('APP_USER'));
   fire_on_logout_event(to_user_id(p_user_name=>v('APP_USER')));
exception 
   when others then
      arcsql.log_err('post_logout: '||dbms_utility.format_error_stack);
      raise;
end;

procedure set_password ( -- | Sets a user password. 
   p_user_id in number,
   p_password in varchar2) is 
   hashed_password varchar2(120);
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

function is_auth_token_valid ( -- | Return true if the auth token is legit and has not expired.
   p_auth_token in varchar2) return boolean is
   n number;
begin 
   select count(*) into n from saas_auth
    where auth_token=p_auth_token
      and (auth_token_expire is null or auth_token_expire > sysdate);
   return n = 1;
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

procedure send_one_time_login_link (  -- | Sends a one time login link to a user.
   p_user_id in number,
   p_subject in varchar2,
   p_body in varchar2,
   p_expire_minutes in number default 60,
   p_redirect in varchar2 default 'home') is 
   v_app_name     varchar2(120)                             := app_config.app_name;
   v_app_id       number                                    := k2_utl.get_app_id;
   v_from_address varchar2(120)                             := app_config.app_from_email;
   m              varchar2(24000);
   v_saas_auth    saas_auth%rowtype;
   page_url       varchar2(1200);
begin 

   generate_new_auth_token(p_user_id=>p_user_id, p_expire_minutes=>p_expire_minutes);
   v_saas_auth := get_saas_auth_row(p_user_id=>p_user_id);

   m := p_body;
   m := replace(m, '#APP_NAME#', v_app_name);
   page_url := k2.monkey_patch_remove_app_root_url(apex_page.get_url (
                  p_application=>k2_utl.get_app_id,
                  p_page=>'auth-token',
                  -- Note that spaces after a comma seem to get included in the values. Recommend you don't use them.
                  p_items=>'AUTH_TOKEN,REDIRECT',
                  p_values=>v_saas_auth.auth_token||','||p_redirect));
   -- get_url is adding a checksum which I don't want for now.
   -- page_url := k2.remove_checksum_from_url(page_url);
   m := replace(m, '#ONE_TIME_LOGIN_LINK#', page_url);

   m := apex_markdown.to_html(
         p_markdown=>m, 
         p_embedded_html_mode=>'PRESERVE',
         p_softbreak=>'<br />', 
         p_extra_link_attributes=>apex_t_varchar2('target', '_blank'));

   app_send_email (
      p_from=>v_from_address,
      p_to=>get_email_override_when_set(v_saas_auth.email),
      p_subject=>p_subject,
      p_body=>m);

exception 
   when others then
      arcsql.log_err('send_one_time_login_link: '||dbms_utility.format_error_backtrace);
      raise;
end; 

procedure send_forgot_pass_email (  -- | Sends a one time login link to a user.
   p_user_id in number) is 
begin 
   send_one_time_login_link (
      p_user_id=>p_user_id,
      p_body=>saas_auth_one_time_login_body,
      p_subject=>saas_auth_one_time_login_subject,
      p_expire_minutes=>saas_auth_config.forgot_pass_expire_minutes,
      p_redirect=>saas_auth_config.forgot_pass_redirect);
exception 
   when others then
      arcsql.log_err('send_forgot_pass_email: '||dbms_utility.format_error_stack);
      raise;
end;  

procedure send_verify_email_request (  -- | Sends a verification code to a user if the account is valid.
   p_user_id in number) is 
begin 
   assert_account_is_inactive(p_user_id=>p_user_id);
   send_one_time_login_link (
      p_user_id=>p_user_id,
      p_body=>saas_auth_verify_email_body,
      p_subject=>saas_auth_verify_email_subject,
      p_expire_minutes=>saas_auth_config.verify_email_expire_minutes,
      p_redirect=>saas_auth_config.verify_email_redirect);
exception 
   when others then
      arcsql.log_err('send_verify_email_request: '||dbms_utility.format_error_stack);
      raise;
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

procedure assert_password_prefix_present_if_required ( -- | -- Raises error if password prefix is defined and the password does not use it.
   p_password in varchar2) is 
   v_prefix varchar2(120);
begin 
   v_prefix := trim(saas_auth_config.saas_auth_pass_prefix);
   if v_prefix is not null then 
      if substr(p_password, 1, length(v_prefix)) != v_prefix then 
         arcsql.log_security_event(p_text=>'assert_password_prefix_present_if_required: ', p_key=>'saas_auth');
         raise_error('This app is in a restricted access mode. Please contact support if you need further assistance.');
      end if;
   end if;
end;

function to_user_id ( -- | Returns user id using user name.
   p_user_name in varchar2) return number is
   r saas_auth%rowtype;
begin
   select * into r from saas_auth where user_name=lower(p_user_name);
   return r.user_id;
end;

function to_user_id ( -- | Returns user id using verification token.
   p_auth_token in varchar2) return number is
   r saas_auth%rowtype;
begin
   select * into r 
     from saas_auth 
    where auth_token=p_auth_token
      and (auth_token_expire is null or auth_token_expire >= sysdate);
   return r.user_id;
end;

procedure raise_does_not_appear_to_be_an_email_format ( -- | Raises an error if the string does not look like an email.
   p_email in varchar2) is 
begin 
   if not arcsql.str_is_email(p_email) then 
      raise_error('Email does not appear to be a valid email address.');
   end if;
end;

procedure delete_user ( -- | Delete user account by id. Throw an error if the user_id is invalid.
   p_user_id in number) is 
begin 
   arcsql.debug('delete_user: '||p_user_id);
   fire_user_event(p_event_name=>'before_delete_user', p_user_id=>p_user_id);
   delete from saas_auth 
    where user_id=p_user_id;
   fire_user_event(p_event_name=>'after_delete_user', p_user_id=>p_user_id);
   arcsql.log_security_event(p_text=>'delete_user: '||p_user_id, p_key=>'saas_auth');
exception 
   when others then
      -- arcsql.log_err('delete_user: '||dbms_utility.format_error_stack);
      raise;
end;

procedure add_system_user ( -- | Add an user account for a system user.
   p_user_name in varchar2,
   p_email in varchar2) is 
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
         lower(p_email), 
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

procedure process_login ( -- | Process the 'login' page.
   p_user_name in varchar2,
   p_password in varchar2,
   p_timezone_name in varchar2 default saas_auth_config.default_timezone,
   p_auto_login in varchar2 default 'N') is 
   v_user_id number;
begin 
   arcsql.debug('process_login: '||p_user_name);
   v_user_id := to_user_id(p_user_name=>p_user_name);
   fire_user_event(p_event_name=>'before_user_login', p_user_id=>v_user_id);
   assert_account_is_allowed_to_login(p_user_id=>v_user_id);
   apex_authentication.login (
      p_username => lower(p_user_name),
      p_password => p_password);
   saas_auth_pkg.set_timezone_name (
      p_user_name => lower(p_user_name),
      p_timezone_name => p_timezone_name);
   saas_auth_pkg.set_auto_login(p_auto_login => p_auto_login);
   fire_user_event(p_event_name=>'after_user_login', p_user_id=>v_user_id);
end;

procedure process_auth_token ( -- | Called from the 'auth-token' page. Processes the token passed to the page.
   p_auth_token in varchar2,
   p_redirect in varchar2 default 'home' -- | Desired page alias to branch to if the token is valid.
   ) is 
   v_user_id number;
   r saas_auth%rowtype;
   v_redirect varchar2(120) := trim(p_redirect);
begin 
   arcsql.debug('process_auth_token: '||p_auth_token||', '||v_redirect);

   if not is_auth_token_valid(p_auth_token) then
      k2.add_flash_message('Invalid authorization token.');
      arcsql.log_security_event(p_text=>'Invalid authorization token: '||p_auth_token, p_key=>'saas_auth');
      v_redirect := 'error';
   else
      v_user_id := to_user_id(p_auth_token=>p_auth_token);
      r := get_saas_auth_row(p_user_id=>v_user_id);
      update saas_auth set auth_token_expire=sysdate where user_id=v_user_id;
      if r.account_status = 'inactive' then 
         update saas_auth set account_status='active', email_verified=sysdate where user_id=v_user_id;
         fire_user_event(p_event_name=>'activate_account', p_user_id=>v_user_id);
      end if;
      login (p_user_name=>r.user_name);
   end if;
   commit;
   apex_util.redirect_url(p_url => apex_page.get_url(p_page => v_redirect));
exception
   when others then
      arcsql.log_err('process_auth_token: '||dbms_utility.format_error_stack);
      raise;
end;     

procedure process_forgot_pass ( -- | Called from the 'forgot-pass' page. Processes the form.
   p_user_name in varchar2) is
   v_user_id number;
begin 
   arcsql.debug('process_forgot_pass: '||p_user_name);
   if not arcsql.str_is_email(p_user_name) then 
      raise_error('Invalid email address.');
   end if;
   if does_user_name_exist(p_user_name=>p_user_name) then 
      v_user_id := to_user_id(p_user_name=>p_user_name);
      send_forgot_pass_email(p_user_id=>v_user_id);
   end if;
   k2.add_flash_message('We sent you an email with a link you can use to log in and change your password.');
end;

procedure process_change_pass (
   p_user_id in number,
   p_password in varchar2) is 
begin 
   arcsql.debug('process_change_pass: '||p_user_id||', '||p_password);
   assert_password_passes_complexity_check(p_password=>p_password);
   set_password(p_user_id=>p_user_id, p_password=>p_password);
end;

procedure assert_valid_email_format ( -- | Throw an error if the email address format looks invalid.
   p_email in varchar2) is 
begin
   if not arcsql.str_is_email(p_email) then 
      raise_error('Invalid email address.');
   end if;
end;

procedure add_account (
   p_email in varchar2,
   p_full_name in varchar2,
   p_password in varchar2,
   p_account_status in varchar2 default 'inactive') is 
   v_user_id number;
begin 
   -- This code is similar to process_create_account but we would need to return the new user_id in we wanted to refactor.
   insert into saas_auth (
      user_name,
      full_name,
      email, 
      uuid,
      last_session_id,
      password,
      account_status) values (
      -- For now user name is email
      lower(p_email),
      p_full_name,
      lower(p_email), 
      sys_guid(),
      v('APP_SESSION'),
      arcsql.str_random(12)||'x!',
      p_account_status) returning user_id into v_user_id;
   set_password (
      p_user_id=>v_user_id,
      p_password=>p_password);
   fire_user_event(p_event_name=>'after_create_account', p_user_id=>v_user_id);
end;

procedure process_create_account ( -- | Add email to the saas_auth table with an unknown password and unverified email.
   p_email in varchar2,
   p_full_name in varchar2,
   p_password in varchar2) is 
   n number;
   r saas_auth%rowtype;
   v_user_id number;
begin 
   arcsql.debug('process_create_account: '||p_email);

   assert_password_passes_complexity_check(p_password=>p_password);
   assert_valid_email_format(p_email=>p_email);
   assert_password_prefix_present_if_required(p_password=>p_password);

   select count(*) into n from saas_auth
    where user_name=lower(p_email);

   -- If the account already exists
   if n = 1 then 
      -- And the status is still 'inactive'
      r := get_saas_auth_row(p_user_id=>to_user_id(p_user_name=>p_email));
      if r.account_status = 'inactive' then 
         -- Update the password and full name because the user has never logged in
         set_password (
            p_user_id=>r.user_id,
            p_password=>p_password);
         update saas_auth 
            set full_name=p_full_name
          where user_id=r.user_id;
         send_verify_email_request(p_user_id=>r.user_id);
      else 
         arcsql.log_security_event('process_create_account: Account already exists: '||r.user_name, p_key=>'saas_auth');
         raise_application_error(-20001, 'There was a problem creating your account. Please contact support.');
      end if;
   end if;

   if n = 0 then
      insert into saas_auth (
         user_name,
         full_name,
         email, 
         uuid,
         last_session_id,
         password,
         account_status) values (
         -- For now user name is email
         lower(p_email),
         p_full_name,
         lower(p_email), 
         sys_guid(),
         v('APP_SESSION'),
         arcsql.str_random(12)||'x!',
         'inactive') returning user_id into v_user_id;
      set_password (
         p_user_id=>v_user_id,
         p_password=>p_password);
      send_verify_email_request(p_user_id=>v_user_id);
      fire_user_event(p_event_name=>'after_create_account', p_user_id=>v_user_id);
   end if;
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

   arcsql.debug('v_password='||v_password||', v_stored_password='||r.password);
   if v_password=r.password then
      arcsql.debug('custom_auth: true');
      register_login(v_user_id);
      return true;
   end if;

   -- Things have failed if we get here.
   update saas_auth 
      set auth_token_expire=sysdate,
          last_failed_login=sysdate,
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

end;
/

create or replace package body saas_auth_pkg as

function get_saas_auth_role_row ( -- | Return a role row using the role name as a look up.
   p_role_name in varchar2) 
   return saas_auth_role%rowtype is 
   r saas_auth_role%rowtype;
begin
   select * into r from saas_auth_role where lower(role_name) = lower(p_role_name);
   return r;
end;

procedure assign_user_role ( -- | Set the role id in the saas_auth table for a user using the role name.
   p_user_id in number,
   p_role_name in varchar2) is 
   r saas_auth_role%rowtype;
begin
   r := get_saas_auth_role_row(p_role_name);
   update saas_auth set role_id=r.role_id where user_id=p_user_id;
   if sql%rowcount = 0 then 
      raise_application_error(-20001, 'User not found');
   end if;
exception
   when others then
      arcsql.log_err('assign_user_role: '||dbms_utility.format_error_stack);
      raise;
end;

function get_saas_auth_row (
   p_user_id in number)
   return saas_auth%rowtype is 
   r saas_auth%rowtype;
begin
   select * into r from saas_auth where user_id=p_user_id;
   return r;
end;

procedure assert_user_id_is_valid (
   p_user_id in number) is
   n number;
begin
   select count(*) into n from saas_auth where user_id=p_user_id;
   if n = 0 then 
      raise_application_error(-20001, 'Invalid user_id: '||p_user_id);
   end if;
end;

procedure increment_email_count (
   p_email_address in varchar2) is 
begin 
   update saas_auth
      set email_count=email_count+1,
          last_email=systimestamp
    where email=lower(p_email_address);
exception
   when others then 
      arcsql.log_err('increment_email_count: '||dbms_utility.format_error_stack);
      raise;
end;  

function days_since_last_login ( -- | Return the number of days since the user has logged in.
   p_user_id in number) return number as
   l_days_since_last_login number;
begin 
   select (sysdate - last_login) into l_days_since_last_login from saas_auth where user_id = p_user_id;
   return round(l_days_since_last_login);
exception 
   when others then
      arcsql.log_err('days_since_last_login: '||dbms_utility.format_error_stack);
end;

procedure automation_daily is -- | Tasks which should be scheduled to run daily.
   cursor remove_users is 
   select * from saas_auth where remove_date <= sysdate;
begin
   arcsql.debug('automation_daily: ');
   for c in remove_users loop 
      delete_user(p_user_id=>c.user_id);
   end loop;
exception 
   when others then
      arcsql.log_err('automation_daily: '||dbms_utility.format_error_stack);
      raise;
end;

procedure purge_deleted_accounts ( -- Delete accounts from saas_auth where status = 'delete' for p_days days.
   p_days in number default 7) is 
begin 
   arcsql.debug('purge_deleted_accounts: ');
   delete from saas_auth where account_status='delete' and remove_date > sysdate + p_days;
exception 
   when others then
      arcsql.log_err('purge_deleted_accounts: '||dbms_utility.format_error_stack);
      raise;
end;


procedure logout is -- | Used to log a user out if called from the UI.
   -- WARNING: I think this may throw a rollback so anything that does work and calls this needs to commit first!
begin 
   arcsql.debug('logout: ');
   apex_authentication.logout(v('APP_SESSION'), v('APP_ID'));
   -- No not call fire_on_logout here! post_logout will run automatically and it will get called.
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
   select * into s from saas_auth where user_id=p_user_id and account_status='active';
   select tz_offset(s.timezone_name) into v_offset from dual;
   apex_util.set_session_time_zone(p_time_zone=>v_offset);
exception 
   when others then
      arcsql.log_err('set_session_time_zone: '||dbms_utility.format_error_stack);
      raise;
end;


procedure fire_on_login_event ( -- | Fired when a login occurs.
   --
   -- This is the hook apps using auth can use to trigger workflow when a user logs on.
   p_user_id in varchar2) is 
   n number;
begin 
   arcsql.debug('file_login_event: user='||p_user_id);
   update saas_auth 
      set reset_pass_token=null, 
          reset_pass_expire=null,
          last_login=sysdate,
          login_count=login_count+1,
          last_session_id=v('APP_SESSION'),
          failed_login_count=0
    where user_id=p_user_id;
   select count(*) into n from user_source 
    where name = 'ON_LOGIN'
      and type='PROCEDURE';
   if n > 0 then 
      arcsql.debug('fire_on_login_event: '||p_user_id);
      execute immediate 'begin on_login('||p_user_id||'); end;';
   end if;
   set_session_time_zone(p_user_id);
   -- set_login_cookie;
exception 
   when others then
      arcsql.log_err('fire_on_login_event: '||dbms_utility.format_error_stack);
      raise; 
   /*
   | This procedure looks for the on_login procedure and calls it if it exists.
   | Apps should create a custom on_login procedure to capture login events.
   */
end;


function is_valid_auth_token ( -- | Return true if the token is valid.
   p_auth_token in saas_auth_token.auth_token%type) 
   return boolean 
   is 
   n number;
begin 
   arcsql.debug('is_valid_auth_token: '||p_auth_token);
   select count(*) into n 
     from saas_auth_token a,
          saas_auth b
    where a.user_id=b.user_id 
      and b.account_status = 'active'
      and a.auth_token=p_auth_token 
      and (a.expires_at is null or a.expires_at > sysdate)
      and a.use_count < a.max_use_count;
   return n = 1;
   arcsql.log_security_event('is_valid_auth_token: Invalid authorization token.');
   raise_application_error(-20001, 'Invalid authorization token.');
exception 
   when others then
      arcsql.log_err('is_valid_auth_token: '||dbms_utility.format_error_stack);
      raise; 
end;


function is_auth_token_auto_login_enabled ( -- | Is the token an auto-login token?
   p_auth_token in saas_auth_token.auth_token%type) 
   return boolean 
   is 
   v_auto_login saas_auth_token.auto_login%type;
begin
   arcsql.debug('is_auth_token_auto_login_enabled: ');
   select a.auto_login into v_auto_login
     from saas_auth_token a,
          saas_auth b
    where a.user_id=b.user_id 
      and b.account_status='active'
      and a.auth_token=p_auth_token;
   return v_auto_login = 'Y';
exception 
   when others then
      arcsql.log_err('is_auth_token_auto_login_enabled: '||dbms_utility.format_error_stack);
      raise; 
end;


procedure check_auth_token_auto_login ( -- | Called from the UI. If token is valid and auto-login token, the user is logged in.
   p_auth_token in saas_auth_token.auth_token%type)
   is 
   v_user_id saas_auth.user_id%type;
   v_user_name saas_auth.user_name%type;
begin 
   arcsql.debug('check_auth_token_auto_login: ');
   v_user_id := get_user_id_from_auth_token(p_auth_token);
   v_user_name := get_user_name(v_user_id);
   if is_auth_token_auto_login_enabled(p_auth_token) then 
      apex_authentication.post_login (
         p_username=>v_user_name, 
         p_password=>utl_raw.cast_to_raw(dbms_random.string('x',10)));
         fire_on_login_event(saas_auth_pkg.get_user_id_from_user_name(v_user_name));
   end if;
exception 
   when others then
      arcsql.log_err('check_auth_token_auto_login: '||dbms_utility.format_error_stack);
      raise; 
end;


-- ToDo: Could add last_use_date to table.
procedure use_auth_token ( -- | Registers use of a token.
   p_auth_token in varchar2) 
   is 
begin 
   arcsql.debug('use_auth_token: ');
   update saas_auth_token 
      set use_count=use_count+1 
    where auth_token=p_auth_token;
exception 
   when others then
      arcsql.log_err('use_auth_token: '||dbms_utility.format_error_stack);
      raise; 
end;


function get_user_id_from_auth_token ( -- | Get the user id a token is linked to.
   p_auth_token in varchar2) return number is 
   v_user_id saas_auth.user_id%type;
begin 
   arcsql.debug('get_user_id_from_auth_token: ');
   select user_id into v_user_id 
     from saas_auth_token 
    where auth_token = p_auth_token
      and (expires_at is null or expires_at > sysdate)
      and use_count < max_use_count;
   return v_user_id;
exception 
   when others then
      arcsql.log_err('get_user_id_from_auth_token: '||dbms_utility.format_error_stack);
      raise; 
end;


function get_new_auth_token ( -- | Generates a new token for a user.
   p_user_name in varchar2 default null,
   p_user_id in number default null,
   p_expires_at in date default null,
   p_auto_login in boolean default false,
   p_max_use_count in number default 1
   ) return varchar2 is 
   v_user_name saas_auth.user_name%type := lower(p_user_name);
   v_user_id saas_auth.user_id%type := p_user_id;
   new_token varchar2(120);
   v_auto_login saas_auth_token.auto_login%type := 'N';
begin 
   arcsql.debug('get_new_auth_token: ');
   if v_user_id is null and v_user_name is null then 
      raise_application_error(-20001, 'get_new_auth_token: Must provide a user name or user id.');
   elsif v_user_id is null then 
      v_user_id := get_user_id_from_user_name(v_user_name);
   elsif v_user_name is null then 
      v_user_name := get_user_name(v_user_id);
   end if;
   new_token := sys_guid();
   if p_auto_login then 
      v_auto_login := 'Y';
   end if;
   insert into saas_auth_token (
      user_id,
      user_name,
      auth_token,
      expires_at,
      auto_login,
      max_use_count) values (
      v_user_id,
      v_user_name,
      new_token,
      p_expires_at,
      v_auto_login,
      p_max_use_count
      );
   arcsql.log_security_event(p_text=>'get_new_auth_token: '||p_user_name, p_key=>'saas_auth');
   return new_token;
exception 
   when others then
      arcsql.log_err('get_new_auth_token: '||dbms_utility.format_error_stack);
      raise; 
end;


procedure set_auto_login ( -- | Called from login form. Enables or disables auto login based on value of check box.
   p_auto_login varchar2 default 'N') 
   is 
   v_auto_login_token varchar2(120) := sys_guid();
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
         set auto_login=sysdate+saas_auth_config.enable_auto_login_days,
             auto_login_token=v_auto_login_token
       where user_name=lower(v('APP_USER'));
      k2.add_cookie(
         p_name=>'auto_login_token', 
         p_value=>v_auto_login_token,
         p_expires=>sysdate+saas_auth_config.enable_auto_login_days,
         p_user_name=>v('APP_USER'));
   else
      update saas_auth 
         set auto_login=null,
             auto_login_token=null
       where user_name=lower(v('APP_USER'));
   end if;
exception 
   when others then
      arcsql.log_err('set_auto_login: '||dbms_utility.format_error_stack);
      raise;
end;


function get_auto_login_token -- | Return the value of the auto_login_token cookie.
   return varchar2 is 
begin 
   arcsql.debug('get_auto_login_token: ');
   return k2.get_cookie('auto_login_token');
exception 
   when others then
      arcsql.log_err('get_auto_login_token: '||dbms_utility.format_error_stack);
      raise;
end;


function is_able_to_auto_login return boolean is 
   n number;
   t saas_auth.auto_login_token%type := get_auto_login_token;
begin 
   arcsql.debug('is_able_to_auto_login: user='||v('APP_USER')||', session='||v('APP_SESSION'));
   if v('APP_USER') != 'nobody' then 
      arcsql.debug('App user is not nobody: '||v('APP_USER'));
      return false;
   end if;
   if t is null then 
      arcsql.debug('auto_login_token cookie is null.');
      return false;
   end if;
   select count(*) into n 
     from saas_auth 
    where auto_login_token=t
      and (auto_login > sysdate or auto_login is null);
   if n = 0 then 
      arcsql.debug('Auto login token not valid for this device or expired.');
      return false;
   end if;
   if apex_custom_auth.session_id_exists then 
      arcsql.debug('Session id exists.');
   else 
      arcsql.debug('Session id does not exist.');
   end if;
   return true;
exception 
   when others then
      arcsql.log_err('is_able_to_auto_login: '||dbms_utility.format_error_stack);
      raise;
end;


procedure auto_login is 
   
   v_user_name saas_auth.user_name%type;
   t saas_auth.auto_login_token%type := get_auto_login_token;
begin 
   arcsql.debug('auto_login: user='||v('APP_USER')||', session='||v('APP_SESSION'));

   if not is_able_to_auto_login then 
      return;
   end if;
   
   -- Figure out user and log them in.
   select user_name into v_user_name 
     from saas_auth 
    where auto_login_token=t
      and auto_login > sysdate
      and account_status='active';
   arcsql.log_security_event(p_text=>'auto_login: '||v_user_name, p_key=>'saas_auth');
   apex_authentication.post_login (
      p_username=>lower(v_user_name), 
      p_password=>utl_raw.cast_to_raw(dbms_random.string('x',10)));
   -- fire_on_login_event(get_user_id_from_user_name(v_user_name));
exception 
   when others then
      arcsql.log_err('auto_login: '||dbms_utility.format_error_stack);
      raise;
end;


function get_current_time_for_user ( -- | Return a timestamp for the current time using tz for the user.
   p_user_id in number) 
   return timestamp is -- | Returns null if a timezone name can't be identified. Good idea to set k2_config.default_timezone to avoid that.
   v_timezone_name saas_auth.timezone_name%type;
   t timestamp;
begin 
   select timezone_name into v_timezone_name
     from saas_auth 
    where user_id=p_user_id;
   if v_timezone_name is null then 
      v_timezone_name := k2_config.default_timezone;
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


procedure set_remove_date (
   p_user_id in number,
   p_date in date) is 
begin 
   update saas_auth set remove_date=p_date where user_id=p_user_id;
exception 
   when others then
      arcsql.log_err('set_remove_date: '||dbms_utility.format_error_stack);
      raise;
end;


procedure set_status_delete (
   p_user_id in number) is 
begin 
   arcsql.debug('set_status_delete: '||p_user_id);
   update saas_auth set account_status='delete' where user_id=p_user_id;
   arcsql.debug('set_status_delete: '||sql%rowcount);
exception 
   when others then
      arcsql.log_err('set_status_delete: '||dbms_utility.format_error_stack);
      raise;
end;

procedure ui_delete_account (
   p_auth_token in varchar2) is 
   v_user_id saas_auth.user_id%type;
begin 
   arcsql.log_security_event(p_text=>'ui_delete_account: '||p_auth_token, p_key=>'saas_auth');
   if is_valid_auth_token (p_auth_token=>p_auth_token) then 
      v_user_id := get_user_id_from_auth_token(p_auth_token=>p_auth_token);
      set_remove_date(p_user_id=>v_user_id, p_date=>trunc(sysdate)+7);
      set_status_delete(p_user_id=>v_user_id);
      -- .0001 is about 7 seconds
      k2.add_flash_message(p_message=>'Your account has been deleted.', p_expires_at=>sysdate+.0001);
      -- Commit before calling logout. I think it may cause a rollback. Status change above was not working until I did this.
      commit;
      logout;
      -- This one was here before adding the one above, leaving it for now, it won't hurt.
      commit;
   end if;
exception 
   when others then
      arcsql.log_err('ui_delete_account: '||dbms_utility.format_error_stack);
      raise;
end;


function does_user_name_exist ( -- | Return true if the user name exists. Does not see some accounts!
   --
   p_user_name in varchar2) return boolean is
   n number;
   v_user_name saas_auth.user_name%type := lower(p_user_name);
begin 
   arcsql.debug('does_user_name_exist: '||v_user_name);
   select count(*) into n 
      from v_saas_auth_available_accounts
     where user_name=v_user_name;
   return n = 1;
exception 
   when others then
      arcsql.log_err('does_user_name_exist: '||dbms_utility.format_error_stack);
      raise;
end;


procedure raise_user_name_not_found (
   -- Raises error if user name does not exist.
   --
   p_user_name in varchar2 default null) is 
begin 
   if not does_user_name_exist(p_user_name) then
      arcsql.log_security_event(p_text=>'raise_user_name_not_found: '||p_user_name, p_key=>'saas_auth');
      raise_application_error(-20001, 'raise_user_name_not_found: '||p_user_name);
   end if;
exception 
   when others then
      arcsql.log_err('raise_user_name_not_found: '||dbms_utility.format_error_stack);
      raise;
end;


function get_uuid (p_user_name in varchar2) return varchar2 is 
   -- Return a user's uuid from user name.
   --
   n number;
   v_uuid saas_auth.uuid%type;
begin 
   select uuid into v_uuid 
     from v_saas_auth_available_accounts
    where user_name=lower(p_user_name);
   return v_uuid;
exception 
   when others then
      arcsql.log_err('get_uuid: '||dbms_utility.format_error_stack);
      raise;
end;


function get_email_override_when_set (
   -- Returns the override address if set otherwise returns the original address.
   --
   p_email varchar2) return varchar2 is 
begin 
   return nvl(trim(saas_auth_config.global_email_override), p_email);
exception 
   when others then
      arcsql.log_err('get_email_override_when_set: '||dbms_utility.format_error_stack);
      raise;
end;  


procedure set_error_message (p_message in varchar2) is 
begin 
   apex_error.add_error (
      p_message          => p_message,
      p_display_location => apex_error.c_inline_in_notification );
exception 
   when others then
      arcsql.log_err('set_error_message: '||dbms_utility.format_error_stack);
      raise;
end;


function does_email_exist (
   -- Return true if the email exists.
   --
   p_email in varchar2) return boolean is
   n number;
   v_email saas_auth.email%type := lower(p_email);
begin 
   arcsql.debug('does_email_exist: '||v_email);
   select count(*) into n 
      from v_saas_auth_available_accounts
     where email=v_email;
   return n = 1;
exception 
   when others then
      arcsql.log_err('does_email_exist: '||dbms_utility.format_error_stack);
      raise;
end;


procedure raise_password_failed_complexity_check (
   p_password in varchar2) is 
begin 
   if not arcsql.str_complexity_check(text=>p_password, chars=>8) then 
      set_error_message('Password needs to be at least 8 characters long.');
      raise_application_error(-20001, 'Password needs to be at least 8 characters long.');
   end if;
   if not arcsql.str_complexity_check(text=>p_password, uppercase=>1) then 
      set_error_message('Password needs at least 1 upper-case character.');
      raise_application_error(-20001, 'Password needs at least 1 upper-case character.');
   end if;
   if not arcsql.str_complexity_check(text=>p_password, lowercase=>1) then 
      set_error_message('Password needs at least 1 lower-case character.');
      raise_application_error(-20001, 'Password needs at least 1 lower-case character.');
   end if;
   if not arcsql.str_complexity_check(text=>p_password, digit=>1) then 
      set_error_message('Password needs at least 1 digit.');
      raise_application_error(-20001, 'Password needs at least 1 digit.');
   end if;
exception 
   when others then
      arcsql.log_err('raise_password_failed_complexity_check: '||dbms_utility.format_error_stack);
      raise;
end;


function get_hashed_password (
   -- Returns SHA256 hash we will store in the password field.
   --
   p_secret_string in varchar2) return raw is
begin
   return arcsql.encrypt_sha256(saas_auth_config.saas_auth_salt || p_secret_string);
exception 
   when others then
      arcsql.log_err('get_hashed_password: '||dbms_utility.format_error_stack);
      raise;
end;


procedure raise_email_not_found (
   p_email in varchar2 default null) is 
   -- Raises error if user is not found.
   n number;
begin 
   arcsql.debug('raise_email_not_found: ');
   if not does_email_exist(p_email) then
      arcsql.log_security_event(p_text=>'raise_email_not_found: '||p_email, p_key=>'saas_auth');
      set_error_message('Email not found.');
      raise_application_error(-20001, 'raise_email_not_found: '||p_email);
   end if;
exception 
   when others then
      arcsql.log_err('raise_email_not_found: '||dbms_utility.format_error_stack);
      raise;
end;


procedure fire_on_logout_event(
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


procedure post_logout is 
begin 
   arcsql.debug('post_logout: user='||v('APP_USER'));
   update saas_auth
      set auto_login=null,
          auto_login_token=null 
    where user_name=lower(v('APP_USER'));
   fire_on_logout_event(get_user_id_from_user_name(v('APP_USER')));
exception 
   when others then
      arcsql.log_err('post_logout: '||dbms_utility.format_error_stack);
      raise;
end;


procedure set_password (
   -- Sets a user password. 
   --
   -- Note that the complexity check does not run here.
   p_user_name in varchar2,
   p_password in varchar2) is 
   hashed_password varchar2(120);
   v_uuid saas_auth.uuid%type;
begin 
   arcsql.debug('set_password: '||p_user_name);
   raise_user_name_not_found(p_user_name=>p_user_name);
   v_uuid := get_uuid(p_user_name=>p_user_name);
   hashed_password := get_hashed_password(p_secret_string=>v_uuid||p_password);
   update saas_auth
      set password=hashed_password
    where user_name=lower(p_user_name);
exception 
   when others then
      arcsql.log_err('set_password: '||dbms_utility.format_error_stack);
      raise;
end;


function is_email_verified (
   -- Return true if email has been verified. 
   --
   p_user_name in varchar2) return boolean is 
   n number;
begin 
   select count(*) into n 
     from v_saas_auth_available_accounts  
    where user_name=lower(p_user_name) 
      and email_verified is not null;
   return n = 1;
end;


function is_email_verification_enabled return boolean is 
begin 
   return saas_auth_config.allowed_logins_before_email_verification_is_required is not null;
end; 


function is_account_locked (
   -- Return true if email has been verified. 
   --
   p_user_name in varchar2) return boolean is 
   n number;
begin 
   select count(*) into n from saas_auth  
    where user_name=lower(p_user_name) 
      and account_status='locked';
   return n=1;
end;


procedure raise_account_is_locked (
   -- Raises an error if the account is locked.
   --
   p_user_name in varchar2) is 
   n number;
begin 
   if is_account_locked(p_user_name) then 
      arcsql.log_security_event(p_text=>'raise_account_is_locked: '||p_user_name, p_key=>'saas_auth');
      raise_application_error(-20001, 'raise_account_is_locked: '||lower(p_user_name));
   end if;
end;


procedure raise_too_many_auth_requests is 
   -- Raises error if too many authorization requests are being made.
   --
begin 
   arcsql.debug('raise_too_many_auth_requests: ');
   if saas_auth_config.auth_request_rate_limit is null then 
      return;
   end if;
   -- If there have been more than 20 requests in the past minute raise an error.
   if arcsql.get_request_count(p_request_key=>'saas_auth', p_min=>10) > saas_auth_config.auth_request_rate_limit then
      arcsql.log_security_event(p_text=>'raise_too_many_auth_requests: '||arcsql.get_request_count(p_request_key=>'saas_auth', p_min=>10), p_key=>'saas_auth');
      set_error_message('Authorization request rate has been exceeded.');
      raise_application_error(-20001, 'Authorization request rate has been exceeded.');
      apex_util.pause(1);
   end if;
end;


function ui_branch_to_main_after_auth (
   -- Go to main page after registration if condition exists.
   --
   p_email in varchar2) return boolean is  
   v_saas_auth saas_auth%rowtype;
begin 
   arcsql.debug('ui_branch_to_main_after_auth: ');
   select * into v_saas_auth from v_saas_auth_available_accounts 
    where email=lower(p_email);
   if v_saas_auth.email_verified is not null then 
      arcsql.debug('true1');
      return true;
   end if;
   if saas_auth_config.allowed_logins_before_email_verification_is_required is null then 
      arcsql.debug('true2');
      return true;
   end if;
   -- Register button was clicked
   if v_saas_auth.login_count = 0 then 
      if saas_auth_config.allowed_logins_before_email_verification_is_required > 0 then 
         arcsql.debug('true3');
         return true;
      end if;
   else
      -- Login button was clicked
      if v_saas_auth.login_count > saas_auth_config.allowed_logins_before_email_verification_is_required then 
         arcsql.debug('true4');
         return true;
      end if;
   end if;
   return false;
end;


procedure send_email_verification_code_to (  -- Sends a verification code to a user if the account is valid.
   p_user_name in varchar2) is 
   t              saas_auth.email_verification_token%type   := arcsql.str_random(6, 'an');
   v_app_name     varchar2(120)                             := k2_config.app_name;
   v_app_id       number                                    := apex_utl2.get_app_id;
   v_from_address varchar2(120)                             := arcsql_cfg.default_email_from_address;
   good_for       number                                    := saas_auth_config.token_good_for_minutes;
   m              varchar2(24000);
   v_saas_auth    saas_auth%rowtype;
   page_url       varchar2(1200);
begin 
   if is_account_locked(p_user_name) then 
      return;
   end if;
   if is_email_verified(p_user_name) then
      return;
   end if;
   if not is_email_verification_enabled then 
      return;
   end if;

   select * into v_saas_auth  
     from v_saas_auth_available_accounts 
    where user_name=lower(p_user_name);

   update saas_auth 
      set email_verification_token=t,
          email_verification_token_expires_at=decode(nvl(good_for, 0), 0, null, sysdate+good_for/1440)
    where user_name=lower(p_user_name);

   m := '### Hello,';
   m := m || '

';
   m := m || '### Thanks for signing up with '||v_app_name||'! Click the link below to verify this email address.';

   page_url := k2.monkey_patch_remove_app_root_url(apex_page.get_url (
                  p_application=>apex_utl2.get_app_id,
                  p_page=>20002,
                  p_items=>'SAAS_AUTH_EMAIL,SAAS_AUTH_TOKEN',
                  p_values=>lower(v_saas_auth.email)||','||t));
   m := m || '

';
   m := m || page_url;
m := m || '

';
   m := m || '**Thanks,**';
   m := m || '
';
   m := m || '**'||k2_config.app_name||'**';

   m := apex_markdown.to_html(
         p_markdown=>m, 
         p_embedded_html_mode=>'PRESERVE',
         p_softbreak=>'<br />', 
         p_extra_link_attributes=>apex_t_varchar2('target', '_blank'));

   send_email (
      p_from=>v_from_address,
      p_to=>get_email_override_when_set(v_saas_auth.email),
      p_subject=>'Welcome to '||v_app_name||'. Please take a second to verify your email.',
      p_body=>m);

   if saas_auth_config.flash_notifications then 
      k2.add_flash_message (
         p_message=>'Look for verification email in your inbox (check spam folder if you don''t see it).',
         p_user_name=>lower(p_user_name),
         p_expires_at=>sysdate+.0002);
   end if;

exception 
   when others then
      arcsql.log_err('send_email_verification_code_to: '||dbms_utility.format_error_backtrace);
      raise;
end;  

procedure verify_email ( -- | Verifies a user's email by updating the saas_auth table.
   p_user_id in number default null,
   p_user_name in varchar2 default null)
   is 
   v_user_id number := p_user_id;
begin 
   if v_user_id is null then 
      v_user_id := get_user_id_from_user_name(p_user_name);
   end if;
   update saas_auth 
      set email_verification_token=null, 
          email_verification_token_expires_at=null, 
          email_verified=sysdate
    where user_id=v_user_id 
      and email_verified is null;
exception 
   when others then
      arcsql.log_err('verify_email: '||dbms_utility.format_error_stack);
      raise;
end;


procedure verify_email_using_token ( -- | Try to verify email using token and if valid log the user in.
   p_email in varchar2,
   p_auth_token in varchar2) is 
   n number;
   v_saas_auth saas_auth%rowtype;
begin 
   arcsql.debug('verify_email_using_token: '||p_auth_token);
   arcsql.count_request(p_request_key=>'saas_auth');
   raise_too_many_auth_requests;   
   raise_email_not_found(p_email);

   select * into v_saas_auth 
     from v_saas_auth_available_accounts 
    where email=lower(p_email);

   if v_saas_auth.email_verification_token = p_auth_token  
      and (v_saas_auth.email_verification_token_expires_at is null 
       or v_saas_auth.email_verification_token_expires_at >= sysdate) then 
      fire_on_login_event(to_user_id(p_email=>lower(p_email)));
      verify_email(p_user_id=>v_saas_auth.user_id);
      apex_authentication.post_login (
         p_username=>lower(v_saas_auth.user_name), 
         -- Password does not matter here.
         p_password=>utl_raw.cast_to_raw(dbms_random.string('x',10)));
   end if;
exception 
   when others then
      arcsql.log_err('verify_email_using_token: '||dbms_utility.format_error_stack);
      raise;
end;


procedure set_timezone_name (
   -- Called when user logs in to set the current timezone name.
   -- 
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
   set_session_time_zone(get_user_id_from_user_name(p_user_name));
exception 
   when others then
      arcsql.log_err('set_timezone_name: '||dbms_utility.format_error_stack);
      raise;
end;


function does_email_already_exist (
   -- Return true if email exists.
   --
   p_email in varchar2) return boolean is
   n number;
begin
   arcsql.debug('does_email_already_exist: '||p_email);
   select count(*) into n 
     from v_saas_auth_available_accounts
    where email=lower(p_email);
   return n > 0;
end;


procedure raise_email_already_exists (
   p_email in varchar2) is 
   -- Raises error if the email address exists.
   n number;
begin 
   if does_email_already_exist(p_email) then
      arcsql.log_security_event(p_text=>'raise_email_already_exists: '||p_email, p_key=>'saas_auth');
      set_error_message('User is already registered.');
      raise_application_error(-20001, 'User is already registered.');
   end if;
end;


procedure raise_duplicate_user_name (
   p_user_name in varchar2) is 
   -- Raises error if user exists.
   n number;
begin 
   if does_user_name_exist(p_user_name) then
      arcsql.log_security_event(p_text=>'raise_duplicate_user_name: '||p_user_name, p_key=>'saas_auth');
      set_error_message('User name already exists. Try using a different one.');
      raise_application_error(-20001, 'User name already exists.');
   end if;
end;


procedure raise_invalid_password_prefix (
   p_password in varchar2) is 
   -- Raises error if password prefix is defined and the password does not use it.
   p varchar2(120);
begin 
   p := saas_auth_config.saas_auth_pass_prefix;
   if trim(p) is not null then 
      if substr(p_password, 1, length(p)) != p then 
         arcsql.log_security_event(p_text=>'raise_invalid_password_prefix:', p_key=>'saas_auth');
         set_error_message('This environment may not be available to the public (secret prefix defined).');
         raise_application_error(-20001, 'Secret prefix missing or did not match.');
      end if;
   end if;
end;


function get_email_from_user_name (
   p_user_name in varchar2) return varchar2 is 
   e saas_auth.email%type;
begin 
   select lower(email) into e 
     from v_saas_auth_available_accounts 
    where user_name = lower(p_user_name);
   return e;
end;


function get_user_id_from_user_name ( -- | Return the user id using the user name. 
   p_user_name in varchar2 default v('APP_USER')) return number is 
   n number;
   v_user_name saas_auth.user_name%type := lower(p_user_name);
begin 
   arcsql.debug3('get_user_id_from_user_name: user='||v_user_name);
   select user_id into n 
     from v_saas_auth_available_accounts 
    where user_name = v_user_name;
   return n;
exception 
   when others then
      arcsql.log_err('get_user_id_from_user_name: '||dbms_utility.format_error_stack);
      raise;
end;


function get_user_id_from_email ( -- | Return the user id using the user name. Uses v_saas_auth_available_accounts which does not return *ALL* accounts.
   p_email in varchar2) return number is 
   n number;
begin 
   arcsql.debug('get_user_id_from_email: email='||lower(p_email));
   raise_email_not_found(p_email);
   select user_id into n 
     from v_saas_auth_available_accounts 
    where email = lower(p_email);
   return n;
exception 
   when others then
      arcsql.log_err('get_user_id_from_email: '||dbms_utility.format_error_stack);
      raise;
end;


function to_user_id ( -- | Returns user id using email. Can see all accounts and might be a better option than get_user_id_from_email.
   p_email in varchar2) return number is
   r saas_auth%rowtype;
begin
   select * into r from saas_auth where email=lower(p_email);
   return r.user_id;
end;


function get_user_name (p_user_id in number) return varchar2 is 
   -- Return the user name by using the user id. 
   --
   n number;
   v_user_name saas_auth.user_name%type;
begin 
   select lower(user_name) into v_user_name 
     from v_saas_auth_available_accounts 
    where user_id=p_user_id;
   return v_user_name;
end;


procedure raise_does_not_appear_to_be_an_email_format (
   -- Raises an error if the string does not look like an email.
   --
   p_email in varchar2) is 
begin 
   if not arcsql.str_is_email(p_email) then 
      set_error_message('Email does not appear to be a valid email address.');
      raise_application_error(-20001, 'Email does not appear to be a valid email address.');
   end if;
end;


procedure add_test_user ( -- Add a user which is only accessible in dev mode.
   p_email in varchar2) is 
begin
   arcsql.debug('add_test_user: '||lower(p_email));
   if not does_user_name_exist(p_user_name=>lower(p_email)) then
      add_user (
         p_user_name=>lower(p_email),
         p_email=>lower(p_email),
         p_password=>saas_auth_config.saas_auth_test_pass,
         p_is_test_user=>true);
   end if;
end;

procedure fire_create_account (p_user_id in varchar2) is 
   n number;
begin 
   arcsql.debug('saas_auth_pkg.fire_create_account: '||p_user_id);
   select count(*) into n from user_source 
    where name = 'ON_CREATE_ACCOUNT'
      and type='PROCEDURE';
   if n > 0 then 
      arcsql.debug('fire_create_account: '||p_user_id);
      execute immediate 'begin on_create_account('||p_user_id||'); end;';
   end if;
end;

procedure fire_before_delete_user (
   p_user_id in varchar2) is 
   n number;
begin 
   arcsql.debug('saas_auth_pkg.fire_before_delete_user: '||p_user_id);
   select count(*) into n from user_source 
    where name = 'BEFORE_DELETE_USER'
      and type='PROCEDURE';
   if n > 0 then 
      execute immediate 'begin before_delete_user('||p_user_id||'); end;';
   end if;
end;

procedure fire_after_delete_user (
   p_user_id in varchar2) is 
   n number;
begin 
   arcsql.debug('saas_auth_pkg.fire_after_delete_user: '||p_user_id);
   select count(*) into n from user_source 
    where name = 'AFTER_DELETE_USER'
      and type='PROCEDURE';
   if n > 0 then 
      execute immediate 'begin after_delete_user('||p_user_id||'); end;';
   end if;
end;

procedure delete_user ( -- | Delete user account by id. Throw an error if the user_id is invalid.
   p_user_id in number) is 
begin 
   arcsql.debug('delete_user: '||p_user_id);
   assert_user_id_is_valid(p_user_id);
   fire_before_delete_user(p_user_id);
   delete from saas_auth 
    where user_id=p_user_id;
   fire_after_delete_user(p_user_id);
   arcsql.log_security_event(p_text=>'delete_user: '||p_user_id, p_key=>'saas_auth');
exception 
   when others then
      -- arcsql.log_err('delete_user: '||dbms_utility.format_error_stack);
      raise;
end;

procedure delete_user ( -- | Delete user by email if the account exists. Otherwise exit quietly.
   p_email in varchar2) is 
   n number;
begin 
   arcsql.debug('delete_user: '||p_email);
   select count(*) into n from saas_auth where email=lower(p_email);
   -- if not does_email_already_exist(p_email) then <- Don't use this, it use a view which will raise an error if email does not exist.
   if n > 0 then
      delete_user(p_user_id=>to_user_id(p_email));
   end if;
end;

procedure add_system_user (
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
         role_id) values (
         lower(p_user_name),
         lower(p_email), 
         sys_guid(),
         3);
   end if;
end;

procedure add_user (
   p_user_name in varchar2,
   p_email in varchar2,
   p_password in varchar2,
   p_is_test_user in boolean default false) is
   v_message varchar2(4000);
   v_password raw(64);
   v_user_id number;
   v_email varchar2(120) := lower(p_email);
   v_is_test_user varchar2(1) := 'n';
   v_uuid saas_auth.uuid%type;
   v_hashed_password saas_auth.password%type;
begin
   arcsql.debug('add_user: '||v_email);
   raise_does_not_appear_to_be_an_email_format(v_email);
   raise_duplicate_user_name(p_user_name=>v_email);
   if p_is_test_user then 
      v_is_test_user := 'y';
   end if;
   v_uuid := sys_guid();
   v_hashed_password := get_hashed_password(p_secret_string=>v_uuid||p_password);
   insert into saas_auth (
      user_name,
      email, 
      password,
      uuid,
      role_id,
      last_session_id,
      is_test_user) values (
      v_email,
      v_email, 
      v_hashed_password,
      v_uuid,
      1,
      v('APP_SESSION'),
      v_is_test_user);
   arcsql.log_security_event(p_text=>'add_user: '||v_email, p_key=>'saas_auth');
   set_password (
      p_user_name=>v_email,
      p_password=>p_password);
   v_user_id := get_user_id_from_user_name(p_user_name=>v_email);
   fire_create_account(v_user_id);
end;


function is_email_verification_required (
   -- Return true if the user must verify email before logging in.
   --
   p_email in varchar2) return boolean is 
   v_saas_auth saas_auth%rowtype;
begin 
   arcsql.debug('is_email_verification_required: '||p_email);
   raise_email_not_found(p_email);
   select * into v_saas_auth 
     from v_saas_auth_available_accounts 
    where email=lower(p_email);
   if v_saas_auth.email_verified is not null then 
      arcsql.debug('false1');
      return false;
   end if;
   if v_saas_auth.login_count >= saas_auth_config.allowed_logins_before_email_verification_is_required then 
      arcsql.debug('true');
      return true;
   else
      arcsql.debug('false2');
      return false;
   end if;
exception 
   when others then
      arcsql.log_err('is_email_verification_required: '||dbms_utility.format_error_stack);
      set_error_message('There was an error processing this request.');
      return true;
end;


procedure create_account ( -- | Creates a new user account.
   p_user_name in varchar2,
   p_email in varchar2,
   p_password in varchar2,
   p_confirm in varchar2,
   p_timezone_name in varchar2 default k2_config.default_timezone) is
   v_message varchar2(4000);
   v_email varchar2(120) := lower(p_email);
   v_user_id number;
begin
   arcsql.debug('create_account: '||lower(p_email));
   arcsql.count_request(p_request_key=>'saas_auth');
   raise_too_many_auth_requests;

   raise_duplicate_user_name(p_user_name=>v_email);
   raise_invalid_password_prefix(p_password);
   if p_password != p_confirm then 
      set_error_message('Passwords do not match.');
      raise_application_error(-20001, 'Passwords do not match.');
   end if;
   raise_password_failed_complexity_check(p_password);
   add_user (
      p_user_name=>v_email,
      p_email=>v_email,
      p_password=>p_password);
   set_timezone_name (
      p_user_name => v_email,
      p_timezone_name => p_timezone_name);
   -- This only works if it is enabled.
   send_email_verification_code_to(v_email);
   -- Can we auto login the user right away?
   if saas_auth_config.allowed_logins_before_email_verification_is_required > 0 then
      apex_authentication.post_login (
         p_username=>v_email, 
         p_password=>utl_raw.cast_to_raw(dbms_random.string('x',10)));
   end if;
   if saas_auth_config.send_email_on_create_account then 
      k2.log_email('saas_auth_pkg.create_account: '||v_email);
   end if;
exception 
   when others then
      arcsql.log_err('create_account: '||dbms_utility.format_error_backtrace);
      raise;
end;

function custom_auth (
   -- Custom authorization function registered as APEX authorization scheme.
   --
   p_username in varchar2,
   p_password in varchar2) return boolean is

   v_password                    saas_auth.password%type;
   v_stored_password             saas_auth.password%type;
   v_user_name                   saas_auth.user_name%type := lower(p_username);
   v_user_id                     saas_auth.user_id%type;
   v_uuid                        saas_auth.uuid%type;

begin
   arcsql.debug('custom_auth: user='||v_user_name);
   arcsql.count_request(p_request_key=>'saas_auth');
   raise_too_many_auth_requests;
   raise_user_name_not_found(v_user_name);

   v_user_id := get_user_id_from_user_name(p_user_name=>v_user_name);

   select password, uuid
     into v_stored_password, v_uuid
     from v_saas_auth_available_accounts
    where user_name=v_user_name;
   v_password := get_hashed_password(p_secret_string=>v_uuid||p_password);

   -- arcsql.debug('v_password='||v_password||', v_stored_password='||v_stored_password);
   if v_password=v_stored_password then
      arcsql.debug('custom_auth: true');
      fire_on_login_event(v_user_id);
      return true;
   end if;

   -- Things have failed if we get here.
   update saas_auth 
      set reset_pass_token=null, 
          reset_pass_expire=null,
          last_failed_login=sysdate,
          failed_login_count=failed_login_count+1,
          last_session_id=v('APP_SESSION')
    where user_name=v_user_name;
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


procedure send_reset_pass_token (
   -- Sends the user a security token which can be used on the password reset form.
   --
   p_email in varchar2) is 
   n number;
   v_token varchar2(120);
   v_app_name varchar2(120);
   m varchar2(1200);
begin 
   arcsql.debug('send_reset_pass_token: '||p_email);
   arcsql.count_request(p_request_key=>'saas_auth');
   raise_too_many_auth_requests;

   -- Fail quietly. Querying emails is potential malicious activity.
   if not does_email_already_exist(lower(p_email)) then 
      arcsql.log_err('send_reset_pass_token: Email address not found: '||lower(p_email));
      return;
   end if;

   while 1=1 loop 
      v_token := arcsql.str_random(6, 'an');
      select count(*) into n from v_saas_auth_available_accounts
       where reset_pass_token=v_token;
      if n=0 then 
         exit;
      end if;
   end loop;

   -- ToDo: Add a config parameter for the expiration time.
   update saas_auth 
      set reset_pass_token=v_token,
          reset_pass_expire=sysdate+nvl(saas_auth_config.password_reset_token_good_for_minutes, 15)/1440,
          last_session_id=v('APP_SESSION')
    where email=lower(p_email);

   v_app_name := k2_config.app_name;
   m := '
Hello,

You have requested to reset the password of your '||v_app_name||' account. 

Please use the security code to change your password.

'||v_token||'

Thanks,

- The '||v_app_name||' Team';
   send_email (
      p_to=>get_email_override_when_set(p_email),
      p_from=>arcsql_cfg.default_email_from_address,
      p_subject=>'Resetting your '||v_app_name||' account password!',
      p_body=>m);
exception 
   when others then
      arcsql.log_err('send_reset_pass_token: '||dbms_utility.format_error_stack);
      raise;
end;


procedure reset_password (
   p_token in varchar2,
   p_password in varchar2,
   p_confirm in varchar2) is 
   v_hashed_password varchar2(100);
   n number;
   v_user_name varchar2(120);
begin
   arcsql.debug('reset_password: ');
   arcsql.count_request(p_request_key=>'saas_auth');
   raise_too_many_auth_requests;

   select count(*) into n 
     from v_saas_auth_available_accounts 
    where reset_pass_token=p_token 
      and reset_pass_expire > sysdate;
   if n=0 then 
      set_error_message('Your token is either expired or invalid.');
      raise_application_error(-20001, 'Invalid password reset token.');
   end if;
   if p_password != p_confirm then 
      set_error_message('Passwords do not match.');
      raise_application_error(-20001, 'Passwords do not match.');
   end if;
   raise_password_failed_complexity_check(p_password);
   select lower(user_name) into v_user_name 
     from v_saas_auth_available_accounts 
    where reset_pass_token=p_token 
      and reset_pass_expire > sysdate;
   set_password (
      p_user_name=>v_user_name,
      p_password=>p_password);
   update saas_auth 
      set email_verified=sysdate,
          email_verification_token=null, 
          email_verification_token_expires_at=null 
    where email_verified is null 
      and user_name=v_user_name;
exception 
   when others then
      arcsql.log_err('reset_password: '||dbms_utility.format_error_stack);
      raise;
end;


function is_signed_in return boolean is 
begin 
   if lower(v('APP_USER')) not in ('guest', 'nobody') then 
      return true;
   else 
      return false;
   end if;
end;


function is_not_signed_in return boolean is 
begin 
   if lower(v('APP_USER')) in ('guest', 'nobody') then 
      return true;
   else 
      return false;
   end if;
end;


function is_admin (
   p_user_id in number) return boolean is
   x varchar2(1);
begin
   select 'Y'
    into x
    from v_saas_auth_available_accounts a
   where user_id=p_user_id
     and a.role_id=(select role_id from saas_auth_role where role_name='admin');
   return true;
exception
   when no_data_found then
      return false;
end;


procedure login_with_new_demo_account is 
   v_user varchar2(120);
   v_pass varchar2(120);
   n number;
begin 
   -- Generate a random demo user and password.
   v_user := 'Demo'||arcsql.str_random(5, 'a');
   v_pass := 'FooBar'||arcsql.str_random(5)||'@foo$';
   select count(*) into n 
     from v_saas_auth_available_accounts 
    where last_session_id=v('APP_SESSION') 
      and created >= sysdate-(.1/1440);
   if n = 0 then 
      saas_auth_pkg.create_account (
         p_user_name=>v_user,
         p_email=>v_user||'@null.com',
         p_password=>v_pass,
         p_confirm=>v_pass);
      apex_authentication.login(
         p_username => v_user,
         p_password => v_pass);
      post_auth;
   else 
      apex_error.add_error ( 
         p_message=>'Please wait 10 seconds before trying to create a new account.',
         p_display_location=>apex_error.c_inline_in_notification);
   end if;
end;


end;
/

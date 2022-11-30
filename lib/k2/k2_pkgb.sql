
create or replace package body k2 as 
    
procedure debug (
   p_text in varchar2, 
   p_key in varchar2) is 
begin 
   if k2_config.enable_arcsql_logging then
      arcsql.debug(p_text=>p_text, p_key=>p_key);
   end if;
   if k2_config.enable_apex_debug then
      apex_debug.message(p_message=>k2_config.apex_debug_prefix||p_text, p_level=>apex_debug.c_log_level_info);
   end if;
end;

procedure debug2 (
   p_text in varchar2, 
   p_key in varchar2) is
begin 
   if k2_config.enable_arcsql_logging then
      arcsql.debug2(p_text=>p_text, p_key=>p_key);
   end if;
   if k2_config.enable_apex_debug then
      apex_debug.message(p_message=>k2_config.apex_debug_prefix||p_text, p_level=>apex_debug.c_log_level_app_trace);
   end if;
end;

procedure debug3 (
   p_text in varchar2, 
   p_key in varchar2 default null) is
begin 
   if k2_config.enable_arcsql_logging then
      arcsql.debug3(p_text=>p_text, p_key=>p_key);
   end if;
   if k2_config.enable_apex_debug then
      apex_debug.message(p_message=>k2_config.apex_debug_prefix||p_text, p_level=>apex_debug.c_log_level_app_trace);
   end if;
end;

procedure log_err (
   p_text in varchar2, 
   p_key in varchar2 default null) is
begin 
   if k2_config.enable_arcsql_logging then
      log_err(p_text=>p_text, p_key=>p_key);
   end if;
   if k2_config.enable_apex_debug then
      apex_debug.message(p_message=>k2_config.apex_debug_prefix||p_text, p_level=>apex_debug.c_log_level_error);
   end if;
end;

procedure log (
   p_text in varchar2, 
   p_key in varchar2 default null) is
begin 
   if k2_config.enable_arcsql_logging then
      arcsql.log(p_text=>p_text, p_key=>p_key);
   end if;
   if k2_config.enable_apex_debug then
      apex_debug.message(p_message=>k2_config.apex_debug_prefix||p_text, p_level=>apex_debug.c_log_level_info);
   end if;
end;

procedure log_audit (
   p_text in varchar2, 
   p_key in varchar2 default null) is
begin 
   if k2_config.enable_arcsql_logging then
      arcsql.log_audit(p_text=>p_text, p_key=>p_key);
   end if;
   if k2_config.enable_apex_debug then
      apex_debug.message(p_message=>k2_config.apex_debug_prefix||p_text, p_level=>apex_debug.c_log_level_warn);
   end if;
end;

procedure log_email (
   p_text in varchar2, 
   p_key in varchar2 default null) is
begin 
   if k2_config.enable_arcsql_logging then
      arcsql.log_email(p_text=>p_text, p_key=>p_key);
   end if;
   -- Apex won't send an email this way. This only works for Arcsql if configured to send emails.
   if k2_config.enable_apex_debug then
      apex_debug.message(p_message=>k2_config.apex_debug_prefix||p_text, p_level=>apex_debug.c_log_level_warn);
   end if;
end;

procedure log_security_event (
   p_text in varchar2, 
   p_key in varchar2 default null) is
begin 
   if k2_config.enable_arcsql_logging then
      arcsql.log_security_event(p_text=>p_text, p_key=>p_key);
   end if;
   if k2_config.enable_apex_debug then
      apex_debug.message(p_message=>k2_config.apex_debug_prefix||p_text, p_level=>apex_debug.c_log_level_warn);
   end if;
end;


/*
-----------------------------------------------------------------------------------
MONKEY PATCHES
-----------------------------------------------------------------------------------
*/


function monkey_patch_remove_app_root_url (  -- | Fixes random return of full internal apex domain in apex_page.get_url.
   p_url in varchar2)                        -- | If url contains the k2_config.internal_app_domain replace it with k2_config.external_app_domain.
   return varchar2 is                        -- | Return value always starts with leading slash /.
   v_url varchar2(1200) := p_url;
   r varchar2(1200);
begin 
   arcsql.debug('monkey_patch_remove_app_root_url: '||p_url);
   if substr(v_url, 1, 2) = 'f?' then 
      r := k2_config.external_app_domain||'/'||k2_config.ords_url_prefix||'/'||v_url;
   end if;
   if substr(v_url, 1, 1) = '/' then 
      -- This should already include the ords_url_prefix.
      r := k2_config.external_app_domain||v_url; 
   end if;
   if instr(p_url, k2_config.internal_app_domain) > 0 then 
      r := replace(p_url, k2_config.internal_app_domain, k2_config.external_app_domain);
   end if;
   arcsql.debug('r='||r);
   return r;
   /*
   | get_url return value is unpredictable. It can return "f" style links, or pretty urls.
   | Can also return relative path or full path and uses internal k2.maxapex for domain
   | so if external domain name is needed get_url won't provide that. This function should
   | take all possible inputs and return the full path using the externally addressed domain.
   |
   | ToDo: Move to apex_utl2 or k2 packages. This should be shared code.
   */
end;


/* 
-----------------------------------------------------------------------------------
COOKIES
-----------------------------------------------------------------------------------
*/


procedure add_cookie (
   -- Queues a cookie by adding it to the cookie table.
   --
   p_name in varchar2,
   p_value in varchar2,
   p_expires in date default null,
   p_user_name in varchar2 default null,
   p_session_id in number default null) is 
   v_user_id number;
   v_user_name saas_auth.user_name%type := lower(p_user_name); 
   v_session_id number;
begin 
   arcsql.debug('add_cookie: name='||p_name);
   if p_user_name is not null then 
      select user_id into v_user_id from saas_auth where user_name=lower(p_user_name);
   end if;
   if p_user_name is null and p_session_id is null then 
      v_session_id := v('APP_SESSION');
   end if;
   insert into cookie (
      cookie_name,
      cookie_value,
      expires_at,
      user_id,
      user_name,
      session_id) values (
      lower(p_name),
      p_value, 
      p_expires, 
      v_user_id, 
      v_user_name, 
      v_session_id
      );
exception 
   when others then
      log_err('add_cookie: '||dbms_utility.format_error_stack);
      raise;
end;


procedure set_cookies is 
   -- Called from the global page. Sets any cookies that are queued.
   --
   cursor c_cookies is 
   select * from cookie 
    where user_name=lower(v('APP_USER')) 
       or session_id=v('APP_SESSION');
begin 
   arcsql.debug2('set_cookies: ');
   for c in c_cookies loop 
      owa_cookie.send (
         name    => c.cookie_name,
         value   => c.cookie_value,
         expires => c.expires_at,
         path    => '/',
         domain  => null,
         secure  => 'Y');
      delete from cookie where id=c.id;
   end loop;
exception 
   when others then
      log_err('set_cookies: '||dbms_utility.format_error_stack);
      raise;
end;


function get_cookie (
   p_cookie_name in varchar2) return varchar2 is 
   c owa_cookie.cookie;
begin 
   c := owa_cookie.get(p_cookie_name);
   arcsql.debug('get_cookie: '||p_cookie_name||'='||c.vals(1));
   return c.vals(1);
exception
   when no_data_found then 
      return null;
   when others then
      log_err('get_cookie: '||dbms_utility.format_error_stack);
      -- Do not raise error here. The 15 min admin job was getting 6502 err here and breaking.
      -- Not sure why admin job would be calling this. Might be from plsq in auto login auth scheme.
      -- raise;
end;



/* 
-----------------------------------------------------------------------------------
FLASH MESSAGES
-----------------------------------------------------------------------------------
*/


procedure add_flash_message (
   --
   --
   p_message in varchar2,
   p_message_type in varchar2 default 'notice',
   p_user_name in varchar2 default null,
   p_expires_at in date default null) is 
   v_user_id saas_auth.user_id%type;
begin 
   arcsql.debug('add_flash_message: '||p_message);
   insert into flash_message (
      message_type,
      message,
      user_name,
      session_id,
      expires_at) values (
      p_message_type, 
      p_message, 
      p_user_name,
      v('APP_SESSION'),
      p_expires_at);
exception 
   when others then
      log_err('add_flash_message: '||dbms_utility.format_error_stack);
      raise;
end;


function get_flash_message (
   --
   --
   p_message_type in varchar2 default 'notice',
   p_delete in boolean default true) return varchar2 is 
   cursor c_messages is 
   select * from flash_message 
    where message_type=p_message_type 
      and (user_name=lower(v('APP_USER'))
       or session_id=v('APP_SESSION'))
      and (expires_at is null  
       or expires_at > sysdate)
    order by id desc;
   r varchar2(1200);
begin 
   arcsql.debug('get_flash_message: '||p_message_type);
   for m in c_messages loop 
      r := r || m.message;
      if p_delete then 
         delete from flash_message where id=m.id;
      end if;
      exit;
   end loop;
   return r;
exception 
   when others then
      log_err('get_flash_message: '||dbms_utility.format_error_stack);
      raise;
end;


function get_flash_messages (
   --
   --
   p_message_type in varchar2 default 'notice',
   p_delete in boolean default true) return varchar2 is 
   cursor c_messages is 
   select * from flash_message 
    where message_type=p_message_type 
      and (user_name=lower(v('APP_USER'))
       or session_id=v('APP_SESSION'))
      and (expires_at is null  
       or expires_at > sysdate)
    order by id desc;
   r varchar2(1200);
   loop_count number := 0;
begin 
   arcsql.debug('get_flash_messages: '||p_message_type);
   for m in c_messages loop 
      loop_count := loop_count + 1;
      if loop_count = 1 then
         r := r || m.message;
      else 
         r := r || m.message ||' 
      ';
      end if;
      if p_delete then 
         delete from flash_message where id=m.id;
      end if;
   end loop;
   -- arcsql.debug('r='||r);
   return r;
exception 
   when others then
      log_err('get_flash_message: '||dbms_utility.format_error_stack);
      raise;
end;


function flash_message_count (
   --
   --
   p_message_type in varchar2 default 'notice') return number is
   n number;
begin 
   select count(*) into n 
     from flash_message 
    where message_type = p_message_type
      and (expires_at is null or expires_at > sysdate)
      and (user_name=lower(v('APP_USER'))
       or session_id=v('APP_SESSION'));
   arcsql.debug('flash_message_count: count='||n||', session='||v('APP_SESSION'));
   return n;
exception 
   when others then
      log_err('flash_message_count: '||dbms_utility.format_error_stack);
      raise;
end;



end;
/

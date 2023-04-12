
set define off

create or replace package body k2 as 

function app_alias return varchar2 is 
begin
   return k2_utl.get_app_alias;
end;

function app_id return number is 
begin 
   return k2_utl.get_app_id;
end;

/*

### fire_event_proc (function)

Calls a procedure with a no parameters if it exists.

* **p_proc_name** - The name of the procedure.

This is used to notify your app of of certain events within the framework. The notification passes a single numeric key which can be used to retrieve the relevant data.

*/

procedure fire_event_proc (
   -- Required
   p_proc_name in varchar2) is 
   n number;
begin 
   arcsql.debug('fire_event_proc: '||p_proc_name);
   select count(*) into n from user_source
    where name = upper(p_proc_name)
      and type='PROCEDURE';
   if n > 0 then 
      execute immediate 'begin '||p_proc_name||'; end;';
   end if;
end;

/*

### fire_event_proc (function)

Calls a procedure with a single parameter (number) if it exists.

* **p_proc_name** - The name of the procedure.
* **p_parm** - Numeric ID used to identify the event data.

This is used to notify your app of of certain events within the framework. The notification passes a single numeric key which can be used to retrieve the relevant data.

*/

procedure fire_event_proc (
   -- Required
   p_proc_name in varchar2,
   p_parm in number) is 
   n number;
begin 
   arcsql.debug('fire_event_proc: '||p_proc_name);
   select count(*) into n from user_source
    where name = upper(p_proc_name)
      and type='PROCEDURE';
   if n > 0 then 
      execute immediate 'begin '||p_proc_name||'('||p_parm||'); end;';
   end if;
end;

/*

### fire_event_proc (function)

Calls a procedure with a single parameter (string) if it exists.

* **p_proc_name** - The name of the procedure.
* **p_parm** - Numeric ID used to identify the event data.

*/

procedure fire_event_proc (
   -- Required
   p_proc_name in varchar2,
   p_parm in varchar2) is 
   n number;
begin 
   arcsql.debug('fire_event_proc: '||p_proc_name);
   select count(*) into n from user_source
    where name = upper(p_proc_name)
      and type='PROCEDURE';
   if n > 0 then 
      execute immediate 'begin '||p_proc_name||'('''||p_parm||'''); end;';
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
   v_url varchar2(2048) := p_url;
   r varchar2(2048);
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
   -- Removes // which could be in URL chain, but then puts the :// back which is after http or https
   return replace(replace(r, '//', '/'), ':/', '://') ;
   /*
   | get_url return value is unpredictable. It can return "f" style links, or pretty urls.
   | Can also return relative path or full path and uses internal k2.maxapex for domain
   | so if external domain name is needed get_url won't provide that. This function should
   | take all possible inputs and return the full path using the externally addressed domain.
   |
   */
end;

function remove_checksum_from_url ( -- | Removes the checksum from a url.
   p_url in varchar2)
   return varchar2 is 
   /*
   APEX 22.2 docs state that apex_page.get_url does not include a checksum but that does not 
   seem to be the case. This returns a url without the checksum. This assumes the checksum
   is the last parameter. Everything after the &cs= will be removes from the input url.
   */
   x number;
begin
   x := instr(p_url, '&cs=');
   if x > 0 then 
      return substr(p_url, 1, x-1);
   else
      return p_url;
   end if;
end;

/* 
-----------------------------------------------------------------------------------
COOKIES
-----------------------------------------------------------------------------------
*/

/*

### add_cookie (procedure)

Adds a cookie to the cookie table which will be deployed the next time process_cookies is called.

* **p_name** - Name of cookie. Should be unique across apps, consider adding app name or other id.
* **p_value** - Value of cookie
* **p_expires** - Date cookie expires
* **p_user_name** - User name of user to associate cookie with
* **p_session_id** - Session ID of user to associate cookie with
* **p_user_id** - User ID of user to associate cookie with
* **p_secure** - Y or N, defaults to Y. Not sure why we would want N here. Just here in case.

> Note
* The cookie will be deployed the next time process_cookies is called.
* The on_page_load event should directly or indirectly call process_cookies.
* The user can provide a user_id or user_name for the cookie, if neither is provided, the session id will be used.

*/

procedure add_cookie (
   p_name in varchar2,
   p_value in varchar2,
   p_expires in date default null,
   p_user_name in varchar2 default null,
   p_user_id in number default null,
   p_secure in varchar2 default 'Y') is 
   v_user_id number := p_user_id;
   v_user_name saas_auth.user_name%type := lower(p_user_name); 
   v_session_id number;
begin 
   arcsql.debug('add_cookie: name='||p_name);
   if p_user_id is null and p_user_name is not null then 
      v_user_id := saas_auth_pkg.to_user_id(p_user_name=>p_user_name);
   end if;
   if v_user_id is null then 
      v_session_id := v('APP_SESSION');
   end if;
   insert into cookie (
      cookie_name,
      cookie_value,
      expires_at,
      user_id,
      session_id,
      secure) values (
      lower(p_name),
      p_value, 
      p_expires, 
      v_user_id, 
      v_session_id,
      p_secure);
exception 
   when others then
      arcsql.log_err('add_cookie: '||dbms_utility.format_error_stack);
      raise;
end;


/*

### invalidate_cookie (procedure)

* Refer to add_cookie for parameter definitions
* The new cookie is expired and has a null value. It will invalidate any existing cookies. Web search suggest this is more reliable than remove cookie.

*/

procedure invalidate_cookie (
   p_name in varchar2,
   p_user_name in varchar2 default null,
   p_user_id in number default null) is 
begin 
   arcsql.debug('invalidate_cookie: name='||p_name);
   add_cookie(
      p_name=>p_name,
      p_value=>null,
      p_user_name=>p_user_name,
      p_user_id=>p_user_id,
      p_expires=>sysdate-1);
end;

/*

### process_cookies (procedure)

Retrieves cookie from the "cookie" table based on the current user's session or user ID, and then sends the retrieved cookies to the user's browser using the "owa_cookie.send" function. The cookies are deleted from the table after they are sent to the browser.

*/

procedure process_cookies is 
   cursor c_cookies is 
   select * from cookie 
    where session_id=v('APP_SESSION')
       or user_id=saas_auth_pkg.user_id;
begin 
   for c in c_cookies loop 
      owa_cookie.send (
         name    => c.cookie_name,
         value   => c.cookie_value,
         expires => c.expires_at,
         domain  => null,
         secure  => c.secure);
      delete from cookie where id=c.id;
   end loop;
end;

-- ToDo: Remove set_cookies
procedure set_cookies is 
   cursor c_cookies is 
   select * from cookie 
    where session_id=v('APP_SESSION');
begin 
   arcsql.log_deprecated('set_cookies');
exception 
   when others then
      arcsql.log_err('set_cookies: '||dbms_utility.format_error_stack);
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
      arcsql.log_err('get_cookie: '||dbms_utility.format_error_stack);
      -- Do not raise error here. The 15 min admin job was getting 6502 err here and breaking.
      -- Not sure why admin job would be calling this. Might be from plsql in auto login auth scheme.
      -- raise;
end;

/* 
-----------------------------------------------------------------------------------
FLASH MESSAGES
-----------------------------------------------------------------------------------
*/


procedure add_flash_message ( -- | Add a message to the flash_message table so it can be displayed to the user.
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
      arcsql.log_err('add_flash_message: '||dbms_utility.format_error_stack);
      raise;
end;

function get_flash_message (
   p_message_type in varchar2 default 'notice',
   p_delete in number default 1) return varchar2 is 
   pragma autonomous_transaction;
   cursor c_messages is 
   select * 
     from flash_message 
    where message_type=p_message_type 
      and (user_name=lower(v('APP_USER'))
       or session_id=v('APP_SESSION'))
      and (expires_at is null  
       or expires_at > sysdate)
    order by id desc;
   r varchar2(2048);
begin 
   arcsql.debug2('get_flash_message: '||p_message_type);
   for m in c_messages loop 
      r := r || m.message;
      if p_delete=1 then 
         delete from flash_message where id=m.id;
         commit;
      end if;
      exit;
   end loop;
   return r;
exception 
   when others then
      arcsql.log_err('get_flash_message: '||dbms_utility.format_error_stack);
      raise;
end;


function get_flash_messages ( -- | Return a string of messages from the flash_messages table.
   p_message_type in varchar2 default 'notice',
   p_delete in number default 1) return varchar2 is 
   pragma autonomous_transaction;
   cursor c_messages is 
   select * from flash_message 
    where message_type=p_message_type 
      and (user_name=lower(v('APP_USER'))
       or session_id=v('APP_SESSION'))
      and (expires_at is null or expires_at > sysdate)
    order by id desc;
   r varchar2(2048);
   loop_count number := 0;
begin 
   arcsql.debug2('get_flash_messages: '||p_message_type);
   for m in c_messages loop 
      loop_count := loop_count + 1;
      if loop_count = 1 then
         r := m.message;
      else 
         r := r || '  ----  ' || m.message;
      end if;
      if p_delete=1 then 
         delete from flash_message where id=m.id;
         commit;
      end if;
   end loop;
   -- arcsql.debug('r='||r);
   return r;
exception 
   when others then
      arcsql.log_err('get_flash_message: '||dbms_utility.format_error_stack);
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
   arcsql.debug2('flash_message_count: count='||n||', session='||v('APP_SESSION'));
   return n;
exception 
   when others then
      arcsql.log_err('flash_message_count: '||dbms_utility.format_error_stack);
      raise;
end;

end;
/

set define on
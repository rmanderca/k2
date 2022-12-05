
-- uninstall: exec drop_package('k2');
create or replace package k2 as 

/*
LOGGING

These calls simply forward a single call here to both arcsql.debug* procedures as 
well as apex_debug.* procedures. There is a k2_config variable available which 
you can use to set a prefix which will help identify the apex_debug calls, it 
is only added to the apex_debug calls.

*/
procedure debug   (p_text in varchar2, p_key in varchar2 default null);
procedure debug2  (p_text in varchar2, p_key in varchar2 default null);
procedure debug3  (p_text in varchar2, p_key in varchar2 default null);
procedure log_err (p_text in varchar2, p_key in varchar2 default null);
procedure log     (p_text in varchar2, p_key in varchar2 default null);
procedure log_audit           (p_text in varchar2, p_key in varchar2 default null);
procedure log_email           (p_text in varchar2, p_key in varchar2 default null);
procedure log_security_event  (p_text in varchar2, p_key in varchar2 default null);

/*
-----------------------------------------------------------------------------------
MONKEY PATCHES
-----------------------------------------------------------------------------------
*/

function monkey_patch_remove_app_root_url ( 
  p_url in varchar2)
  return varchar2;

/* 
-----------------------------------------------------------------------------------
COOKIES
-----------------------------------------------------------------------------------
*/

procedure add_cookie(
   p_name in varchar2,
   p_value in varchar2,
   p_expires in date default null,
   p_user_name in varchar2 default null,
   p_session_id in number default null);

procedure set_cookies;

function get_cookie (
   p_cookie_name in varchar2) return varchar2;

/* 
-----------------------------------------------------------------------------------
FLASH MESSAGES
-----------------------------------------------------------------------------------
*/

procedure add_flash_message (
   p_message in varchar2,
   p_message_type in varchar2 default 'notice',
   p_user_name in varchar2 default null,
   p_expires_at in date default null);

function get_flash_message (
   p_message_type in varchar2 default 'notice',
   p_delete in boolean default true) return varchar2;

function get_flash_messages (
   p_message_type in varchar2 default 'notice',
   p_delete in boolean default true) return varchar2;

function flash_message_count (
   p_message_type in varchar2 default 'notice') return number;

end;
/

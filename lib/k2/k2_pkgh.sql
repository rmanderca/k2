-- uninstall: exec drop_package('k2_config');
-- uninstall: exec drop_package('k2');
create or replace package k2 as 

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

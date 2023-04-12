
-- uninstall: exec drop_package('saas_auth_pkg');
-- uninstall: exec drop_package('saas_auth_config');
create or replace package saas_auth_pkg as

   procedure raise_error (
      p_message in varchar2);

   procedure assert_valid_email_format ( 
      p_email_address in varchar2);
   
   procedure add_account (
      p_email_address in varchar2,
      p_full_name in varchar2,
      p_password in varchar2,
      p_account_status in varchar2 default 'inactive');

   function get_saas_auth_row (
      p_user_id in number)
      return saas_auth%rowtype;

   function get_saas_auth_row ( 
      p_user_name in varchar2)
      return saas_auth%rowtype;

   procedure auto_login;

   function get_current_time_for_user (
      p_user_id in number) return timestamp;

   procedure delete_user (
      p_user_id in number);

   procedure add_system_user (
      p_user_name in varchar2,
      p_email_address in varchar2);

   function does_user_name_exist ( 
      p_user_name in varchar2) return boolean;

   procedure assert_password_passes_complexity_check (
      p_password in varchar2);

   -- Add this to your authentication scheme. Calls all packaged procedures with name 'post_auth'.
   procedure post_auth;

   procedure set_timezone_name (
      p_user_name in varchar2,
      p_timezone_name in varchar2);

   procedure login ( 
      p_user_name in varchar2);

   procedure login ( 
      p_user_id in number);

   function custom_auth (
      p_username in varchar2,
      p_password in varchar2) return boolean;

   procedure set_password (
      p_user_id in number,
      p_password in varchar2);
   
   function is_admin (
      p_user_id in number) return boolean;

   function to_user_id (
      p_user_name in varchar2) return number;

   procedure post_logout;

   function user_id 
      return number;

end;
/





-- uninstall: exec drop_package('saas_auth_pkg');
-- uninstall: exec drop_package('saas_auth_config');
create or replace package saas_auth_pkg as

   procedure process_auth_token (
      p_auth_token in varchar2,
      p_redirect in varchar2 default 'home');

   procedure process_login ( 
      p_user_name in varchar2,
      p_password in varchar2,
      p_timezone_name in varchar2 default saas_auth_config.default_timezone,
      p_auto_login in varchar2 default 'N');

   procedure process_forgot_pass (
      p_user_name in varchar2);

   procedure process_change_pass (
      p_user_id in number,
      p_password in varchar2);

   procedure process_create_account (
      p_email in varchar2,
      p_full_name in varchar2,
      p_password in varchar2);

   procedure send_verify_email_request ( 
      p_user_id in number);

   procedure send_forgot_pass_email (
      p_user_id in number);

   function get_saas_auth_row (
      p_user_id in number)
      return saas_auth%rowtype;

   procedure generate_new_auth_token (
      p_user_id in number,
      p_expire_minutes in number);

   procedure set_auto_login (
      p_auto_login varchar2 default 'N');

   procedure auto_login;

   function get_email_override_when_set (
      p_email varchar2) return varchar2;

   function get_current_time_for_user (
      p_user_id in number) return timestamp;

   procedure delete_user (
      p_user_id in number);

   procedure add_system_user (
      p_user_name in varchar2,
      p_email in varchar2);

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

   function to_user_id ( 
      p_auth_token in varchar2) return number;

   procedure post_logout;

   procedure logout;

end;
/




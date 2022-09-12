
-- uninstall: drop package saas_auth_pkg;
create or replace package saas_auth_pkg as

   procedure automation_daily;

   procedure purge_deleted_accounts ( 
      p_days in number default 7);

   procedure check_auth_token_auto_login (
      p_auth_token in saas_auth_token.auth_token%type);

   procedure use_auth_token (
      p_auth_token in varchar2);

   function get_user_id_from_auth_token (
      p_auth_token in varchar2) return number;

   function is_valid_auth_token (
      p_auth_token in saas_auth_token.auth_token%type) return boolean;

   function get_new_auth_token (
      p_user_name in varchar2 default null,
      p_user_id in number default null,
      p_expires_at in date default null,
      p_auto_login in boolean default false,
      p_max_use_count in number default 1
      ) return varchar2;

   procedure set_auto_login (
      p_auto_login varchar2 default 'N');

   procedure auto_login;

   function get_email_override_when_set (
      p_email varchar2) return varchar2;

   function get_current_time_for_user (
      p_user_id in number) return timestamp;

   procedure delete_user (
      p_email in varchar2 default null,
      p_user_id in number default null);

   procedure set_remove_date (
      -- Sets a date to delete the user from the app. An automation will take care of this once per day.
      p_user_id in number,
      p_date in date);

   procedure ui_delete_account (
      p_auth_token in varchar2);

   function is_email_verification_required (
      p_email in varchar2) return boolean;

   procedure send_email_verification_code_to (
      p_user_name in varchar2);

   procedure verify_email (
      p_user_id in number default null,
      p_user_name in varchar2 default null);

   procedure verify_email_using_token (
      p_email in varchar2,
      p_auth_token in varchar2);
  
   -- Add this to your authentication scheme. Calls all packaged procedures with name 'post_auth'.
   procedure post_auth;

   procedure set_timezone_name (
      p_user_name in varchar2,
      p_timezone_name in varchar2);

   procedure add_user (
      p_user_name in varchar2,
      p_email in varchar2,
      p_password in varchar2,
      p_is_test_user in boolean default false);
      
   procedure add_test_user (
      p_email in varchar2);

   procedure create_account (
      p_user_name in varchar2,
      p_email in varchar2,
      p_password in varchar2,
      p_confirm in varchar2,
      p_timezone_name in varchar2 default k2_config.default_timezone);

   function custom_auth (
      p_username in varchar2,
      p_password in varchar2) return boolean;

   procedure send_reset_pass_token (
      p_email in varchar2);

   procedure reset_password (
      p_token in varchar2,
      p_password in varchar2,
      p_confirm in varchar2);

   procedure set_password (
      p_user_name in varchar2,
      p_password in varchar2);
      
   function does_email_already_exist (
      p_email in varchar2) return boolean;

   -- This is set up in APEX as a custom authorization.
   function is_signed_in return boolean;
   
   -- This is set up in APEX as a custom authorization.
   function is_not_signed_in return boolean;

   function is_admin (
      p_user_id in number) return boolean;

   procedure login_with_new_demo_account;

   function get_user_id_from_user_name (
      p_user_name in varchar2 default v('APP_USER')) return number;

   function get_user_id_from_email (
      p_email in varchar2) return number;

   function get_user_name (p_user_id in number) return varchar2;

   function ui_branch_to_main_after_auth (
      p_email in varchar2) return boolean;

   procedure post_logout;

end;
/




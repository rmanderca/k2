

-- uninstall: exec drop_package('saas_auth_ui');

create or replace package saas_auth_ui as

   procedure set_auto_login (
      p_checkbox_value in varchar2 default 'N');

   procedure logout;

   -- Deprecated
   procedure process_create_account (
      p_email_address in varchar2,
      p_full_name in varchar2,
      p_password in varchar2,
      p_requested_pricing_plan in varchar2 default null);

   function create_account (
      p_email_address in varchar2,
      p_full_name in varchar2,
      p_password in varchar2,
      p_requested_pricing_plan in varchar2 default null)
      return number;

   procedure set_account_status (
      p_user_name in varchar2,
      p_account_status in varchar2);

   function get_account_status (
      p_user_name in varchar2)
      return varchar2;

   procedure assert_user_name_exists (
      p_user_name in varchar2);

   procedure assert_user_name_does_not_exist (
      p_user_name in varchar2);
   
end;
/

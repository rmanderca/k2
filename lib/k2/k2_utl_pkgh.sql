-- uninstall: exec drop_package('k2_utl');
create or replace package k2_utl as
   
    /* 
    -----------------------------------------------------------------------------------
    Setting and getting sys_context values.
    -----------------------------------------------------------------------------------
    */

    -- I used this to have access to client identifier in FarmPulse but not sure why now :)
    -- This might explain it: https://jeffkemponoracle.com/2013/02/apex-and-application-contexts
    
   procedure set_sys_context (
      p_namespace in varchar2,
      p_attribute in varchar2,
      p_value in varchar2,
      p_client_id in varchar2 default null);

   function get_sys_context (
      p_namespace in varchar2,
      p_attribute in varchar2) return varchar2;

   procedure enable_automations (p_app_id in number);
   function get_current_theme_id_for_app return number;
   function get_app_id return number;
   function get_app_alias return varchar2;
   procedure change_theme_for_user (p_theme_name in varchar2);
   function get_ip return varchar2;
   function get_query_string return varchar2;
   procedure log_cgi_env_to_debug;
      
end;
/

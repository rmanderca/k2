create or replace package apex_utl2 as

    function get_current_theme_id_for_app return number;
    function get_app_id return number;
    function get_app_alias return varchar2;
    procedure change_theme_for_user (p_theme_name in varchar2);
    function get_ip return varchar2;
    function get_query_string return varchar2;
    procedure log_cgi_env_to_debug;
end;
/

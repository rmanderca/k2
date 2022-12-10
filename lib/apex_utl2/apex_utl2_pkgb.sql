
create or replace package body apex_utl2 as


/* 
-----------------------------------------------------------------------------------
Setting and getting sys_context values.
-----------------------------------------------------------------------------------
*/

procedure set_sys_context (
   p_namespace in varchar2,
   p_attribute in varchar2,
   p_value in varchar2,
   p_client_id in varchar2 default null) is 
   v_client_id varchar2(200);
begin 
   if p_client_id is null then 
      v_client_id := sys_context('userenv','client_identifier');
   else 
      v_client_id := p_client_id;
   end if;
   dbms_session.set_context(
      namespace => p_namespace,
      attribute => p_attribute,
      value     => p_value,
      client_id => v_client_id);
exception 
   when others then 
      raise;
end;

function get_sys_context (
   p_namespace in varchar2,
   p_attribute in varchar2) return varchar2 is 
begin 
   return sys_context(p_namespace, p_attribute);
end;


procedure enable_automations ( -- | Enable all automations for the given application id.
   p_app_id in number) is 
   cursor c_automations is
   select application_id, static_id
     from apex_appl_automations
    where polling_status_code in ('DISABLED')
      and application_id = p_app_id;
begin
   wwv_flow_api.set_security_group_id;
   for c in c_automations loop 
      apex_automation.enable(
        p_application_id=>c.application_id, 
        p_static_id=>c.static_id);
      arcsql.notify('enable_automations.sql: Enabled automation '||c.static_id||' ('||c.application_id||').');
   end loop;
end;


function get_app_id return number is -- | Return app id if available within APEX session context else return configured value.
begin 
    return nvl(apex_application.g_flow_id, k2_config.app_id);
end;


function get_app_alias return varchar2 is -- | Return the app alias using g_flow_alias.
begin 
    return trim(apex_application.g_flow_alias);
end;


function get_current_theme_id_for_app return number is -- | Return current theme by using g_flow_theme_id.
begin 
    return to_number(trim(apex_application.g_flow_theme_id));
end;


function get_style_id_for_theme_name ( -- | Return numeric style id for the specified theme name.
    p_theme_name in varchar2) 
    return number is 
    n number;
begin 
    select theme_style_id into n 
      from apex_application_theme_styles 
     where application_name=apex_application.g_flow_name
       and name=p_theme_name;
    return n;
end;


procedure change_theme_for_user ( -- | Change the theme for the current v('APP_USER').
    p_theme_name in varchar2) is 
begin
    arcsql.debug('change_theme_for_user: user='||v('APP_USER')||', theme='||p_theme_name||', app_id='||get_app_id);
    apex_theme.set_session_style (
        p_theme_number => get_current_theme_id_for_app,
        p_name => p_theme_name
        );
    apex_theme.set_user_style (
        p_application_id => get_app_id,
        p_user           => v('APP_USER'),
        p_theme_number   => get_current_theme_id_for_app,
        p_id             => get_style_id_for_theme_name(p_theme_name)
        );
exception 
    when others then
        arcsql.log_err('change_theme_for_user: '||dbms_utility.format_error_stack);
        raise;
end;


function get_ip return varchar2 is  -- | Return the IP of the calling session.
begin 
    return owa_util.get_cgi_env('REMOTE_ADDR');
end;


function get_query_string return varchar2 is  -- | Return the query string of the calling session.
begin 
    -- https://www.oracle-and-apex.com/authenticate-apex-via-token/
    return owa_util.get_cgi_env('QUERY_STRING');
end;

procedure log_cgi_env_to_debug is 
begin 
    -- https://stackoverflow.com/questions/70313694/how-to-get-host-name-and-request-headers-for-ords-restful-services
    for i in 1..nvl(owa.num_cgi_vars, 0) loop
        arcsql.debug('log_cgi_env_to_debug: '||owa.cgi_var_name(i) || ' = ' || owa.cgi_var_val(i));
    end loop;
end;

end;
/

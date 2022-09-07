

/*

This file should be run after an app is refreshed in the workspace.

*/


declare 
   cursor c_automations is
   select application_id, static_id
     from apex_appl_automations
    where polling_status_code in ('DISABLED')
      and application_id in (-1);
begin
   wwv_flow_api.set_security_group_id;
   for c in c_automations loop 
      apex_automation.enable(
        p_application_id=>c.application_id, 
        p_static_id=>c.static_id);
      arcsql.notify('post_app_refresh.sql: Enabled automation '||c.static_id||' ('||c.application_id||').');
   end loop;
end;
/

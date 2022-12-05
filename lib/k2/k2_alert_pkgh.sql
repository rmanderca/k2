
-- uninstall: exec drop_package('k2_alert');

create or replace package k2_alert as 

function to_priority_group_id (
   p_priority_group_key in varchar2)
   return number;

procedure close_alert (
   p_priority_group_id in number,
   p_alert_text in varchar2);

procedure close_alert (
   p_alert_key in varchar2);

procedure open_alert (
   p_priority_group_id in number,
   p_alert_text in varchar2,
   p_priority_level in number default 3,
   p_alert_key in varchar2 default null);

procedure create_priority_group (
   p_priority_group_key in varchar2,
   p_priority_group_name in varchar2 default null,
   p_user_id in number default null);

function does_priority_group_exist (
   p_priority_group_key in varchar2)
   return boolean;

procedure delete_priority_group (
   p_priority_group_key in varchar2);

procedure add_default_rows_to_new_priority_group (
   p_priority_group_id in number);

procedure check_alerts;

-- Objects below here are exposed for writing tests only.

function get_priority_group_id (
   p_priority_group_key in varchar2) return number;

end;
/

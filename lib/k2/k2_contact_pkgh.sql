
-- uninstall: exec drop_package('k2_contact');
create or replace package k2_contact as 

function does_contact_exist (
   p_contact_key in varchar2)
   return boolean;
   
function is_contact_available (
   p_contact_id in number)
   return number;

function is_contact_group_available (
   p_contact_group_id in number)
   return number;

procedure create_contact_group ( 
   p_contact_group_key in varchar2,
   p_contact_group_name in varchar2 default null,
   p_user_id in number default null,
   p_contact_group_alt_id in number default null);

procedure create_contact (
   p_contact_key in varchar2,
   p_contact_name in varchar2,
   p_email_address in varchar2,
   p_text_address in varchar2 default null,
   p_user_id in number default null,
   p_contact_alt_id in number default null,
   p_attribute_1 in varchar2 default null,
   p_attribute_2 in varchar2 default null,
   p_attribute_3 in varchar2 default null,
   p_attribute_4 in varchar2 default null,
   p_attribute_5 in varchar2 default null);

procedure add_contact_to_contact_group (
   p_contact_id in number,
   p_contact_group_id in number);

procedure assert_contact_is_member_of_group (
   p_contact_key in varchar2,
   p_contact_group_key in varchar2);

procedure remove_contact_from_contact_group (
   p_contact_id in number,
   p_contact_group_id in number);

procedure delete_contact (
   p_contact_key in varchar2);

procedure delete_group (
   p_contact_group_key in varchar2);

procedure add_alert_priority_group_to_contact_group (
   p_alert_priority_group_key in varchar2,
   p_contact_group_key in varchar2);

function to_contact_id (
   p_contact_key in varchar2)
   return number;

function to_contact_group_id (
   p_contact_group_key in varchar2)
   return number;

procedure send_email (
   p_contact_id in number);

function get_contact_row (
   p_contact_id in number)
   return contacts%rowtype;

function get_contact_row (
   p_contact_key in varchar2)
   return contacts%rowtype;

function get_contact_group_row (
   p_contact_group_key in varchar2)
   return contact_groups%rowtype;

function get_contact_group_row (
   p_contact_group_id number)
   return contact_groups%rowtype;

end;
/

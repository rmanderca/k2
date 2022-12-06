
-- uninstall: exec drop_package('k2_contact');
create or replace package k2_contact as 

procedure create_group ( 
   p_contact_group_key in varchar2,
   p_contact_group_name in varchar2 default null,
   p_user_id in number default null);

procedure create_contact (
   p_contact_key in varchar2,
   p_contact_name in varchar2,
   p_email in varchar2,
   p_sms in varchar2,
   p_user_id in number);

procedure add_contact_to_group (
   p_contact_key in varchar2,
   p_contact_group_key in varchar2);

procedure remove_contact_from_group (
   p_contact_key in varchar2,
   p_contact_group_key in varchar2);

procedure delete_contact (
   p_contact_key in varchar2);

procedure delete_group (
   p_contact_group_key in varchar2);

procedure add_priority_group_to_contact_group (
   p_priority_group_key in varchar2,
   p_contact_group_key in varchar2);

function to_contact_id (
   p_contact_key in varchar2)
   return number;

function to_contact_group_id (
   p_contact_group_key in varchar2)
   return number;

procedure send_email (
   p_contact_id in number);

end;
/

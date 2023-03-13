create or replace package body k2_contact as 

function is_contact_available (
   p_contact_id in number)
   return number is 
   v_contact contacts%rowtype;
begin 
   v_contact := get_contact_row(p_contact_id);
   if not arcsql.is_truthy_y(v_contact.is_contact_active) = 'y' then
      return 0;
   end if;
   if arcsql.is_truthy_y(v_contact.is_contact_out_of_office) = 'y' then 
      return 0;
   end if;
   return 1;
end;

function is_contact_group_available (
   p_contact_group_id in number)
   return number is 
   v_contact_group contact_groups%rowtype;
begin 
   v_contact_group := get_contact_group_row(p_contact_group_id);
   if not arcsql.is_truthy_y(v_contact_group.is_contact_group_active) = 'y' then
      return 0;
   end if;
   if arcsql.is_truthy_y(v_contact_group.is_contact_group_out_of_office) = 'y' then 
      return 0;
   end if;
   return 1;
end;

function to_contact_id ( -- | Convert contact key to contact id.
   p_contact_key in varchar2)
   return number is
   n number;
begin 

   select contact_id into n from contacts where contact_key = p_contact_key;
   return n;
end;

function to_contact_group_id (
   p_contact_group_key in varchar2)
   return number is
   n number;
begin
   select contact_group_id into n from contact_groups where contact_group_key = p_contact_group_key;
   return n;
end;

function does_contact_group_id_exist (
   p_contact_group_id in number)
   return boolean is
   n number;
begin 
   select count(*) into n from contact_groups where contact_group_id = p_contact_group_id;
   return n = 1;
end;

function does_contact_group_exist ( -- | Return true if contact group exists.
   p_contact_group_key in varchar2) 
   return boolean is  
   n number;
begin 
   select count(*) into n from contact_groups where contact_group_key=p_contact_group_key;
   return n = 1;
end;

function does_contact_exist ( -- Return true if contact exists.
   p_contact_key in varchar2)
   return boolean is
   n number;
begin 
   select count(*) into n from contacts where contact_key = p_contact_key;
   return n = 1;
end;

function is_contact_member_of_contact_group ( -- Return true if contact group contact exists.
   p_contact_id in number,
   p_contact_group_id in number)
   return boolean is
   n number;
begin 
   select count(*) into n from contact_group_members where contact_group_id = p_contact_group_id and contact_id = p_contact_id;
   return n = 1;
end;

function is_contact_group_subscribed_to_priority_group (
   p_alert_priority_group_id in number,
   p_contact_group_id in number)
   return boolean is
   n number;
begin
   select count(*) into n from contact_group_priority_groups where alert_priority_group_id = p_alert_priority_group_id and contact_group_id = p_contact_group_id;
   return n = 1;
end;

procedure create_contact_group ( -- | Create a contact group if it does not exist.
   p_contact_group_key in varchar2,
   p_contact_group_name in varchar2 default null,
   p_user_id in number,
   p_contact_group_alt_id in number default null) is
begin
   arcsql.debug('create_contact_group: ' || p_contact_group_key);
   if not does_contact_group_exist(p_contact_group_key) then
      insert into contact_groups (
         contact_group_key, 
         contact_group_name, 
         user_id,
         contact_group_alt_id) values (
         p_contact_group_key, 
         p_contact_group_name, 
         p_user_id,
         p_contact_group_alt_id);
   end if;
end;

procedure create_contact ( -- | Create a new contact if it does not exist.
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
   p_attribute_5 in varchar2 default null) is
begin
   arcsql.debug('create_contact', 'p_contact_key: ' || p_contact_key);
   if not does_contact_exist(p_contact_key) then
      insert into contacts (
         contact_key, 
         contact_name, 
         email_address, 
         text_address, 
         user_id,
         contact_alt_id,
         attribute_1,
         attribute_2,
         attribute_3,
         attribute_4,
         attribute_5) values (
         p_contact_key, 
         p_contact_name, 
         p_email_address, 
         p_text_address, 
         p_user_id,
         p_contact_alt_id,
         p_attribute_1,
         p_attribute_2,
         p_attribute_3,
         p_attribute_4,
         p_attribute_5);
   end if;
end;

procedure add_contact_to_contact_group (
   p_contact_id in number,
   p_contact_group_id in number) is 
begin
   arcsql.debug('add_contact_to_contact_group: '||p_contact_id||', '||p_contact_group_id);
   if not is_contact_member_of_contact_group(p_contact_id, p_contact_group_id) then
      insert into contact_group_members (contact_id, contact_group_id) values (p_contact_id, p_contact_group_id);
   end if;
end;

procedure assert_contact_is_member_of_group (
   p_contact_key in varchar2,
   p_contact_group_key in varchar2) is
   n number;
begin 
   select count(*) into n from contact_group_members 
    where contact_id = to_contact_id(p_contact_key) 
      and contact_group_id = to_contact_group_id(p_contact_group_key);
   if n = 0 then
      raise_application_error(-20000, 'assert_contact_is_member_of_group: Contact is not a member of the group.');
   end if;
exception 
   when others then 
      arcsql.log_err('assert_contact_is_member_of_group: '||sqlerrm);
      raise;
end;

procedure remove_contact_from_contact_group ( -- | Removes a contact from a contact group.
   p_contact_id in number,
   p_contact_group_id in number) is
begin 
   arcsql.debug('remove_contact_from_contact_group: '||p_contact_id||', '||p_contact_group_id);
   delete from contact_group_members where contact_id = p_contact_id and contact_group_id = p_contact_group_id;
end;

procedure delete_contact_id (
   p_contact_id in number) is
begin 
   delete from contacts where contact_id = p_contact_id;
end;

procedure delete_contact ( -- | Deletes a contact.
   p_contact_key in varchar2) is
begin
   delete_contact_id(to_contact_id(p_contact_key));
end;

procedure delete_group_id (
   p_contact_group_id in number) is
begin 
   delete from contact_groups where contact_group_id = p_contact_group_id;
end;

procedure delete_group (
   p_contact_group_key in varchar2) is
begin
   delete_group_id(to_contact_group_id(p_contact_group_key));
end;

function is_priority_group_id_in_contact_group_id (
   p_alert_priority_group_id in number,
   p_contact_group_id in number)
   return boolean is
   n number;
begin 
   select count(*) into n from contact_group_priority_groups 
    where alert_priority_group_id = p_alert_priority_group_id and contact_group_id = p_contact_group_id;
   return n = 1;
end;

procedure add_priority_group_id_to_contact_group_id (
   p_alert_priority_group_id in number,
   p_contact_group_id in number) is
begin
   if not is_priority_group_id_in_contact_group_id(p_alert_priority_group_id, p_contact_group_id) then
      insert into contact_group_priority_groups (alert_priority_group_id, contact_group_id) values (
         p_alert_priority_group_id, p_contact_group_id);
   end if;
end;

procedure add_alert_priority_group_to_contact_group (
   p_alert_priority_group_key in varchar2,
   p_contact_group_key in varchar2) is
begin
   arcsql.debug('add_alert_priority_group_to_contact_group: '||p_alert_priority_group_key||' '||p_contact_group_key);
   add_priority_group_id_to_contact_group_id(k2_alert.to_priority_group_id(p_alert_priority_group_key), to_contact_group_id(p_contact_group_key));
end;

function get_contact_group_row (
   p_contact_group_id in number)
   return contact_groups%rowtype is 
   r contact_groups%rowtype;
begin 
   select * into r from contact_groups where contact_group_id=p_contact_group_id;
   return r;
end;

function get_contact_row (
   p_contact_id in number)
   return contacts%rowtype is
   r contacts%rowtype;
begin
   select * into r from contacts where contact_id=p_contact_id;
   return r;
end;

function get_contact_row (
   p_contact_key in varchar2)
   return contacts%rowtype is
   r contacts%rowtype;
begin
   select * into r from contacts where contact_key=p_contact_key;
   return r;
end;

function get_contact_group_row (
   p_contact_group_key in varchar2)
   return contact_groups%rowtype is
   r contact_groups%rowtype;
begin
   select * into r from contact_groups where contact_group_key=p_contact_group_key;
   return r;
end;

procedure send_email (
   p_contact_id in number) is 
begin 
   null;
end;

end;
/

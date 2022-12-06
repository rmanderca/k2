
create or replace package body k2_contact as 

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

function is_contact_in_group ( -- Return true if contact group contact exists.
   p_contact_id in number,
   p_contact_group_id in number)
   return boolean is
   n number;
begin 
   select count(*) into n from contact_group_members where contact_group_id = p_contact_group_id and contact_id = p_contact_id;
   return n = 1;
end;

function is_contact_group_subscribed_to_priority_group (
   p_priority_group_id in number,
   p_contact_group_id in number)
   return boolean is
   n number;
begin
   select count(*) into n from contact_group_priority_groups where priority_group_id = p_priority_group_id and contact_group_id = p_contact_group_id;
   return n = 1;
end;

procedure create_group ( -- | Create a contact group if it does not exist.
   p_contact_group_key in varchar2,
   p_contact_group_name in varchar2 default null,
   p_user_id in number) is
begin
   if not does_contact_group_exist(p_contact_group_key) then
      insert into contact_groups (contact_group_key, contact_group_name, user_id) values (
         p_contact_group_key, p_contact_group_name, p_user_id);
   end if;
end;

procedure create_contact ( -- | Create a new contact if it does not exist.
   p_contact_key in varchar2,
   p_contact_name in varchar2,
   p_email in varchar2,
   p_sms in varchar2,
   p_user_id in number) is
begin
   if not does_contact_exist(p_contact_key) then
      insert into contacts (
         contact_key, contact_name, email_address, sms_address, user_id) values (
         p_contact_key, p_contact_name, p_email, p_sms, p_user_id);
   end if;
end;

procedure add_contact_id_to_group_id ( -- | Adds a contact to a contract group if the relationship does not already exist.
   p_contact_id in number,
   p_contact_group_id in number) is
begin
   if not is_contact_in_group(p_contact_id, p_contact_group_id) then
      insert into contact_group_members (contact_id, contact_group_id) values (p_contact_id, p_contact_group_id);
   end if;
end;

procedure add_member_to_group (
   p_contact_key in varchar2,
   p_contact_group_key in varchar2)
   is 
begin 
   add_contact_id_to_group_id(to_contact_id(p_contact_key), to_contact_group_id(p_contact_group_key));
end;

procedure remove_contact_id_from_group_id (
   p_contact_id in number,
   p_contact_group_id in number) is
begin 
   delete from contact_group_members where contact_id = p_contact_id and contact_group_id = p_contact_group_id;
end;

procedure remove_contact_from_group ( -- | Removes a contact from a contact group.
   p_contact_key in varchar2,
   p_contact_group_key in varchar2) is
begin
   remove_contact_id_from_group_id(to_contact_id(p_contact_key), to_contact_group_id(p_contact_group_key));
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
   p_priority_group_id in number,
   p_contact_group_id in number)
   return boolean is
   n number;
begin 
   select count(*) into n from contact_group_priority_groups 
    where priority_group_id = p_priority_group_id and contact_group_id = p_contact_group_id;
   return n = 1;
end;

procedure add_priority_group_id_to_contact_group_id (
   p_priority_group_id in number,
   p_contact_group_id in number) is
begin
   if not is_priority_group_id_in_contact_group_id(p_priority_group_id, p_contact_group_id) then
      insert into contact_group_priority_groups (priority_group_id, contact_group_id) values (
         p_priority_group_id, p_contact_group_id);
   end if;
end;

procedure add_priority_group_to_contact_group (
   p_priority_group_key in varchar2,
   p_contact_group_key in varchar2) is
begin
   add_priority_group_id_to_contact_group_id(k2_alert.to_priority_group_id(p_priority_group_key), to_contact_group_id(p_contact_group_key));
end;

function get_contract_group_row (
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

procedure process_contact (
   p_contact_id in number,
   p_contact_group_id in number) is 
   n number;
   message_body varchar2(32000);
   r contacts%rowtype;
   g contact_groups%rowtype;
   cursor contact_report is 
   select * from contact_report_view
    where contact_id=p_contact_id 
      and contact_group_id=p_contact_group_id;
begin 
   r := get_contact_row(p_contact_id);
   if trim(r.email_address) is null then
      return;
   end if;

   -- Are there any records this contact needs to be notified about using email?
   select count(*) into n 
     from alert_contacts_view
    where contact_id=p_contact_id
      and contact_group_id=p_contact_group_id
      and try_email = 'y';
   if n = 0 then 
      return;
   end if;

   for alert in contact_report loop 
      update alerts set sent_email_count = sent_email_count+1 where alert_id=alert.alert_id;
      message_body := message_body + alert.full_text ||'
';
   end loop;
   
   g := get_contract_group_row(p_contact_group_id);

   -- Send email
   -- send_email (
   --    p_to => r.email_address, 
   --    p_from => arcsql_cfg.default_email_from_address,
   --    p_body => message_body,
   --    p_subject => 'Alert notifications for the '||nvl(g.contact_group_name, g.contact_group_key)||' contract_group');

end;

procedure process_available_contacts ( -- | Loop through each available contact in a contract group and process it.
   p_contact_group_id in number) is
   cursor available_contacts is 
   select * 
     from contact_group_members
    where contact_group_id=p_contact_group_id 
      -- Make sure the contact is available
      and arcsql.is_truthy_y(is_enabled)='y'
      -- Make sure email is enabled as an available target for the contact
      and arcsql.is_truthy_y(email_enabled)='y';
begin 
   for contact in available_contacts loop 
      process_contact (
         p_contact_id=>contact.contact_id,
         p_contact_group_id=>p_contact_group_id);
   end loop;
end;

procedure process_available_contact_groups -- | Loop through each contract group that is currently enabled and process it.
   is 
   cursor available_groups is 
   select contact_group_id 
     from contact_groups
    where arcsql.is_truthy_y(is_enabled)='y';
begin 
   for contact_group in available_groups loop 
      process_available_contacts(contact_group.contact_group_id);
   end loop;
end;

procedure send_email (
   p_contact_id in number) is 
begin 
   null;
end;

end;
/

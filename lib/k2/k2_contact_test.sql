

-- begin 
--    k2_alert.create_priority_group (
--       p_priority_group_key=>'test_priority_group',
--       p_priority_group_name=>'Test',
--       p_user_id=>null);
--    k2_alert.open_alert(
--       p_priority_group_id=>k2_alert.get_priority_group_id('test_priority_group'),
--       p_alert_text=>'Test',
--       p_priority_level=>1,
--       p_alert_key=>'test_alert');
--     k2_contact.create_group('test_contact_group');
--     k2_contact.create_contact('test_contact', 'Ethan', 'post.ethan@gmail.com', null);
--     k2_contact.add_contact_to_group('test_contact', 'test_contact_group');
--     k2_contact.add_priority_group_to_contact_group('test_priority_group', 'test_contact_group');
-- end;
-- /

delete from arcsql_log;

create or replace package t as 
   email varchar2(100) := 'post.e.than@gmail.com';
end;
/

declare
   n number;
   v_alert_id number;
   v varchar2(120);
begin 

   arcsql.init_test('Create a contact group');
   k2_contact.create_group (
      p_contact_group_key=>'k2_test',
      p_contact_group_name=>'K2 test contact group');

   arcsql.init_test('Create a contact');
   k2_contact.create_contact (
      p_contact_key=>'k2_ethan',
      p_contact_name=>'Ethan',
      p_email=>t.email,
      p_sms=>null);

   arcsql_init_test('Add a contact to a group');
   k2_contact.add_contact_to_group (
      p_contact_key=>'k2_ethan',
      p_contact_group_key=>'k2_test');

   arcsql.init_test('Send an email to a contact');
   k2_contact.send_email (
      p_contact_key=>'k2_ethan',
      p_subject=>'Test email',
      p_body=>'This is a test email');

   arcsql.init_test('Send an email to a group');
   k2_contact.send_email (
      p_contact_group_key=>'k2_test',
      p_subject=>'Test group email',
      p_body=>'This is a group test email');

   arcsql.init_test('Link an alert priority group to a contact group');
   k2_contact.add_priority_group_to_contact_group (
      p_priority_group_key=>'k2_test',
      p_contact_group_key=>'k2_test');

end;
/

commit;

select * from arcsql_log where log_type in ('pass', 'fail', 'error') order by 1 desc;




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

create or replace package test as
   email varchar2(100) := 'post.e.than@gmail.com';
   user_id number;
   n number;
end;
/

/*

Our app starts with a user. 

*/

exec saas_auth_pkg.delete_user(test.email);
exec saas_auth_pkg.add_test_user(p_email=>test.email);
exec test.user_id := saas_auth_pkg.get_user_id_from_email(test.email);

declare
   v_alert_id number;
   v varchar2(120);
begin 

   arcsql.init_test('Create a contact group');
   k2_contact.create_group (
      p_contact_group_key=>'k2_test',
      p_contact_group_name=>'K2 test contact group',
      p_user_id=>test.user_id);
   select count(*) into test.n from contact_groups where contact_group_key='k2_test';
   if test.n = 1 then 
      arcsql.pass_test;
   else
      arcsql.fail_test;
   end if;

   arcsql.init_test('Create a contact');
   k2_contact.create_contact (
      p_contact_key=>'k2_ethan',
      p_contact_name=>'Ethan',
      p_email=>test.email,
      p_sms=>null,
      p_user_id=>test.user_id);
   select count(*) into test.n from contacts where contact_key='k2_ethan';
   if test.n = 1 then 
      arcsql.pass_test;
   else
      arcsql.fail_test;
   end if;

   arcsql.init_test('Add a contact to a group');
   k2_contact.add_member_to_group (
      p_contact_key=>'k2_ethan',
      p_contact_group_key=>'k2_test');
   select count(*) into test.n from contact_group_members
    where contact_id=k2_contact.to_contact_id('k2_ethan')
      and contact_group_id=k2_contact.to_contact_group_id('k2_test');
   if test.n = 1 then
      arcsql.pass_test;
   else
      arcsql.fail_test;
   end if;

   arcsql.init_test('Create an alert priority group');
   k2_alert.create_priority_group (
      p_priority_group_key=>'k2_test',
      p_priority_group_name=>'K2 test priority group',
      p_user_id=>test.user_id);

   arcsql.init_test('Link an alert priority group to a contact group');
   k2_contact.add_priority_group_to_contact_group (
      p_priority_group_key=>'k2_test',
      p_contact_group_key=>'k2_test');

end;
/

commit;

select * from arcsql_log where log_type in ('pass', 'fail', 'error') order by 1 desc;

select count(*) tests,
       log_type
 from arcsql_log
group
   by log_type;


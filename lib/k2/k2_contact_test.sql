

-- begin 
--    k2_alert.create_contact_group (
--       p_group_key=>'test_group',
--       p_group_name=>'Test',
--       p_user_id=>null);
--    k2_alert.open_alert(
--       p_group_id=>k2_alert.get_group_id('test_group'),
--       p_alert_text=>'Test',
--       p_priority_level=>1,
--       p_alert_key=>'test_alert');
--     k2_contact.create_contact_group('test_contact_group');
--     k2_contact.create_contact('test_contact', 'Ethan', 'post.ethan@gmail.com', null);
--     k2_contact.add_contact_to_contact_group('test_contact', 'test_contact_group');
--     k2_contact.add_group_to_contact_group('test_group', 'test_contact_group');
-- end;
-- /


create or replace package test as
   email varchar2(128) := app_config.app_test_user;
   user_id number;
   n number;
end;
/

exec k2_test.setup;

exec test.user_id := saas_auth_pkg.get_user_from_user_name(p_user_name=>test.email);

declare
   v_alert_id number;
   v varchar2(128);
begin 

   arcsql.init_test('Create a contact group');
   k2_contact.create_contact_group (
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
      p_email_address=>test.email,
      p_text_address=>null,
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
   k2_alert.create_contact_group (
      p_group_key=>'k2_test',
      p_group_name=>'K2 test priority group',
      p_user_id=>test.user_id);

   arcsql.init_test('Link an alert priority group to a contact group');
   k2_contact.add_group_to_contact_group (
      p_group_key=>'k2_test',
      p_contact_group_key=>'k2_test');

end;
/

commit;

@k2_test_result.sql


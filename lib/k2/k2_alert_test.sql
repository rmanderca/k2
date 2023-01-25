

delete from arcsql_log;

create or replace package test as
   email varchar2(100) := 'post.e.than@gmail.com';
   user_id number;
   n number;
end;
/

begin 
   select user_id into test.user_id from saas_auth where user_name='k2';
   k2_alert.create_group (
      p_group_key=>'k2_test',
      p_group_name=>'Test',
      p_user_id=>test.user_id);
   k2_alert.open_alert(
      p_group_id=>k2_alert.get_group_id('k2_test'),
      p_alert_text=>'Test',
      p_priority_level=>3,
      p_alert_key=>'k2_test_alert');
end;
/

declare
   n number;
   v varchar2(120);
begin 
   
   k2_alert.delete_group('k2_test');
   arcsql.init_test('Priority group used for testing should be deleted');
   if not k2_alert.does_group_exist(p_group_key=>'k2_test') then 
      arcsql.pass_test;
   else 
      arcsql.fail_test;
   end if;

   arcsql.init_test('Create a new alert priority group');
   k2_alert.create_group (
      p_group_key=>'k2_test',
      p_group_name=>'Test',
      p_user_id=>test.user_id);
   if k2_alert.does_group_exist(p_group_key=>'k2_test') then 
      arcsql.pass_test;
   else 
      arcsql.fail_test;
   end if;

   arcsql.init_test('Open an alert');
   k2_alert.open_alert(
      p_group_id=>k2_alert.get_group_id('k2_test'),
      p_alert_text=>'Test',
      p_priority_level=>3,
      p_alert_key=>'k2_test_alert');
   arcsql.pass_test;

   arcsql.init_test('Make sure a record exists in the alerts table for the alert');
   select count(*) into n from alerts where alert_key='k2_test_alert';
   if n = 1 then 
      arcsql.pass_test;
   else 
      arcsql.fail_test;
   end if;

   arcsql.init_test('Open the same alert, nothing should happen');
   k2_alert.open_alert(
      p_group_id=>k2_alert.get_group_id('k2_test'),
      p_alert_text=>'Test',
      p_priority_level=>3,
      p_alert_key=>'k2_test_alert');
   arcsql.pass_test;

   arcsql.init_test('There should still be only one record in the alerts table for the original alert');
   select count(*) into n from alerts where alert_key='k2_test_alert';
   if n = 1 then 
      arcsql.pass_test;
   else 
      arcsql.fail_test;
   end if;

   arcsql.init_test('Running check_alerts should not generate any errors');
   k2_alert.check_alerts;
   arcsql.pass_test;

   arcsql.init_test('Closing the alert should not generate any errors');
   k2_alert.close_alert(p_alert_key=>'k2_test_alert');
   arcsql.pass_test;

   arcsql.init_test('Validate the alert is in closed status');
   select alert_status into v from alerts where alert_key='k2_test_alert';
   if v = 'closed' then 
      arcsql.pass_test;
   else 
      arcsql.fail_test;
   end if;

end;
/

commit;

select * from arcsql_log where log_type in ('pass', 'fail', 'error') order by 1 desc;

select count(*) tests,
       log_type
 from arcsql_log
group
   by log_type;

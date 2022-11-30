

begin 
   k2_alert.create_priority_group (
      p_priority_group_key=>'k2_test',
      p_priority_group_name=>'Test',
      p_user_id=>987654321);
   k2_alert.open_alert(
      p_priority_group_id=>k2_alert.get_priority_group_id('k2_test'),
      p_alert_text=>'Test',
      p_priority_level=>3,
      p_alert_key=>'k2_test_alert');
end;
/


delete from arcsql_log;

declare
   n number;
   v_alert_id number;
   v varchar2(120);
begin 
   
   k2_alert.delete_priority_group('k2_test');
   arcsql.init_test('Priority group used for testing should be deleted');
   if not k2_alert.does_priority_group_exist(p_priority_group_key=>'k2_test') then 
      arcsql.pass_test;
   else 
      arcsql.fail_test;
   end if;

   arcsql.init_test('Create a new alert priority group');
   k2_alert.create_priority_group (
      p_priority_group_key=>'k2_test',
      p_priority_group_name=>'Test',
      p_user_id=>987654321);
   if k2_alert.does_priority_group_exist(p_priority_group_key=>'k2_test') then 
      arcsql.pass_test;
   else 
      arcsql.fail_test;
   end if;

   arcsql.init_test('Open an alert');
   k2_alert.open_alert(
      p_priority_group_id=>k2_alert.get_priority_group_id('k2_test'),
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
   
   arcsql.init_test('Make sure the alert log has 1 entry');
   select alert_id into v_alert_id from alerts where alert_key='k2_test_alert';
   select count(*) into n from alert_log where alert_id=v_alert_id;
   if n = 1 then 
      arcsql.pass_test;
   else 
      arcsql.fail_test;
   end if;

   arcsql.init_test('Open the same alert, nothing should happen');
   k2_alert.open_alert(
      p_priority_group_id=>k2_alert.get_priority_group_id('k2_test'),
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

   arcsql.init_test('Adding entries to the alert log should not generate any errors');
   k2_alert.insert_alert_log(v_alert_id, 'reminder');
   k2_alert.insert_alert_log(v_alert_id, 'closed');
   k2_alert.insert_alert_log(v_alert_id, 'abandoned');
   k2_alert.insert_alert_log(v_alert_id, 'autoclosed');
   arcsql.pass_test;

   arcsql.init_test('Make sure the alert log has 5 entries');
   select count(*) into n from alert_log where alert_id=v_alert_id;
   if n = 5 then 
      arcsql.pass_test;
   else 
      arcsql.fail_test;
   end if;

   arcsql.init_test('Closing the alert should not generate any errors');
   k2_alert.close_alert(p_alert_key=>'k2_test_alert');
   arcsql.pass_test;

   arcsql.init_test('Validate the alert is in closed status');
   select alert_status into v from alerts where alert_id=v_alert_id;
   if v = 'closed' then 
      arcsql.pass_test;
   else 
      arcsql.fail_test;
   end if;

   arcsql.init_test('Make sure the alert log has 6 entries');
   select count(*) into n from alert_log where alert_id=v_alert_id;
   if n = 5 then 
      arcsql.pass_test;
   else 
      arcsql.fail_test;
   end if;

end;
/

commit;

select * from arcsql_log where log_type in ('pass', 'fail', 'error') order by 1 desc;


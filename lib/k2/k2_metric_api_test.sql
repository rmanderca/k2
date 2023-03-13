

delete from arcsql_log;

create or replace package test as
   email varchar2(128) := app_config.app_test_user;
   user_id number;
   n number;
   dataset dataset%rowtype;
end;
/

begin
   saas_auth_pkg.delete_user(test.email);
   saas_auth_pkg.add_user(
        p_email_address=>test.email,
        p_user_name=>test.email,
        p_password=>app_config.app_test_pass);
end;
/

exec test.user_id := saas_auth_pkg.get_user_from_user_name(p_user_name=>test.email);

begin 
   select user_id into test.user_id from saas_auth where user_name=test.email;

   arcsql.init_test('Create a dataset and update metric');
   
   -- Create a dataset
   k2_metric_api.create_dataset_v1 (
      p_dataset_key => 'test_dataset_'||test.user_id,
      p_dataset_name => 'Test dataset',
      p_user_id => test.user_id);

   test.dataset := k2_metric.get_dataset_row(p_dataset_key=>'test_dataset_'||test.user_id);

   k2_metric_api.update_metric_v1 (
      p_dataset_token => test.dataset.dataset_token,
      p_metric => 'test_metric',
      p_value => 1.25);

   select count(*) into test.n from metric_in where dataset_key=test.dataset.dataset_key;
   if test.n = 1 then 
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


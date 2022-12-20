
delete from arcsql_log;

create or replace package test as
   email varchar2(100) := 'post.e.than@gmail.com';
   user_id number;
   n number;
end;
/

-- This requires an APEX session to work
-- begin
--    arcsql.init_test('Create a regular user');
--    saas_auth_pkg.delete_user(test.email);
--    saas_auth_pkg.create_account(
--       p_user_name=>test.email,
--       p_email=>test.email,
--       p_password=>saas_auth_config.saas_auth_test_pass,
--       p_confirm=>saas_auth_config.saas_auth_test_pass);
-- end;
-- /

begin 
   arcsql.init_test('k2@builtonapex.com system user should already exist');
   select count(*) into test.n from saas_auth where email='k2@builtonapex.com' and role_id=3;
   if test.n=1 then
      arcsql.pass_test;
   else
      arcsql.fail_test;
   end if;
end;
/

exec saas_auth_pkg.delete_user(p_user_name=>test.email);

begin 
   arcsql.init_test('Create a system user account');
   saas_auth_pkg.add_user (
      p_user_name=>test.email,
      p_email=>test.email,
      p_password=>saas_auth_config.saas_auth_test_pass);
   select user_id into test.user_id from saas_auth where email=test.email;
   saas_auth_pkg.assign_user_role(
      p_user_id=>test.user_id,
      p_role_name=>'system');
   select count(*) into test.n from saas_auth where user_id=test.user_id and role_id=3;
   if test.n > 0 then 
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

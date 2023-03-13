
delete from arcsql_log;

create or replace package test as
   email varchar2(100) := 'post.e.than@gmail.com';
   password varchar2(100) := arcsql.str_random(15)||'x!';
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
--       p_email_address=>test.email,
--       p_password=>saas_auth_config.saas_auth_test_pass,
--       p_confirm=>saas_auth_config.saas_auth_test_pass);
-- end;
-- /

begin 
   arcsql.init_test('k2 system user should already exist');
   select count(*) into test.n from saas_auth where user_name='k2' and account_type='system';
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
   saas_auth_pkg.add_system_user (
      p_user_name=>test.email,
      p_email_address=>test.email);
   select user_id into test.user_id from saas_auth where email=test.email;
   select count(*) into test.n from saas_auth where user_id=test.user_id and account_type='system';
   if test.n > 0 then 
      arcsql.pass_test;
   else
      arcsql.fail_test;
   end if;
end;
/

declare
   v_email varchar2(100) := 'ethan@arclogicsoftware.com';
   v_full_name varchar2(100) := 'Ethan Post';
   v_token varchar2(12);
   n number;
begin 
   -- wwv_flow_api.set_security_group_id;
   delete from saas_auth where user_name=v_email;
   -- User enters email on create-account page
   saas_auth_pkg.initiate_account(p_email_address=>v_email);
   -- Send an email verification request to the user
   saas_auth_pkg.send_verify_email_request(p_user_name=>v_email);
   select email_verification_token into v_token from saas_auth where user_name=v_email;
   -- We know the token is good but we would typically need to check to see if it exists.
   select count(*) into n from saas_auth where email_verification_token=v_token;
   -- User clicks link and ends up on account-setup page, fills out form (full name, password)
   -- Even if the token is expired we will update pass and full name but user won't be able to login yet.
   if saas_auth_pkg.does_verify_token_exist(p_token=>v_token) then
      saas_auth_pkg.set_password(p_user_name=>v_email, p_password=>arcsql.str_random(12)||'x!');
      update saas_auth set full_name=v_full_name where user_name=v_email;
   end if;

   -- If the token has not expired we will verify the account and log the user in.
   if saas_auth_pkg.is_verify_token_valid(v_token) then
      saas_auth_pkg.verify_account(p_token=>v_token);
      -- Throws ORA-20987: APEX - Application not found. which is expected. Here for documentation.
      -- saas_auth_pkg.login(p_user_name=>v_email);
      -- If we could we would redirect to home page here.
   else 
      -- If the token has expired but is otherwise valid we need to send a new validation email.
      -- This email will be include an auto login link instead of a verification link.
      -- If we could we would redirect to thank-you page but may modify the message displayed.
      null;
   end if;
   -- If token is expired send a new email and redirect to the page instructing the user to verify thier email.
   -- This link should be an auto login link instead of a account-setup link.
   commit;
end;
/

commit;

select * from arcsql_log where log_type in ('pass', 'fail', 'error') order by 1 desc;

select count(*) tests,
       log_type
 from arcsql_log
group
   by log_type;

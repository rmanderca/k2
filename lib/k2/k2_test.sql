
create or replace package k2_test as 
   user_id number;
   procedure setup;
end;
/

create or replace package body k2_test as 

/*

### setup (procedure)

Performs common test setup tasks.

* Deletes all data from ARCSQL_LOG table.
* Deletes and recreates your main test user (account status is set to active) - app_config.app_test_user
* Sets k2_test.user_id to the test user.

*/

procedure setup is 
begin 
   delete from arcsql_log;
   if saas_auth_pkg.does_user_name_exist(app_config.app_test_user) then
      saas_auth_pkg.delete_user(saas_auth_pkg.to_user_id(p_user_name=>app_config.app_test_user));
   end if;
   saas_auth_pkg.add_account (
      p_email_address=>app_config.app_test_user,
      p_full_name=>app_config.app_test_user,
      p_password=>app_config.app_test_pass,
      p_account_status=>'active');
   k2_test.user_id := saas_auth_pkg.to_user_id(p_user_name=>app_config.app_test_user);
end;

end;
/




begin 
   if app_config.env = 'dev' then
      if trim(app_config.app_test_user) is not null then 
         if not saas_auth_pkg.does_user_name_exist(app_config.app_test_user) then
            saas_auth_pkg.add_account(
               p_email=>app_config.app_test_user,
               p_full_name=>app_config.app_test_user, 
               p_password=>app_config.app_test_pass,
               p_account_status=>'active');
         end if;
      end if;
   end if;
end;
/

select 'Add other default app accounts here' m from dual;

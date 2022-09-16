

/*
This file contains test accounts which are set up when install.sql is run.
*/

-- ToDo: Keep track of is_dev state and if anything has ever been dev and is now prd prevent dev user logins or is_dev should return error.


begin 
    if k2_config.env = 'dev' then 
        saas_auth_pkg.add_test_user(p_email=>'donotreply@notmydomain.com');
    else
        saas_auth_pkg.delete_user(p_email=>'donotreply@notmydomain.com');
    end if;
end;
/




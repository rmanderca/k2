
delete from arcsql_log;

create or replace package test as
   email varchar2(100) := app_config.app_test_user;
   user_id number;
   api_token varchar2(240);
end;
/

declare 
	n number;
	v varchar2(120);
	
begin

    saas_auth_pkg.delete_user(p_user_name=>test.email);
    
	arcsql.init_test('Make sure test user does not exist');
	if not saas_auth_pkg.does_user_name_exist(test.email) then
        arcsql.pass_test;
    else
    	arcsql.fail_test;
    end if;

	arcsql.init_test('Create test user');
	saas_auth_pkg.add_user(
        p_email=>test.email,
        p_user_name=>test.email,
        p_password=>app_config.app_test_pass);
	if saas_auth_pkg.does_user_name_exist(test.email) then
        arcsql.pass_test;
    else
    	arcsql.fail_test;
    end if;

    test.user_id := saas_auth_pkg.get_user_id_from_user_name(p_user_name=>test.email);

    arcsql.init_test('Generate an API token for the user');
    test.api_token := k2_token.create_token(p_token_key=>'api_token_'||test.user_id, p_user_id=>test.user_id);
    arcsql.debug('api_token: '||test.api_token);
    if length(test.api_token) > 0 then
		arcsql.pass_test;
	else
		arcsql.fail_test;
	end if;

	arcsql.init_test('Make sure a record exists for the token in the api_token table');
	select count(*) into n from tokens where token=test.api_token;
	if n > 0 then
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

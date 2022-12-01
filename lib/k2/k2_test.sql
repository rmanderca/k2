
delete from arcsql_log;

create or replace package t as
   email varchar2(100) := 'post.e.than@gmail.com';
   user_id number;
   api_token varchar2(240);
end;
/

declare 
	n number;
	v varchar2(120);
	
begin

    saas_auth_pkg.delete_user(p_email=>t.email);
    
	arcsql.init_test('Make sure test user does not exist');
	if not saas_auth_pkg.does_user_name_exist(t.email) then
        arcsql.pass_test;
    else
    	arcsql.fail_test;
    end if;

	arcsql.init_test('Create test user');
	saas_auth_pkg.add_test_user(p_email=>t.email);
	if saas_auth_pkg.does_user_name_exist(t.email) then
        arcsql.pass_test;
    else
    	arcsql.fail_test;
    end if;

    t.user_id := saas_auth_pkg.get_user_id_from_email(t.email);

    arcsql.init_test('Generate an API token for the user');
    t.api_token := k2.get_new_api_token(t.user_id);
    arcsql.debug('api_token: '||t.api_token);
    if length(t.api_token) > 0 then
		arcsql.pass_test;
	else
		arcsql.fail_test;
	end if;

	arcsql.init_test('Make sure a record exists for the token in the api_token table');
	select count(*) into n from api_token where token=t.api_token;
	if n > 0 then
		arcsql.pass_test;
	else
		arcsql.fail_test;
	end if;

	arcsql.init_test('Use the API token as a bearer token to check the status of the api');
	k2.api_get_request(p_token=>t.api_token);

end;
/

commit;

select * from arcsql_log where log_type in ('pass', 'fail') order by 1;
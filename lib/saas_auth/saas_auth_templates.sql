

exec drop_procedure('saas_auth_verify_email_subject');

exec drop_procedure('saas_auth_verify_email_body');


create or replace function saas_auth_one_time_login_subject return clob is 
begin
	return 'One-time login link for  '||app_config.app_name;
end;
/

create or replace function saas_auth_one_time_login_body return clob is 
begin
	return 'Hello,

You requested a one-time login link to access your '||app_config.app_name||' account. To log in, click the link below:

#ONE_TIME_LOGIN_LINK#

This link will allow you to log in to your account without a password and will expire in 1 hour. If you did not request this login link, please ignore this email.

';

end;
/

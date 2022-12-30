

create or replace function saas_auth_verify_email_subject return clob is 
begin
	return 'Reminder: Complete your '||app_config.app_name||' sign up';
end;
/

create or replace function saas_auth_verify_email_body return clob is 
	/*
	You can create your own version of this function in your app.
	Placeholders:
		{APP_NAME}
		{ONE_TIME_LOGIN_LINK}
	*/
begin
	return '### You''re almost there!
 
Thank you for signing up for '||app_config.app_name||'! Click the link below to verify your email, and we''ll help you get started.

### #ONE_TIME_LOGIN_LINK#

You received this email because you signed up for an '||app_config.app_name||' account with this email address. If this was a mistake, ignore this email -- the account hasn''t been created yet.';

end;
/

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

-- Verify: Make sure you have modified and implemented this procedure if want to enable email.

create or replace procedure app_send_email ( -- | Primary email interface for sending an email.
   -- Valid email address to which the email is sent (required). For multiple email addresses, use a comma-separated list
   p_to in varchar2,
   -- Email address from which the email is sent (required). This email address must be a valid address. Otherwise, the message is not sent.
   p_from in varchar2,
   -- Body of the email in plain text, not HTML (required). If a value is passed to p_body_html, then this is the only text the recipient sees. If a value is not passed to p_body_html, then this text only displays for email clients that do not support HTML or have HTML disabled. A carriage return or line feed (CRLF) must be included every 1000 characters.
   p_body in varchar2,
   -- Subject of the email.
   p_subject in varchar2 default null) is
begin 
   if arcsql.is_truthy(app_config.disable_email) then 
      return;
   end if;
   -- This line needs to be added for Maxapex.
   -- Update: 2/22/2022 Setting this caused erratic behavior in the return for apex_page.get_url.
   -- It would return full url with domain and change from f= type of url to pretty url. 
   -- Sending email from Maxapex seems to work without this being set.
   -- wwv_flow_api.set_security_group_id;
   apex_mail.send(
      p_to=>p_to,
      p_from=>p_from,
      p_subj=>p_subject,
      p_body=>p_body,
      p_body_html=>p_body
      );
   apex_mail.push_queue;
   -- This should not raise an error if email does not exist since devs could use app_send_email to send emails to users not in saas_auth table.
   arcsql.increment_counter(app_config.app_name||', app_send_email, '||p_to);
   commit;
end;
/

create or replace procedure send_test_email is -- | Send a test email.
begin 
   app_send_email (
      p_to=>app_config.app_email,
      p_from=>app_config.app_from_email,
      p_subject=>'Test email sent at '||to_char(sysdate,'MM/DD/YYYY HH24:MI:SS'),
      p_body=>'This is a test email sent at '||to_char(sysdate,'MM/DD/YYYY HH24:MI:SS'));
end;
/




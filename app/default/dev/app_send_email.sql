-- Verify: Make sure you have modified and implemented this procedure if want to enable email.

/*

### app_send_email (procedure)

Primary app email interface for sending an email.

* **p_to** - One or more comma separated addresses.
* **p_from** - Defaults to app_config.app_from_email which is usually best.
* **p_body** - Defaults to 'Empty message'. Null is not allowed. 
* **p_subject** - Subject of the message.

Body of the email in plain text, not HTML . If a value is passed to p_body_html, then this is the only text the recipient sees. If a value is not passed to p_body_html, then this text only displays for email clients that do not support HTML or have HTML disabled. A carriage return or line feed (CRLF) must be included every 1000 characters.

*/

-- uninstall: exec drop_procedure('app_send_email');
create or replace procedure app_send_email ( -- | 
   p_to in varchar2 default null, 
   p_from in varchar2 default app_config.app_from_email, 
   p_body in varchar2 default 'Empty message',
   p_subject in varchar2 default null 
   ) is
   v_to varchar2(256) := lower(p_to);
begin 
   if arcsql.is_truthy(app_config.disable_email) then 
      return;
   end if;
   
   -- Override will not override an app owner email.
   if trim(app_config.email_override) is not null and v_to != app_config.app_owner_email then 
      v_to := app_config.email_override;
   end if;

   -- This line needs to be added for Maxapex.
   -- Update: 2/22/2022 Setting this caused erratic behavior in the return for apex_page.get_url.
   -- It would return full url with domain and change from f= type of url to pretty url. 
   -- Sending email from Maxapex seems to work without this being set.
   -- wwv_flow_api.set_security_group_id;
   apex_mail.send(
      p_to=>v_to,
      p_from=>p_from,
      p_subj=>p_subject,
      p_body=>p_body,
      p_body_html=>p_body
      );
   apex_mail.push_queue;
   arcsql.increment_counter(app_config.app_name||', app_send_email, '||p_to);
   commit;
end;
/

create or replace procedure app_owner_email (
   p_subject in varchar2,
   p_body in varchar2 default null) is
begin
   app_send_email (
      p_subject=>p_subject,
      p_body=>p_body,
      p_to=>app_config.app_owner_email);
end;
/

create or replace procedure app_send_email_attachment ( -- | Primary email interface for sending an email with an attachment.
   p_to in varchar2,
   p_from in varchar2 default app_config.app_from_email,
   p_body in varchar2, 
   p_subject in varchar2 default null,
   p_blob in blob,
   p_mimetype in varchar2,
   p_file_name in varchar2
   ) is
   v_mail_id number;
   v_to varchar2(256) := p_to;
begin 
   if arcsql.is_truthy(app_config.disable_email) then 
      return;
   end if;
   if lower(v_to) != lower(app_config.app_owner_email) then
      v_to := nvl(trim(app_config.email_override), p_to);
   end if;
   -- wwv_flow_api.set_security_group_id;
   v_mail_id := apex_mail.send(
      p_to=>v_to,
      p_from=>p_from,
      p_subj=>p_subject,
      p_body=>p_body,
      p_body_html=>p_body
      );

   apex_mail.add_attachment(
      p_mail_id=>v_mail_id,
      p_attachment=>p_blob,
      p_filename=>p_file_name,
      p_mime_type=>p_mimetype);
   
   apex_mail.push_queue;
   arcsql.increment_counter(app_config.app_name||', app_send_email_attachment, '||p_to);
   commit;
end;
/

-- uninstall: exec drop_procedure('send_test_email');
create or replace procedure send_test_email is -- | Send a test email.
begin 
   app_send_email (
      p_subject=>'Test email sent at '||to_char(sysdate,'MM/DD/YYYY HH24:MI:SS'),
      p_body=>'This is a test email sent at '||to_char(sysdate,'MM/DD/YYYY HH24:MI:SS'));
end;
/




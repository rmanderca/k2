create or replace package body twilio as 

procedure foo is 
begin
   null;
end;


procedure send_sms_message (
   p_phone_to in varchar2,
   p_messaging_service_sid in varchar2 default 'MG4edcec20a54c1e1b3d580eba5cc38d6f',
   p_phone_from in varchar2,
   p_twilio_account_id in varchar2 default 'ACffb66f5fa4927ac5bbb37208d9b218df',
   p_twilio_auth_token in varchar2,
   p_message_body in varchar2) is 
   v_parms varchar2(120);
   v_values varchar2(120);
begin 
   apex_web_service.g_request_headers.delete();
   apex_web_service.g_request_headers(1).name := 'content-type';
   apex_web_service.g_request_headers(1).value := 'application/x-www-form-urlencoded'; 
   v_parms := 'to:MessagingServiceSid:body';
   v_values := p_phone_to||':'||p_messaging_service_sid||':'||p_message_body;

   response := apex_web_service.make_rest_request (
      p_url         => 'https://api.twilio.com/2010-04-01/Accounts/'||p_twilio_account_id||'/Messages.json', 
      p_http_method => 'POST',
      p_parm_name   => apex_util.string_to_table(v_parms),
      p_parm_value  => apex_util.string_to_table(v_values));
      arcsql.debug(response);
   apex_json.parse(response);
end;
/

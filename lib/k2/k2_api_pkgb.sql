
create or replace package body k2_api as 

procedure status_v1 is 
   -- l_cursor sys_refcursor;
begin 
   -- open l_cursor for 
   -- select * from arcsql_log where rownum < 5;
   -- apex_json.write(l_cursor);
   arcsql.debug('k2_api.status');
   apex_json.open_object;
   apex_json.write('status', 'ok');
   apex_json.close_object;
exception
   when others then
      raise;
end;

procedure json_message (
   p_message in varchar2,
   p_key in varchar2 default 'message') is 
begin
   apex_json.open_object;
   apex_json.write(p_key, p_message);
   apex_json.close_object;
end;

procedure json_response (
   -- Note this does not escape things like line returns.
   p_json in varchar2) is 
begin
   owa_util.mime_header('application/json', false);
   owa_util.http_header_close;
   htp.p(p_json);
end;

procedure assert_bearer_token_exists is 
   authorization_header varchar2(256);
begin
   authorization_header := owa_util.get_cgi_env('authorization');
   if instr(lower(authorization_header), 'bearer') = 0 then 
      raise_application_error(-20001, 'Bearer token not found in request');
   end if;
end;

function get_bearer_token -- | Returns just the token from the CGI env 'authorization' header.
   return varchar2 is 
   authorization_header varchar2(256);
begin 
   assert_bearer_token_exists;
   authorization_header := owa_util.get_cgi_env('authorization');
   return trim(substr(authorization_header, instr(lower(authorization_header), 'bearer')+6));
exception
   when others then 
      arcsql.log_err('get_bearer_token', dbms_utility.format_error_stack);
      raise;
end;

end;
/

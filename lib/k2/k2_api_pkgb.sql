
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

procedure success_message is 
begin
   apex_json.open_object;
   apex_json.write('message', 'success');
   apex_json.close_object;
end;

procedure error_message (
   p_error_message in varchar2) is 
begin 
   arcsql.log_err(p_error_message);
   apex_json.open_object;
   apex_json.write('error', p_error_message);
   apex_json.close_object;
end;

procedure assert_bearer_token_exists is 
   authorization_header varchar2(250);
begin
   authorization_header := owa_util.get_cgi_env('authorization');
   if instr(lower(authorization_header), 'bearer') = 0 then 
      raise_application_error(-20001, 'Bearer token not found in request');
   end if;
end;

function get_bearer_token -- | Returns just the token from the CGI env 'authorization' header.
   return varchar2 is 
   authorization_header varchar2(250);
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

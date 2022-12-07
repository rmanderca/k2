
create or replace package body k2_api as 

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

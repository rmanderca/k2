
-- uninstall: exec drop_package('k2_api');

create or replace package k2_api as 

   procedure status_v1;

   procedure json_message (
      p_message in varchar2,
      p_key in varchar2 default 'message');

   procedure json_response (p_json in varchar2);

   procedure assert_bearer_token_exists;

   function get_bearer_token return varchar2;

end;
/

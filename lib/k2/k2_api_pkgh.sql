
-- uninstall: exec drop_package('k2_api');

create or replace package k2_api as 

procedure status;

procedure assert_bearer_token_exists;

function get_bearer_token return varchar2;

end;
/

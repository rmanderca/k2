
-- uninstall: exec drop_package('k2_token');
create or replace package k2_token as 

procedure save_token_row (
   p_token_row in tokens%rowtype);

function get_token_row (
   p_token_key in varchar2)
   return tokens%rowtype;

function get_token_row (
   p_token in varchar2)
   return tokens%rowtype;

procedure create_token (
   p_token_key in varchar2,
   p_user_id in number);

procedure assert_valid_token (
   p_token in varchar2);

end;
/


-- uninstall: exec drop_package('k2_token');
create or replace package k2_token as 

procedure update_token (
   p_token_id in number);

procedure save_token_row (
   p_token_row in tokens%rowtype);

function get_token_row (
   p_token_key in varchar2)
   return tokens%rowtype;

function get_token_row (
   p_token in varchar2)
   return tokens%rowtype;

function get_token_row ( 
   p_token_id in varchar2)
   return tokens%rowtype;

procedure create_token (
   p_token_key in varchar2,
   p_token_type in varchar2,
   p_user_id in number default null,
   p_expires_in_minutes in number default null,
   p_token_alt_id in number default null,
   p_bytes in number default 32);

function create_token (
   p_token_key in varchar2,
   p_token_type in varchar2,
   p_user_id in number default null,
   p_expires_in_minutes in number default null,
   p_token_alt_id in number default null,
   p_bytes in number default 32)
   return varchar2;

function is_valid_token (
   p_token in varchar2,
   p_user_id in number default null)
   return boolean;

procedure assert_valid_token (
   p_token in varchar2,
   p_user_id in number default null);

end;
/

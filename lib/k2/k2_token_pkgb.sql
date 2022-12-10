
create or replace package body k2_token as 

procedure save_token_row (
   p_token_row in tokens%rowtype) is 
begin
   update tokens set row=p_token_row where token_key=p_token_row.token_key;
   update tokens set updated = systimestamp where token_key=p_token_row.token_key;
end;

function get_token_row (
   p_token_key in varchar2)
   return tokens%rowtype is 
   r tokens%rowtype;
begin
   select * into r from tokens where token_key = p_token_key;
   return r;
end;

function get_token_row (
   p_token in varchar2)
   return tokens%rowtype is 
   r tokens%rowtype;
begin
   select * into r from tokens where token = p_token;
   return r;
end;

procedure create_token ( -- | Creates a token for a user.
   p_token_key in varchar2,
   p_user_id in number) is 
begin
   insert into tokens (
      token_key,
      token,
      user_id) values (
      p_token_key,
      sys_guid(),
      p_user_id);
end;

function create_token ( -- | Creates a token for a user and returns it.
   p_token_key in varchar2,
   p_user_id in number)
   return varchar2 is 
   r tokens%rowtype;
begin 
   create_token(p_token_key=>p_token_key, p_user_id=>p_user_id);
   r := get_token_row(p_token_key=>p_token_key);
   return r.token;
end;

procedure assert_valid_token (
   p_token in varchar2) is 
   n number;
   r tokens%rowtype;
begin 
   select count(*) into n from tokens where token=p_token;
   if n = 1 then
      select * into r from tokens where token=p_token;
      if r.is_enabled = 1 then 
         return;
      end if;
   end if;
   raise_application_error(-20001, 'Token is invalid');
end;

end;
/

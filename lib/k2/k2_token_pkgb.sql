
create or replace package body k2_token as 

procedure update_token ( -- | Updates the token with a new value and sets a new expiration date if the old one was set.
   /*
   We figure out the expiration date by looking at the interval between the last token date and the expiration date.
   */
   p_token_id in number) is 
   v_token tokens%rowtype := get_token_row(p_token_id=>p_token_id);
   expire_interval number;
begin
   if v_token.expires is not null then
      expire_interval := arcsql.secs_between_timestamps(v_token.token_date, v_token.expires);
   end if;
   update tokens set token=dbms_crypto.randombytes(32), updated=systimestamp, token_date=systimestamp where token_id=p_token_id;
   if expire_interval is not null then 
      update tokens set expires=token_date+(expire_interval/(24*60*60)) where token_id=p_token_id;
   end if;
end;

procedure save_token_row ( -- | Pass in tokens%rowtype and it will update the existing row.
   p_token_row in tokens%rowtype) is 
begin
   update tokens set row=p_token_row where token_id=p_token_row.token_id;
   if sql%rowcount = 0 then 
      raise_application_error(-20001, 'save_token_row: Token not found!');
   end if;
   update tokens set updated = systimestamp where token_id=p_token_row.token_id;
end;

function get_token_row ( -- | Return tokens%rowtype using a token_key.
   p_token_key in varchar2)
   return tokens%rowtype is 
   r tokens%rowtype;
begin
   select * into r from tokens where token_key = p_token_key;
   return r;
end;

function get_token_row ( -- | Get a token row using the token.
   p_token in varchar2)
   return tokens%rowtype is 
   r tokens%rowtype;
begin
   select * into r from tokens where token = p_token;
   return r;
end;

function get_token_row ( -- | Get a token row using the id.
   p_token_id in varchar2)
   return tokens%rowtype is 
   r tokens%rowtype;
begin
   select * into r from tokens where token_id = p_token_id;
   return r;
end;

procedure create_token ( -- | Create a token for a user.
   p_token_key in varchar2,
   p_token_type in varchar2,
   p_user_id in number,
   p_expires_in_minutes in number default null,
   p_token_alt_id number default null) is 
   v_expires timestamp;
   v_token varchar2(256) := dbms_crypto.randombytes(32);
   -- v_token := sys_guid();
begin
   if p_expires_in_minutes is not null then
      v_expires := systimestamp + (p_expires_in_minutes / (24*60));
   end if;
   insert into tokens (
      token_key,
      token_type,
      token,
      user_id,
      expires,
      token_alt_id) values (
      p_token_key,
      p_token_type,
      v_token,
      p_user_id,
      v_expires,
      p_token_alt_id);
end;

function create_token ( -- | Create a token for a user while returning the token.
   p_token_key in varchar2,
   p_token_type in varchar2,
   p_user_id in number,
   p_expires_in_minutes in number default null,
   p_token_alt_id number default null)
   return varchar2 is 
   r tokens%rowtype;
begin 
   create_token(
      p_token_key=>p_token_key, 
      p_token_type=>p_token_type,
      p_user_id=>p_user_id, 
      p_expires_in_minutes=>p_expires_in_minutes,
      p_token_alt_id=>p_token_alt_id);
   r := get_token_row(p_token_key=>p_token_key);
   return r.token;
end;

procedure assert_valid_token ( -- | Raise an error if the token is invalid.
   p_token in varchar2) is 
   n number;
   r tokens%rowtype;
begin 
   select count(*) into n 
     from tokens 
    where token=p_token
      and nvl(expires, systimestamp-1) < systimestamp
      and is_enabled = 1;
   if n = 0 then
      raise_application_error(-20001, 'Token is invalid');
   end if;
end;

end;
/

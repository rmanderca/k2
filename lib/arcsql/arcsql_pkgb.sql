
-- ToDo: Add memory caching to debug and dump on error. Flag enabled. Flag enable for time period?

create or replace package body arcsql as

/* 
-----------------------------------------------------------------------------------
Advanced Queueing
-----------------------------------------------------------------------------------
*/

-- procedure queue_message (
--    p_key in varchar2,
--    p_message in varchar2) is 
--    enqueue_options dbms_aq.enqueue_options_t;
--    message_properties dbms_aq.message_properties_t;
--    message_id raw(16);
-- begin 
--    dbms_aq.enqueue (
--       queue_name         => 'arcsql_message_queue',
--       enqueue_options    => enqueue_options,
--       message_properties => message_properties,
--       payload            => p_message,
--       msgid              => message_id);
--    commit;
-- exception 
--    when others then
--       arcsql.log_err('queue_message: '||dbms_utility.format_error_stack);
--       raise;
-- end;

-- | -----------------------------------------------------------------------------------
-- | Datetime 
-- | -----------------------------------------------------------------------------------

function secs_between_timestamps ( -- | Return the number of seconds between two timestamps.
   time_start in timestamp, 
   time_end in timestamp) return number is
   total_secs number;
   d interval day(9) to second(6);
begin
   d := time_end - time_start;
   total_secs := abs(extract(second from d) + extract(minute from d)*60 + extract(hour from d)*60*60 + extract(day from d)*24*60*60);
   return round(total_secs, 3);
end;

function secs_since_timestamp ( -- | Return number of seconds since a timestamp.
   time_stamp timestamp) return number is
   now         timestamp;
   total_secs  number;
   d           interval day(9) to second(6);
begin
   now := cast(sysdate as timestamp);
   d := now - time_stamp;
   total_secs := abs(extract(second from d) + extract(minute from d)*60 + extract(hour from d)*60*60 + extract(day from d)*24*60*60);
   return total_secs;
end;

function get_date_from_epoch ( -- | This function converts an epoch timestamp to a date value.
   p_epoch in number) 
   return date is
begin
   return date'1970-01-01' + ( p_epoch / 86400 );
end;

function get_timestamp_from_epoch ( -- | This function returns a timestamp value from the input epoch value, which represents the number of seconds that have elapsed since January 1, 1970, at 00:00:00 UTC.
   p_epoch in number) 
   return timestamp is
begin
   return timestamp'1970-01-01 00:00:00' + numtodsinterval (p_epoch, 'second');
end;

function get_epoch_from_date ( -- | This function returns the epoch timestamp (number of seconds since 1970-01-01 00:00:00 UTC) corresponding to a given date input.
   p_date in date)
   return number is 
begin 
   return round ((p_date-date'1970-01-01') * 86400);
end;

function get_epoch_from_timestamp ( -- | This function returns the epoch time (number of seconds since 1970-01-01 00:00:00 UTC) for a given timestamp.
   p_timestamp in timestamp)
   return number is 
begin 
   return round(secs_between_timestamps(p_timestamp, timestamp'1970-01-01 00:00:00'));
end;

procedure raise_invalid_cron_expression (p_expression in varchar2) is 
begin 
   null;
end;

-- | -----------------------------------------------------------------------------------
-- | Timer 
-- | -----------------------------------------------------------------------------------

procedure start_timer (p_key in varchar2) is -- | Starts or resets the start time on a timer.
begin 
   -- Sets the timer variable to current time.
   g_timer_start(p_key) := sysdate;
end;

function get_timer ( -- | Return elap secs from timer and reset start time if desired.
   p_key in varchar2, 
   p_reset_start_time in boolean default false
   ) return number is
   -- Returns seconds since last call to 'get_time' or 'start_time' (within the same session).
   r number;
begin 
   r := round((sysdate-nvl(g_timer_start(p_key), sysdate))*24*60*60, 1);
   if p_reset_start_time then
      start_timer(p_key);
   end if;
   return r;
end;

-- | -----------------------------------------------------------------------------------
-- | Strings 
-- | -----------------------------------------------------------------------------------

function str_to_key_str (str in varchar2) -- | Replaces anything that isn't a letter or number with an underscore.
   return varchar2 is
   new_str varchar2(1000);
begin
   new_str := regexp_replace(str, '[^A-Z|a-z|0-9]', '_');
   return new_str;
end;

function str_random ( -- | This function generates a random string of specified length and type, which can be alphabetic (a), numeric (n), or alphanumeric (an).
   length in number default 33, 
   string_type in varchar2 default 'an') return varchar2 is
   r varchar2(4000);
   x number := 0;
begin
   x := least(str_random.length, 4000);
   case lower(string_type)
      when 'a' then
         r := dbms_random.string('a', x);
      when 'n' then
         while x > 0 loop
            x := x - 1;
            r := r || to_char(round(dbms_random.value(0, 9)));
         end loop;
      when 'an' then
         r := dbms_random.string('x', x);
   end case;
   return r;
end;

procedure assert_str_is_key_str ( -- | This procedure takes a string argument and raises an error if it contains characters other than alphabets (both upper and lower case), digits, underscore, and hyphen.
   str in varchar2) is
begin 
   if not regexp_like(str, '^[a-zA-Z0-9_-]+$') then
      raise_application_error(-20000, 'String contains invalid characters: '||str);
   end if;
end;

function str_hash_md5 ( -- | This function takes a string input and returns its MD5 hash value as a hexadecimal string.
   text varchar2) return varchar2 is 
   r varchar2(1000);
begin
   select dbms_crypto.hash(rawtohex(text), 2) into r from dual;
   return r;
end;

function encrypt_sha256 (text varchar2) -- | Uses dbms_crypto.hash which can't be decrypted but is easier to use.
   return varchar2 deterministic is 
   r varchar2(1000);
begin
   r := dbms_crypto.hash(utl_i18n.string_to_raw(text, 'AL32UTF8'), dbms_crypto.hash_sh256);
   return r;
end;

function encrypt ( -- | Encypts a string using a method that can be decrypted with the arcsql.decrypt function.
   p_text_to_encrypt in varchar2,
   p_encryption_key in varchar2
   ) return raw deterministic is 
begin
   if length(p_encryption_key) < 30 then 
      raise_application_error(-20001, 'Encryption key must be at least 30 characters long.');
   end if;
   return dbms_crypto.encrypt (
      -- Text must be converted to AL32UTF8 and then raw per Oracle docs.
      src=>utl_i18n.string_to_raw(p_text_to_encrypt, 'AL32UTF8'),
      -- aes 256 cbc mode + padding (https://stackoverflow.com/questions/32472691/how-to-use-dbms-crypto-encrypt-function-in-oracle)
      typ=>4356,
      key=>utl_i18n.string_to_raw(p_encryption_key, 'AL32UTF8'));
end;

function decrypt ( -- Used to decrypt strings encyrpted using arcsql.encrypt.
   p_text_to_decrypt in varchar2,
   p_encryption_key in varchar2
   ) return varchar2 deterministic is 
begin
   return utl_raw.cast_to_varchar2(dbms_crypto.decrypt (
      src=>p_text_to_decrypt,
      typ=>4356,
      key=>utl_i18n.string_to_raw(p_encryption_key, 'AL32UTF8')));
end;

function str_to_base64(t in varchar2) return varchar2 is
  -- https://stackoverflow.com/questions/3804279/base64-encoding-and-decoding-in-oracle
begin
   return replace(replace(utl_raw.cast_to_varchar2(utl_encode.base64_encode(utl_raw.cast_to_raw(t))), chr(13)), chr(10));
end;

function str_from_base64(t in varchar2) return varchar2 is
  -- https://stackoverflow.com/questions/3804279/base64-encoding-and-decoding-in-oracle
begin
   return utl_raw.cast_to_varchar2(utl_encode.base64_decode(utl_raw.cast_to_raw(t)));
end;

function str_is_email (text varchar2) return boolean is 
begin 
  -- "Anything more complex will likely return false negatives and run slower."
  -- https://stackoverflow.com/questions/801166/sql-script-to-find-invalid-email-addresses
  if regexp_like (text, '.*@.*\..*') then
      arcsql.debug2('str_is_email: yes: '||text);
      return true;
  else 
      arcsql.debug2('str_is_email: no: '||text);
      return false;
   end if;
end;

function str_count ( -- | Return number of occurrances of a string with another string.
   p_str varchar2, 
   p_char varchar2)
   return number is
   -- Not using regex functions. Don't want to deal with escaping chars like "|".
   /*
   http://www.oracle.com/technology/oramag/code/tips2004/121304.html
   Aui de la Vega, DBA, in Makati, Philippines
   This function provides the number of times a pattern occurs in a string (VARCHAR2).
   */

   c      number;
   next_index   number;
   s       varchar2 (2000);
   p      varchar2 (2000);
begin
   c := 0;
   next_index := 1;
   s := lower (p_str);
   p := lower (p_char);
   for i in 1 .. length (s)
   loop
      if     (length (p) <= length (s) - next_index + 1)
         and (substr (s, next_index, length (p)) = p)
      then
         c := c + 1;
      end if;
      next_index := next_index + 1;
   end loop;
   return c;
end;

function str_only_num (text varchar2) return varchar2 is 
begin 
   return regexp_replace(text, '[^[:digit:]]+', '');
end;

function str_is_date_y_or_n (text varchar2) return varchar2 is
   x date;
begin
   x := to_date(text, 'MM/DD/YYYY');
   return 'Y';
exception
   when others then
      return 'N';
end;

function str_is_number_y_or_n (text varchar2) return varchar2 is
   -- Return true if the provided string evalutes to a number.
   x number;
begin
   x := to_number(text);
   return 'Y';
exception
   when others then
      return 'N';
end;

function str_complexity_check
   -- Return true if the complexity of 'text' meets the provided requirements.
   (text   varchar2,
    chars      integer := null,
    letter     integer := null,
    uppercase  integer := null,
    lowercase  integer := null,
    digit      integer := null,
    special    integer := null) return boolean is
   cnt_letter  integer := 0;
   cnt_upper   integer := 0;
   cnt_lower   integer := 0;
   cnt_digit   integer := 0;
   cnt_special integer := 0;
   delimiter   boolean := false;
   len         integer := nvl (length(text), 0);
   i           integer ;
   ch          char(1 char);
   lang        varchar2(512 byte);
begin
   -- Bug 22730089
   -- Get the current session language and use utl_lms to get the messages.
   -- Under the scenario where the language is not supported ,
   -- only the error code shall be displayed.
   lang := sys_context('userenv','lang');
   -- Classify each character in the text.
   for i in 1..len loop
      ch := substr(text, i, 1);
      if ch = '"' then
         delimiter := true;
         -- Got a delimiter, no need to validate other characters.
         exit;
         -- Observes alphabetic, numeric and special characters.
         -- If a character is neither alphabetic nor numeric,
         -- it is considered special.
      elsif regexp_instr(ch, '[[:alnum:]]') > 0 then
         if regexp_instr(ch, '[[:digit:]]') > 0 then
            cnt_digit := cnt_digit + 1;
         -- Certain characters can be both, numeric and alphabetic,
         -- Such characters will be counted in both categories.
         -- Ex:Roman Numerals('I'(U+2160),'II'(U+2161),'i'(U+2170),'ii'(U+2171))
         end if;
         if regexp_instr(ch, '[[:alpha:]]') > 0 then
            cnt_letter := cnt_letter + 1;
            if regexp_instr(ch, '[[:lower:]]') > 0 then
               cnt_lower := cnt_lower + 1;
            end if;
            -- Certain alphabetic characters can be both upper- or lowercase.
            -- Such characters will be counted in both categories.
            -- Ex:Latin Digraphs and Ligatures ('Nj'(U+01CB), 'Dz'(U+01F2))
            if regexp_instr(ch, '[[:upper:]]') > 0 then
               cnt_upper := cnt_upper + 1;
            end if;
         end if;
      else
         cnt_special := cnt_special + 1;
      end if;
   end loop;
   if delimiter = true then
      return false;
   end if;
   if chars is not null and len < chars then
      return false;
   end if;
   if letter is not null and cnt_letter < letter then
      return false;
   end if;
   if uppercase is not null and cnt_upper < uppercase then
      return false;
   end if;
   if lowercase is not null and cnt_lower < lowercase then
      return false;
   end if;
   if digit is not null and cnt_digit < digit then
      return false;
   end if;
   if special is not null and cnt_special < special then
      return false;
   end if;
   return true;
end;

-- Raise error if value exceeds max len or contains anything but A-z, 0-9, and _(s).
procedure str_raise_complex_value (
   text varchar2, 
   allow_regex varchar2 default null) is 
   m varchar2(120);
   max_len number := 1000;
   s varchar2(1000);
begin 
   if length(text) > max_len then 
      m := 'Value is too long.';
      raise_application_error(-20001, m);
   end if;
   if allow_regex is not null then 
      s := regexp_replace(text, allow_regex);
   else 
      s := text;
   end if;
   m := 'Value contains invalid characters.';
   if regexp_replace(s, '[^0-9A-Za-z_]', '') != s then 
      raise_application_error(-20001, m);
   end if;
end;

-- Raise error if the input string is not defined.
procedure str_raise_not_defined(p_str in varchar2 default null) is 
begin 
   if p_str is null or trim(p_str) is null then 
      raise_application_error(-20001, 'str_raise_not_defined: Required string input is not defined.');
   end if;
end;

function str_remove_text_between (
   p_text in varchar2,
   p_left_char in varchar2,
   p_right_char in varchar2) return varchar2 is 
   -- Removes everything between pairs of characters from a string.
   -- i.e. 'foo [x] bar [y]' becomes 'foo bar'.
   start_pos number;
   end_pos number;
   left_side varchar2(2000);
   right_side varchar2(2000);
   v_text varchar2(2000) := p_text;
begin 
   while instr(v_text, p_left_char) > 0 and instr(v_text, p_right_char) > 0 loop 
      start_pos := instr(v_text, '[');
      end_pos := instr(v_text, ']');
      left_side := rtrim(substr(v_text, 1, start_pos-1));
      right_side := ltrim(substr(v_text, end_pos+1));
      v_text := left_side||' '||right_side;
   end loop;
   return v_text;
end;

-- https://stackoverflow.com/questions/23126455/how-to-call-replace-with-clob-without-exceeding-32k
function clob_replace (
   p_clob                 in clob, 
   p_pattern              in varchar2, 
   p_replacement_string   in clob,
   p_offset               in integer default 1,
   p_occurance_number     in integer default 1) return clob is
   v_clob                       clob;
   v_clob_position              pls_integer;
   v_clob_length                pls_integer;
   v_pattern_length             pls_integer;
   v_replacement_string_length  pls_integer;
begin
   if p_clob is null
      or p_pattern is null
      or p_offset < 1
      or p_offset > dbms_lob.lobmaxsize
      or p_occurance_number < 1
      or p_occurance_number > dbms_lob.lobmaxsize then
         return null;
   end if;

   v_clob_position              := nvl( dbms_lob.instr( p_clob, p_pattern, p_offset, p_occurance_number ), 0 );
   v_clob_length                := dbms_lob.getlength( p_clob );
   v_pattern_length             := length( p_pattern );
   v_replacement_string_length  := nvl( dbms_lob.getlength( p_replacement_string ), 0 );

   dbms_lob.createtemporary( v_clob, false );
   if v_clob_position > 0 then
      if v_clob_position > 1 then
         dbms_lob.copy( v_clob, p_clob, v_clob_position-1, 1, 1 );
      end if;

      if v_replacement_string_length > 0 then
         dbms_lob.append( v_clob, p_replacement_string ); 
      end if;

      if v_clob_position + v_pattern_length <= v_clob_length then
         dbms_lob.copy( v_clob, p_clob, v_clob_length - v_clob_position - v_pattern_length + 1, v_clob_position + v_replacement_string_length, v_clob_position + v_pattern_length );
      end if;
   else
      dbms_lob.append( v_clob, p_clob );
   end if;
   return v_clob;
end; 

function get_token (
   p_list  varchar2,
   p_index number,
   p_sep varchar2 := ',') return varchar2 is 
   -- Return a single member of a list in the form of 'a,b,c'.
   -- Largely taken from https://glosoli.blogspot.com/2006/07/oracle-plsql-function-to-split-strings.html.
   start_pos number;
   end_pos   number;
begin
   if p_index = 1 then
       start_pos := 1;
   else
       start_pos := instr(p_list, p_sep, 1, p_index - 1);
       if start_pos = 0 then
           return null;
       else
           start_pos := start_pos + length(p_sep);
       end if;
   end if;

   end_pos := instr(p_list, p_sep, start_pos, 1);

   if end_pos = 0 then
       return substr(p_list, start_pos);
   else
       return substr(p_list, start_pos, end_pos - start_pos);
   end if;
exception
   when others then
      raise;
end get_token;

function shift_list ( -- | Takes '1,2,3,4' and shifts it to '2,3,4'.
   p_list in varchar2,
   p_token in varchar2 default ',',
   p_shift_count in number default 1,
   p_max_items in number default null) return varchar2 is 
   token_count number;
   v_list varchar2(1000) := trim(p_list);
   v_shift_count number := p_shift_count;
begin 
   if p_list is null or 
      length(trim(p_list)) = 0 then
      return null;
   end if;
   if not p_max_items is null then 
      token_count := str_count(v_list, p_token);
      v_shift_count := (token_count + 1) - p_max_items;
   end if;
   if v_shift_count <= 0 then 
      return trim(v_list);
   end if;
   for i in 1 .. v_shift_count loop 
      token_count := str_count(v_list, p_token);
      if token_count = 0 then 
         return null;
      else 
         v_list := substr(v_list, instr(v_list, p_token)+1);
      end if;
   end loop;
   return trim(v_list);
end;

function str_eval_math ( -- | Evaluate a simple string expression like '2+2-1*2/2.2' and return a numeric value.
   p_expression in varchar2,
   p_decimals in number := 2) return number is 
   test_expression varchar2(120) := p_expression;
   x number;
begin
   test_expression := replace(test_expression, '+', '');
   test_expression := replace(test_expression, '-', '');
   test_expression := replace(test_expression, '*', '');
   test_expression := replace(test_expression, '/', '');
   test_expression := replace(test_expression, '.', '');
   x := to_number(test_expression);
   execute immediate 'select ' || p_expression || ' from dual' into x;
   return round(x, p_decimals);
exception 
   when others then 
      raise_application_error(-20001, 'str_eval_math: Error evaluating expression.');
end;

function str_eval_math_v2 ( -- | Another method for evaluating a string as a math expression.
   p_expression in varchar2,
   p_decimals in number := 2) return number is
   n number;
begin
   -- This works but may require a license for OLAP or need OLAP installed. Avoid if possible.
   -- dbms_aw.eval_text('5+5/10')
   -- Not sure if below avoids a hard parse which version 1 most likely occurs.
   select
     xmlquery(
     replace(p_expression, '/', ' div ')
        returning content
     ).getNumberVal() into n
     from dual;
   return round(n, p_decimals);
end;

/*

### str_last_n_items (function)

Returns last N items in a delimited list.

* **p_list** - Deliminated list of items.
* **p_items** - The last N items to return.

If p_items is zero null is returned. If p_items in larger than the total number of items all items are returned.

*/

function str_last_n_items (
   -- Required
   p_list in varchar2,
   p_items in number,
   p_sep in varchar2 default ',')
   return varchar2 is 
   item_count number;
   start_position number;
begin
   if p_items = 0 then
      return null;
   end if;
   item_count := nvl(regexp_count(p_list, p_sep)+1, 0);
   if item_count > p_items then
      start_position := regexp_instr(p_list, '['||p_sep||']+', 1, item_count-p_items);
   else
      start_position := 0;
   end if;
   return trim(substr(p_list, start_position+1));
end;

function str_avg_list (
   p_list in varchar2,
   p_sep in varchar2 default ',')
   return number is 
   n number;
begin
   select avg(to_number(token)) into n from table(to_rows(p_list=>p_list, p_sep=>p_sep));
   return n;
end;

function str_max_list (
   p_list in varchar2,
   p_sep in varchar2 default ',') 
   return number is 
   n number;
begin
   select max(to_number(token)) into n from table(to_rows(p_list=>p_list, p_sep=>p_sep));
   return n;
end;

function str_sum_list (
   p_list in varchar2,
   p_sep in varchar2 default ',')
   return number is 
   n number;
begin
   select sum(to_number(token)) into n from table(to_rows(p_list=>p_list, p_sep=>p_sep));
   return n;
end;

-- | -----------------------------------------------------------------------------------
-- | Numbers 
-- | -----------------------------------------------------------------------------------

function num_get_variance_pct (
      p_val number,
      p_pct_chance number,
      p_change_low_pct number,
      p_change_high_pct number,
      p_decimals number default 0) return number is 
   p_new_val number;
begin
   arcsql.debug2('num_get_variance_pct: '||p_val||','||p_pct_chance||','||p_change_low_pct||','||p_change_high_pct||','||p_decimals);
   if dbms_random.value(1,100) <= p_pct_chance then 
      p_new_val := p_val + round(p_val * dbms_random.value(p_change_low_pct, p_change_high_pct)/100, p_decimals);
      return round(p_new_val, p_decimals);
   else 
      return p_val;
   end if;
end;

function num_get_variance (
      p_val number,
      p_pct_chance number,
      p_change_low number,
      p_change_high number,
      p_decimals number default 0) return number is 
   p_new_val number;
begin
   arcsql.debug2('num_get_variance: '||p_val||','||p_pct_chance||','||p_change_low||','||p_change_high||','||p_decimals);
   if dbms_random.value(1,100) > p_pct_chance then 
      return p_val;
   end if;
   p_new_val := p_val + round(dbms_random.value(p_change_low, p_change_high), p_decimals);
   return round(p_new_val, p_decimals);
end;

function num_random_gauss(
   p_mean number:=0, 
   p_dev number:=1, 
   p_min number:=null, 
   p_max number:=null) return number is 
  -- Example:
  -- select round(arcsql.num_random_gauss(4, 4, .5, 14)) g from dual connect by level<=100;
  -- Taken from Oracle-L list. Author Sayan Malakshinov (http://orasql.org/).
   res number;
   function gauss return number as
   begin
     return dbms_random.normal()*p_dev + p_mean;
   end;
begin
    res := gauss();
    while not res between p_min and p_max loop
        res := gauss();
    end loop;
    return res;
end;

-- | -----------------------------------------------------------------------------------
-- | Utilties 
-- | -----------------------------------------------------------------------------------

function is_truthy (p_val in varchar2) return boolean is 
begin
   debug2('is_truthy: '||p_val);
   if lower(p_val) in ('y','yes', '1', 'true') then
      arcsql.debug2('is_truthy: true');
      return true;
   elsif instr(p_val, ' ') > 0 then 
      if cron_match(p_val) then 
         arcsql.debug2('is_truthy: true');
         return true;
      end if;
   end if;
   debug2('is_truthy: false');
   return false;
end;

function is_truthy_y (p_val in varchar2) return varchar2 is 
begin 
   if is_truthy(p_val) then 
      return 'y';
   else 
      return 'n';
   end if;
end;

procedure backup_table (sourceTable varchar2, newTable varchar2, dropTable boolean := false) is
begin
   if dropTable then
      drop_table(newTable);
   end if;
   execute immediate 'create table '||newTable||' as (select * from '||sourceTable||')';
end;

procedure connect_external_file_as_table (directoryName varchar2, fileName varchar2, tableName varchar2) is
begin
   if does_table_exist(tableName) then
      execute immediate 'drop table '||tableName;
   end if;
   execute immediate '
   create table '||tableName||' (
   text varchar2(1000))
   organization external (
   type oracle_loader
   default directory '||directoryName||'
   access parameters (
   records delimited by newline
   nobadfile
   nodiscardfile
   nologfile
   fields terminated by ''0x0A''
   missing field values are null
   )
   location('''||fileName||''')
   )
   reject limit unlimited';
end;   

procedure write_to_file (directoryName in varchar2, fileName in varchar2, text in varchar2) is
   file_handle utl_file.file_type;
begin
   file_handle := utl_file.fopen(directoryName,fileName, 'A', 32767);
   utl_file.put_line(file_handle, text, true);
   utl_file.fclose(file_handle);
end;

procedure log_alert_log (text in varchar2) is
   -- Disabled for now since it does not work in autonomous cloud database.
   x number;
   begin
--    select count(*) into x from dba_users where user_name='C##CLOUD_OPS';
--    $if x = 1 then
--       sys.dbms_system.ksdwrt(2, text);
--       sys.dbms_system.ksdfls;
--    $else
      x := 0;
   -- $end
end;

function get_audsid return number is 
-- Returns a unique value which can be used to identify the calling session.
begin
   return SYS_CONTEXT('USERENV','sessionid');
end;

function get_days_since_pass_change (username varchar2) return number is 
   n number;
begin
   select round(trunc(sysdate)-trunc(nvl(password_change_date, created)))  
     into n
     from dba_users
    where username=upper(get_days_since_pass_change.username);
   return n;
end;

-- | -----------------------------------------------------------------------------------
-- | Key value storage/lookup 
-- | -----------------------------------------------------------------------------------

procedure cache (
   cache_key varchar2, 
   p_value varchar2) is
   l_value varchar2(4000);
begin

   if not does_cache_key_exist(cache_key) then
      insert into arcsql_cache (key) values (cache_key);
   end if;

   if length(p_value) > 4000 then
      l_value := substr(p_value, 1, 4000);
   end if;

   update arcsql_cache 
      set value=p_value,
          update_time=sysdate
    where key=lower(cache_key);
end;

procedure cache_date (
   cache_key varchar2, 
   p_date date) is
   l_value varchar2(4000);
begin

   if not does_cache_key_exist(cache_key) then
      insert into arcsql_cache (key) values (cache_key);
   end if;

   update arcsql_cache 
      set date_value=p_date,
          update_time=sysdate
    where key=lower(cache_key);

end;

procedure cache_num (
   cache_key varchar2, 
   p_num number) is
begin

   if not does_cache_key_exist(cache_key) then
      insert into arcsql_cache (key) values (cache_key);
   end if;

   update arcsql_cache 
      set num_value=p_num,
          update_time=sysdate
    where key=lower(cache_key);

end;

function get_cache (cache_key in varchar2) return varchar2 is 
   r varchar2(4000);
begin
   if does_cache_key_exist(cache_key) then 
      select value into r from arcsql_cache where key=lower(cache_key);
   else 
      r := null; 
   end if;
   return r;
end;

function get_cache_date (cache_key varchar2) return date is 
   r date;
begin 
   if does_cache_key_exist(cache_key) then 
      select date_value into r from arcsql_cache where key=lower(cache_key);
      return r;
   else 
      return null;
   end if;
end;

function get_cache_num (cache_key varchar2) return number is 
   r number;
begin 
   if does_cache_key_exist(cache_key) then 
      select num_value into r from arcsql_cache where key=lower(cache_key);
      return r;
   else 
      return null;
   end if;
end;

function does_cache_key_exist (cache_key varchar2) return boolean is
   n number;
begin
   select count(*) into n
     from arcsql_cache
    where key=lower(cache_key);
   if n = 0 then
      return false;
   else
      return true;
   end if;
end;

procedure delete_cache_key (
   cache_key        varchar2) is
begin
   delete from arcsql_cache
    where key=lower(cache_key);
end;

-- | -----------------------------------------------------------------------------------
-- | Dynamic config 
-- | -----------------------------------------------------------------------------------

-- Return config value. Checks table, user settings, then default settings.
function get_setting(setting_name varchar2) return varchar2 deterministic is 
   v varchar2(1000) := null;
   x varchar2(1000) := null;
   s varchar2(1000);
   v_setting_name varchar2(120) := lower(setting_name);
begin 
   log('get_setting: name='||setting_name);
   str_raise_complex_value(v_setting_name);
   v := trim(get_config(v_setting_name));
   if not v is null then 
      return v;
   end if;
   s := 'begin :x := arcsql_default_setting.'||setting_name||'; end;';
   begin 
      execute immediate s using out v;
      if not trim(v) is null then 
         return trim(v);
      end if;
   exception
      when others then 
         null;
   end;
   -- Raise an error if nothing found.
   raise_application_error(-20001,'get_setting: '||setting_name||' not found.');
end;

procedure remove_config (name varchar2) is
begin
   delete from arcsql_config where name=remove_config.name;
end;

procedure add_config (name varchar2, value varchar2, description varchar2 default null) is
begin
   -- DO NOT MODIFY IF EXISTS! Update to self.
   update arcsql_config set value=value where name=lower(add_config.name);
   -- If nothing happened we need to add it.
   if sql%rowcount = 0 then
      insert into arcsql_config (name, value, description)
        values (lower(add_config.name), add_config.value, description);
   end if;
end;

procedure set_config (name varchar2, value varchar2) is
begin
   update arcsql_config set value=set_config.value where name=lower(set_config.name);
   if sql%rowcount = 0 then
      add_config(set_config.name, set_config.value);
   end if;
end;

-- Return value from config table.
function get_config (name varchar2) return varchar2 is
   config_value varchar2(1000);
begin
   select value into config_value from arcsql_config where name=lower(get_config.name);
   return config_value;
exception
   when no_data_found then
      return null;
end;

-- | -----------------------------------------------------------------------------------
-- | SQL monitoring/history 
-- | -----------------------------------------------------------------------------------

function get_sql_log_analyze_min_secs return number is
begin  
   return to_number(nvl(arcsql_cfg.sql_log_analyze_min_secs, 1));
end;

function sql_log_age_of_plan_in_days (
    datetime date,
    plan_hash_value number) return number is
    days_ago number;
begin
    select nvl(round(sysdate-min(datetime), 2), 0)
      into days_ago
      from sql_log
     where plan_hash_value = sql_log_age_of_plan_in_days.plan_hash_value
       and datetime < trunc(sql_log_age_of_plan_in_days.datetime, 'HH24')
       and datetime >= trunc(sql_log_age_of_plan_in_days.datetime-90, 'HH24');
    return days_ago;
end;

function sql_log_count_of_faster_plans (
    datetime               date,
    elap_secs_per_exe      number,
    sql_log_id             number,
    plan_hash_value        number,
    sqlid                  varchar2,
    forcematchingsignature number)
    return number is
    r number;
begin
   if forcematchingsignature > 0 then
      select count(*)
        into r
        from sql_log
       where datetime < trunc(sql_log_count_of_faster_plans.datetime, 'HH24')
         and datetime >= trunc(sql_log_count_of_faster_plans.datetime-90, 'HH24')
         and sql_log_id != sql_log_count_of_faster_plans.sql_log_id
         and plan_hash_value != sql_log_count_of_faster_plans.plan_hash_value
         and decode(executions, 0, 0, elapsed_seconds/executions) <= sql_log_count_of_faster_plans.elap_secs_per_exe*.8
         and sql_id = sqlid
         and force_matching_signature = forcematchingsignature;
   else
      select count(*)
        into r
        from sql_log
       where datetime < trunc(sql_log_count_of_faster_plans.datetime, 'HH24')
         and datetime >= trunc(sql_log_count_of_faster_plans.datetime-90, 'HH24')
         and sql_log_id != sql_log_count_of_faster_plans.sql_log_id
         and plan_hash_value != sql_log_count_of_faster_plans.plan_hash_value
         and decode(executions, 0, 0, elapsed_seconds/executions) <= sql_log_count_of_faster_plans.elap_secs_per_exe*.8
         and sql_id = sqlid;
   end if;
   return r;
end;

function sql_log_count_of_slower_plans (
    datetime               date,
    elap_secs_per_exe      number,
    sql_log_id             number,
    plan_hash_value        number,
    sqlid                  varchar2,
    forcematchingsignature number)
    return number is
    r number;
begin
   if forcematchingsignature > 0 then
      select count(*)
        into r
        from sql_log
       where datetime < trunc(sql_log_count_of_slower_plans.datetime, 'HH24')
         and datetime >= trunc(sql_log_count_of_slower_plans.datetime-90, 'HH24')
         and sql_log_id != sql_log_count_of_slower_plans.sql_log_id
         and plan_hash_value != sql_log_count_of_slower_plans.plan_hash_value
         and decode(executions, 0, 0, elapsed_seconds/executions) >= sql_log_count_of_slower_plans.elap_secs_per_exe*1.2
         and sql_id = sqlid
         and force_matching_signature = forcematchingsignature;
   else
      select count(*)
        into r
        from sql_log
       where datetime < trunc(sql_log_count_of_slower_plans.datetime, 'HH24')
         and datetime >= trunc(sql_log_count_of_slower_plans.datetime-90, 'HH24')
         and sql_log_id != sql_log_count_of_slower_plans.sql_log_id
         and plan_hash_value != sql_log_count_of_slower_plans.plan_hash_value
         and decode(executions, 0, 0, elapsed_seconds/executions) >= sql_log_count_of_slower_plans.elap_secs_per_exe*1.2
         and sql_id = sqlid;
   end if;
   return r;
end;

function sql_log_hours_since_last_exe (sqlid varchar2, forcematchingsignature number) return number is 
   hours_ago number := 0;
   d date;
begin
   select nvl(max(datetime), trunc(sysdate, 'HH24')) into d from sql_log 
    where sql_id=sqlid 
      and force_matching_signature=forcematchingsignature 
      and datetime < trunc(sysdate, 'HH24');
   hours_ago := round((trunc(sysdate, 'HH24')-d)*24, 1);
   return hours_ago;
end;

function sql_log_age_of_sql_in_days (datetime date, sqlid varchar2, forcematchingsignature number) return number is
   days_ago number;
begin
   if forcematchingsignature > 0 then
       select nvl(round(sysdate-min(datetime), 2), 0)
         into days_ago
         from sql_log
        where datetime < trunc(sql_log_age_of_sql_in_days.datetime, 'HH24')
          -- ToDo: Need parameters here, 90 days might not be enough. Trying to limit the amount of data we look at.
          -- ToDo: Some of this meta could be calculated in batch one a day.
          and datetime >= trunc(sql_log_age_of_sql_in_days.datetime-90, 'HH24')
          and sql_id=sqlid
          and force_matching_signature=forcematchingsignature;
    else
       select nvl(round(sysdate-min(datetime), 2), 0)
         into days_ago
         from sql_log
        where datetime < trunc(sql_log_age_of_sql_in_days.datetime, 'HH24')
          and datetime >= trunc(sql_log_age_of_sql_in_days.datetime-90, 'HH24')
          and sql_id=sqlid;
    end if;
    return days_ago;
end;

function sql_log_sql_last_seen_in_days (datetime date, sqlid varchar2, forcematchingsignature number) return number is
   days_ago number;
begin
   if forcematchingsignature > 0 then
       select nvl(round(sysdate-max(datetime), 2), 0)
         into days_ago
         from sql_log
        where sql_id=sqlid
          and force_matching_signature=forcematchingsignature
          and datetime < trunc(sql_log_sql_last_seen_in_days.datetime, 'HH24')
          -- ToDo: Add parameter.
          and datetime >= trunc(sql_log_sql_last_seen_in_days.datetime-90, 'HH24');
    else
       select nvl(round(sysdate-max(datetime), 2), 0)
         into days_ago
         from sql_log
        where sql_id=sqlid
          and datetime < trunc(sql_log_sql_last_seen_in_days.datetime, 'HH24')
          and datetime >= trunc(sql_log_sql_last_seen_in_days.datetime-90, 'HH24');
    end if;
    return nvl(days_ago, 0);
end;

function sql_log_elap_secs_all_sql (datetime date) return number is
   total_secs number;
begin
   select sum(elapsed_seconds)
     into total_secs
     from sql_log
    where datetime >= trunc(sql_log_elap_secs_all_sql.datetime, 'HH24')
      and datetime < trunc(sql_log_elap_secs_all_sql.datetime+(1/24), 'HH24');
   return total_secs;
end;

function sql_log_norm_elap_secs_per_exe (
    datetime               date,
    sqlid                  varchar2,
    forcematchingsignature number
    ) return number is
   n number;
   r number;
begin
   if forcematchingsignature > 0 then
       select decode(sum(executions), 0, 0, sum(elapsed_seconds)/sum(executions)),
              count(*)
         into r,
              n
         from sql_log
        where sql_id=sqlid
          and force_matching_signature=forcematchingsignature
          and datetime >= trunc(sql_log_norm_elap_secs_per_exe.datetime-90);
        -- If less than 30 samples remove sql_id and just use force_matching_signature.
        if n < 30 then
           select decode(sum(executions), 0, 0, sum(elapsed_seconds)/sum(executions)),
                  count(*)
             into r,
                  n
             from sql_log
            where force_matching_signature=forcematchingsignature
              and datetime >= trunc(sql_log_norm_elap_secs_per_exe.datetime-90);
        end if;
    else
       select decode(sum(executions), 0, 0, sum(elapsed_seconds)/sum(executions)),
              count(*)
         into r,
              n
         from sql_log
        where sql_id=sqlid
          and datetime >= trunc(sql_log_norm_elap_secs_per_exe.datetime-90);
    end if;
    return r;
end;

function sql_log_norm_execs_per_hour (datetime date, sqlid varchar2, forcematchingsignature number) return number is
   -- Returns the number of average executions per hour for hours in which a SQL executes.
   record_count number;
   avg_executions number;
begin
   if forcematchingsignature > 0 then
      -- Try to match on SQL ID and SIGNATURE.
      select avg(executions), count(*)
        into avg_executions, record_count
        from sql_log
       where sql_id=sqlid
         and force_matching_signature=forcematchingsignature
         and datetime >= trunc(sql_log_norm_execs_per_hour.datetime-90);
      -- If less than 30 samples try again on SIGNATURE only.
      if record_count < 30 then
         select avg(executions)
           into avg_executions
           from sql_log
          where force_matching_signature=forcematchingsignature
            and datetime >= trunc(sql_log_norm_execs_per_hour.datetime-90);
      end if;
   else
      -- SIGNATURE NOT THERE, USE SQL ID ONLY
      select avg(executions)
        into avg_executions
        from sql_log
       where sql_id=sqlid
         and datetime >= trunc(sysdate-90);
   end if;
   return avg_executions;
end;

function sql_log_norm_io_wait_secs (datetime date, sqlid varchar2, forcematchingsignature number) return number is
   -- Returns the number of average io wait per hour for hours in which a SQL executes.
   record_count number;
   avg_user_io_wait_secs number;
begin
   if forcematchingsignature > 0 then
      -- Try to match on SQL ID and SIGNATURE.
      select avg(user_io_wait_secs), count(*)
        into avg_user_io_wait_secs, record_count
        from sql_log
       where sql_id=sqlid
         and force_matching_signature=forcematchingsignature
         and datetime >= trunc(sql_log_norm_io_wait_secs.datetime-90);
      -- If less than 30 samples try again on SIGNATURE only.
      if record_count < 30 then
         select avg(user_io_wait_secs)
           into avg_user_io_wait_secs
           from sql_log
          where force_matching_signature=forcematchingsignature
            and datetime >= trunc(sql_log_norm_io_wait_secs.datetime-90);
      end if;
   else
      -- SIGNATURE NOT THERE, USE SQL ID ONLY
      select avg(user_io_wait_secs)
        into avg_user_io_wait_secs
        from sql_log
       where sql_id=sqlid
         and datetime >= trunc(sysdate-90);
   end if;
   return avg_user_io_wait_secs;
end;

function sql_log_norm_rows_processed (datetime date, sqlid varchar2, forcematchingsignature number) return number is
   -- Returns the number of average rows processed for this SQL per hour.
   record_count number;
   avg_rows_processed number;
begin
   if forcematchingsignature > 0 then
      -- Try to match on SQL ID and SIGNATURE.
      select avg(rows_processed), count(*)
        into avg_rows_processed, record_count
        from sql_log
       where sql_id=sqlid
         and force_matching_signature=forcematchingsignature
         and datetime >= trunc(sql_log_norm_rows_processed.datetime-90);
      -- If less than 30 samples try again on SIGNATURE only.
      if record_count < 30 then
         select avg(rows_processed)
           into avg_rows_processed
           from sql_log
          where force_matching_signature=forcematchingsignature
            and datetime >= trunc(sql_log_norm_rows_processed.datetime-90);
      end if;
   else
      -- SIGNATURE NOT THERE, USE SQL ID ONLY
      select avg(rows_processed)
        into avg_rows_processed
        from sql_log
       where sql_id=sqlid
         and datetime >= trunc(sysdate-90);
   end if;
   return avg_rows_processed;
end;


procedure sql_log_take_snapshot is
   -- Takes a snapshot of the records returned by sql_snap_view.
   -- Rows are simply inserted into sql_snap. These rows can 
   -- later be compared back to the current values in the view.
   n number;
begin
   n := arcsql_cfg.sql_log_sql_text_length;
   insert into sql_snap (
      sql_id,
      insert_datetime,
      sql_text,
      executions,
      plan_hash_value,
      elapsed_time,
      force_matching_signature,
      user_io_wait_time,
      rows_processed,
      cpu_time,
      service,
      module,
      action) (select sql_id,
      sysdate,
      substr(sql_text, 1, n),
      executions,
      plan_hash_value,
      elapsed_time,
      force_matching_signature,
      user_io_wait_time,
      rows_processed,
      cpu_time,
      service,
      module,
      action
     from sql_snap_view);
end;

procedure sql_log_save_active_sess_hist is
   -- Pulls more data from gv$active_session_history into our table active_sql_hist if licensed.
   min_elap_secs number;
begin
   min_elap_secs := get_sql_log_analyze_min_secs;
   -- This is only allowed if you have the license to look at these tables.
   if upper(nvl(arcsql_cfg.sql_log_ash_is_licensed, 'N')) = 'Y' then

      if nvl(arcsql.get_cache('sql_log_last_active_sql_hist_update'), 'x') != to_char(sysdate, 'YYYYMMDDHH24') then

         arcsql.cache('sql_log_last_active_sql_hist_update', to_char(sysdate, 'YYYYMMDDHH24'));

         insert into sql_log_active_session_history (
         datetime,
         sql_id,
         sql_text,
         on_cpu,
         in_wait,
         modprg,
         actcli,
         exes,
         elapsed_seconds)
         (
          select trunc(sample_time, 'HH24') sample_time, 
                 a.sql_id,
                 b.sql_text,
                 sum(decode(session_state, 'ON CPU' , 1, 0)) on_cpu,
                 sum(decode(session_state, 'ON CPU' , 0, 1)) in_wait,
                 translate(nvl(module, program), '0123456789', '----------') modprg,
                 translate(nvl(action, client_id), '0123456789', '----------') actcli, 
                 max(sql_exec_id)-min(sql_exec_id)+1 exes,
                 count(*) elapsed_seconds
            from gv$active_session_history a,
                 (select sql_id, sql_text from sql_log 
                   where datetime >= trunc(sysdate-(1/24), 'HH24') 
                     and datetime < trunc(sysdate, 'HH24') 
                     and elapsed_seconds >= min_elap_secs
                   group 
                      by sql_id, sql_text) b
           where a.sql_id=b.sql_id
             and sample_time >= trunc(sysdate-(1/24), 'HH24') 
             and sample_time < trunc(sysdate, 'HH24') 
             and (a.sql_id, a.sql_plan_hash_value) in (
              select sql_id, plan_hash_value from sql_log
               where datetime >= trunc(sysdate-(1/24), 'HH24') 
                 and datetime < trunc(sysdate, 'HH24') 
                 and elapsed_seconds >= min_elap_secs)
           group
              by trunc(sample_time, 'HH24'), 
                 a.sql_id,
                 b.sql_text,
                 translate(nvl(module, program), '0123456789', '----------'),
                 translate(nvl(action, client_id), '0123456789', '----------'));
      end if;
   end if;
end;

procedure sql_log_analyze_window (datetime date default sysdate) is

   cursor c_sql_log (min_elap_secs number) is
   select a.*
     from sql_log a
    where datetime >= trunc(sql_log_analyze_window.datetime, 'HH24')
      and datetime < trunc(sql_log_analyze_window.datetime+(1/24), 'HH24')
      and a.elapsed_seconds > min_elap_secs;

   total_elap_secs              number;

begin
   total_elap_secs := sql_log_elap_secs_all_sql(sql_log_analyze_window.datetime);
   -- Loop through each row in SQL_LOG in the result set.
   for s in c_sql_log (get_sql_log_analyze_min_secs) loop

      -- We check for nulls below and only set once per hour. Once set we don't need to do it again.

      -- What is the historical avg elap time per exe in seconds for this SQL?
      if s.norm_elap_secs_per_exe is null then
         s.norm_elap_secs_per_exe := sql_log_norm_elap_secs_per_exe(datetime => sql_log_analyze_window.datetime, sqlid => s.sql_id, forcematchingsignature => s.force_matching_signature);
      end if;

      -- What is the historical avg # of executes per hr for this SQL?
      if s.norm_execs_per_hour is null then
         s.norm_execs_per_hour := sql_log_norm_execs_per_hour(datetime=>sql_log_analyze_window.datetime, sqlid=>s.sql_id, forcematchingsignature=>s.force_matching_signature);
      end if;

      if s.norm_user_io_wait_secs is null then 
         s.norm_user_io_wait_secs := sql_log_norm_io_wait_secs(datetime=>sql_log_analyze_window.datetime, sqlid=>s.sql_id, forcematchingsignature=>s.force_matching_signature);
      end if;

      if s.norm_rows_processed is null then 
         s.norm_rows_processed := sql_log_norm_rows_processed(datetime=>sql_log_analyze_window.datetime, sqlid=>s.sql_id, forcematchingsignature=>s.force_matching_signature);
      end if;

      if s.sql_age_in_days is null then
         s.sql_age_in_days := sql_log_age_of_sql_in_days(datetime=>sql_log_analyze_window.datetime, sqlid=>s.sql_id, forcematchingsignature=>s.force_matching_signature);
      end if;

      if s.hours_since_last_exe is null then 
         s.hours_since_last_exe := sql_log_hours_since_last_exe(sqlid=>s.sql_id, forcematchingsignature=>s.force_matching_signature);
      end if;

      if s.sql_last_seen_in_days is null then
         s.sql_last_seen_in_days := sql_log_sql_last_seen_in_days(datetime=>sql_log_analyze_window.datetime, sqlid=>s.sql_id, forcematchingsignature=>s.force_matching_signature);
      end if;

      if s.plan_age_in_days is null then
         s.plan_age_in_days := sql_log_age_of_plan_in_days(datetime=>sql_log_analyze_window.datetime, plan_hash_value=>s.plan_hash_value);
      end if;

      s.faster_plans := sql_log_count_of_faster_plans(
         datetime=>s.datetime,
         elap_secs_per_exe=>s.elap_secs_per_exe,
         sql_log_id=>s.sql_log_id,
         plan_hash_value=>s.plan_hash_value,
         sqlid=>s.sql_id,
         forcematchingsignature=>s.force_matching_signature);

      s.slower_plans := sql_log_count_of_slower_plans(
         datetime=>s.datetime,
         elap_secs_per_exe=>s.elap_secs_per_exe,
         sql_log_id=>s.sql_log_id,
         plan_hash_value=>s.plan_hash_value,
         sqlid=>s.sql_id,
         forcematchingsignature=>s.force_matching_signature);

      s.elap_secs_per_exe_score := 0;
      if s.norm_elap_secs_per_exe > 0 then
         s.elap_secs_per_exe_score := round(s.elap_secs_per_exe/s.norm_elap_secs_per_exe*100);
      end if;

      update sql_log
         set elap_secs_per_exe_score = s.elap_secs_per_exe_score,
             executions_score = decode(norm_execs_per_hour, 0, 0, round(s.executions/s.norm_execs_per_hour*100)),
             pct_of_elap_secs_for_all_sql = round(decode(total_elap_secs, 0, 0, s.elapsed_seconds/total_elap_secs*100)),
             io_wait_secs_score = round(decode(s.norm_user_io_wait_secs, 0, 0, user_io_wait_secs / s.norm_user_io_wait_secs * 100)),
             sql_age_in_days = s.sql_age_in_days,
             sql_last_seen_in_days = s.sql_last_seen_in_days,
             faster_plans = s.faster_plans,
             slower_plans = s.slower_plans,
             plan_age_in_days = s.plan_age_in_days,
             norm_elap_secs_per_exe = round(s.norm_elap_secs_per_exe, 2),
             norm_execs_per_hour = round(s.norm_execs_per_hour, 2),
             norm_user_io_wait_secs = round(s.norm_user_io_wait_secs, 2),
             norm_rows_processed = round(s.norm_rows_processed),
             hours_since_last_exe = s.hours_since_last_exe
       where sql_log_id = s.sql_log_id;

      update sql_log 
         set sql_log_score = round(((s.elap_secs_per_exe_score/100)+(executions_score/100))*elapsed_seconds),
             sql_log_total_score = nvl(sql_log_total_score, 0) + round(((s.elap_secs_per_exe_score/100)+(executions_score/100))*elapsed_seconds),
             sql_log_score_count = nvl(sql_log_score_count, 0) + 1
       where sql_log_id = s.sql_log_id;

      update sql_log 
         set sql_log_avg_score = decode(sql_log_score_count, 0, 0, round(sql_log_total_score / sql_log_score_count)),
             sql_log_max_score = greatest(nvl(sql_log_max_score, sql_log_score), nvl(sql_log_score, sql_log_max_score)),
             sql_log_min_score = least(nvl(sql_log_min_score, sql_log_score), nvl(sql_log_score, sql_log_min_score))
       where sql_log_id = s.sql_log_id;

   end loop;
end;

procedure sql_log_analyze_sql_log_data (days_back number default 0) is
   cursor times_to_analyze (min_elap_secs number) is
   select distinct trunc(datetime, 'HH24') datetime
     from sql_log
    where elapsed_seconds > min_elap_secs 
      and (elap_secs_per_exe_score is null and datetime >= trunc(sysdate-days_back))
       or datetime >= trunc(sysdate, 'HH24');
begin
   for t in times_to_analyze (get_sql_log_analyze_min_secs) loop
      sql_log_analyze_window(datetime => trunc(t.datetime, 'HH24'));
   end loop;
end;

procedure run_sql_log_update is
   cursor busy_sql is
   -- Matches rows in both sets.
   select a.sql_id,
          a.sql_text,
          a.plan_hash_value,
          a.force_matching_signature,
          b.executions-a.executions executions,
          b.elapsed_time-a.elapsed_time elapsed_time,
          b.user_io_wait_time-a.user_io_wait_time user_io_wait_time,
          b.rows_processed-a.rows_processed rows_processed,
          b.cpu_time-a.cpu_time cpu_time,
          round((sysdate-a.insert_datetime)*24*60*60) secs_between_snaps,
          a.service,
          a.module,
          a.action
     from sql_snap a,
          sql_snap_view b
    where a.sql_id=b.sql_id
      and a.plan_hash_value=b.plan_hash_value
      and a.force_matching_signature=b.force_matching_signature
      -- ToDo: This is one second, need to change to a parameter everywhere.
      and b.elapsed_time-a.elapsed_time >= 1*1000000
      and b.executions-a.executions > 0
   union all
   -- These are new rows which are not in the snapshot.
   select a.sql_id,
          a.sql_text,
          a.plan_hash_value,
          a.force_matching_signature,
          a.executions,
          a.elapsed_time,
          a.user_io_wait_time,
          a.rows_processed,
          a.cpu_time,
          0,
          a.service,
          a.module,
          a.action
     from sql_snap_view a
    where a.elapsed_time >= 1*1000000
      and a.executions > 0
      and not exists (select 'x'
                        from sql_snap b
                       where a.sql_id=b.sql_id
                         and a.plan_hash_value=b.plan_hash_value
                         and a.force_matching_signature=b.force_matching_signature);
   n number;
   last_elap_secs_per_exe  number;
   v_sql_log sql_log%rowtype;
begin
   if is_truthy(app_job.disable_all) or not is_truthy(app_job.enable_sql_log_updates) then 
      return;
   end if;
   start_event(p_event_key=>'arcsql', p_sub_key=>'sql_log', p_name=>'run_sql_log_update');
   select count(*) into n from sql_snap where rownum < 2;
   if n = 0 then
      sql_log_take_snapshot;
   else
      for s in busy_sql loop

         update sql_log set
            executions=executions+s.executions,
            elapsed_seconds=round(elapsed_seconds+s.elapsed_time/1000000, 1),
            cpu_seconds=round(cpu_seconds+s.cpu_time/1000000, 1),
            rows_processed=rows_processed+s.rows_processed,
            user_io_wait_secs=round(user_io_wait_secs+s.user_io_wait_time/1000000, 1),
            update_time=sysdate,
            update_count=update_count+1,
            secs_between_snaps=s.secs_between_snaps,
            elap_secs_per_exe = round((elapsed_seconds+s.elapsed_time/1000000) / (executions+s.executions), 3),
            service = s.service,
            module = s.module,
            action = s.action
          where sql_id=s.sql_id
            and plan_hash_value=s.plan_hash_value
            and force_matching_signature=s.force_matching_signature
            and datetime=trunc(sysdate, 'HH24');

         if sql%rowcount = 0 then

            -- Try to load previous record if it exist.
            select max(datetime) into v_sql_log.datetime 
              from sql_log
             where sql_id=s.sql_id 
               and plan_hash_value=s.plan_hash_value 
               and force_matching_signature=s.force_matching_signature 
               and datetime!=trunc(sysdate, 'HH24');

            if not v_sql_log.datetime  is null then 
               select * into v_sql_log
                 from sql_log 
                where sql_id=s.sql_id 
                  and plan_hash_value=s.plan_hash_value 
                  and force_matching_signature=s.force_matching_signature 
                  and datetime=v_sql_log.datetime;
               v_sql_log.rolling_avg_score := shift_list(
                  p_list=>v_sql_log.rolling_avg_score,
                  p_token=>',',
                  p_max_items=>24) || ',' || to_char(v_sql_log.sql_log_avg_score);
            else 
               v_sql_log.rolling_avg_score := null;
            end if;

            -- This is a new SQL or new hour and we need to insert it.
            insert into sql_log (
               sql_log_id, 
               sql_id, 
               sql_text, 
               plan_hash_value, 
               force_matching_signature, 
               datetime, 
               executions, 
               elapsed_seconds, 
               cpu_seconds, 
               user_io_wait_secs, 
               rows_processed, 
               update_count, 
               update_time, 
               elap_secs_per_exe, 
               secs_between_snaps,
               sql_log_score_count,
               sql_log_total_score,
               sql_log_avg_score,
               rolling_avg_score,
               service,
               module,
               action) values (
               seq_sql_log_id.nextval, 
               s.sql_id, s.sql_text, 
               s.plan_hash_value, 
               s.force_matching_signature, 
               trunc(sysdate, 'HH24'), 
               s.executions, 
               round(s.elapsed_time/1000000, 1), 
               round(s.cpu_time/1000000, 1), 
               round(s.user_io_wait_time/1000000, 1), 
               s.rows_processed, 
               1, sysdate, 
               round(s.elapsed_time/1000000/s.executions, 3), 
               s.secs_between_snaps,
               0,
               0,
               null,
               v_sql_log.rolling_avg_score,
               s.service,
               s.module,
               s.action);

         end if;

         if s.executions = 0 then
            last_elap_secs_per_exe := 0;
         else
            last_elap_secs_per_exe := round(s.elapsed_time/1000000/s.executions, 3);
         end if;

         if last_elap_secs_per_exe < 2 then
            update sql_log set secs_0_1=round(secs_0_1+s.elapsed_time/1000000, 1) where sql_id=s.sql_id and plan_hash_value=s.plan_hash_value and force_matching_signature=s.force_matching_signature and datetime=trunc(sysdate, 'HH24');
         elsif last_elap_secs_per_exe < 6 then
            update sql_log set secs_2_5=round(secs_2_5+s.elapsed_time/1000000, 1) where sql_id=s.sql_id and plan_hash_value=s.plan_hash_value and force_matching_signature=s.force_matching_signature and datetime=trunc(sysdate, 'HH24');
         elsif last_elap_secs_per_exe < 11 then
            update sql_log set secs_6_10=round(secs_6_10+s.elapsed_time/1000000, 1) where sql_id=s.sql_id and plan_hash_value=s.plan_hash_value and force_matching_signature=s.force_matching_signature and datetime=trunc(sysdate, 'HH24');
         elsif last_elap_secs_per_exe < 61 then
            update sql_log set secs_11_60=round(secs_11_60+s.elapsed_time/1000000, 1) where sql_id=s.sql_id and plan_hash_value=s.plan_hash_value and force_matching_signature=s.force_matching_signature and datetime=trunc(sysdate, 'HH24');
         else
            update sql_log set secs_61_plus=round(secs_61_plus+s.elapsed_time/1000000, 1) where sql_id=s.sql_id and plan_hash_value=s.plan_hash_value and force_matching_signature=s.force_matching_signature and datetime=trunc(sysdate, 'HH24');
         end if;
      end loop;
      delete from sql_snap;
      sql_log_take_snapshot;
   end if;

   sql_log_analyze_sql_log_data;
   sql_log_save_active_sess_hist;
   stop_event(p_event_key=>'arcsql', p_sub_key=>'sql_log', p_name=>'run_sql_log_update');
end;

-- | -----------------------------------------------------------------------------------
-- | Counters 
-- | -----------------------------------------------------------------------------------

procedure increment_counter ( -- | Increment a counter by 1. Creates the counter if it does not exist.
   p_counter_id varchar2) is 
begin 
   update arcsql_counter
      set value=value+1
    where counter_id=lower(p_counter_id); 
   if sql%rowcount = 0 then 
      insert into arcsql_counter (
         counter_id,
         value) values (
         lower(p_counter_id),
         1);
   end if;
end;

function get_counter ( --  | Get the value of a counter.
   p_counter_id varchar2) return number is 
   n number;
begin 
   select value into n from arcsql_counter where counter_id=lower(p_counter_id); 
   return n;
end;  

/*
-----------------------------------------------------------------------------------
Request counter user for quickly implementing rate limits.
-----------------------------------------------------------------------------------
*/

procedure count_request (
   p_request_key in varchar2, 
   p_sub_key in varchar2 default null) is 
   -- Increments the count for a request by 1 each time called.
   -- Counts are added to 'current' minute which is sysdate
   -- truncated to 'MI' (minute). Sub key is optional. If you 
   -- use sub key you can check rate by only request key or both
   -- request key and sub key.
begin 
   update arcsql_request_count set requests=requests+1
    where request_key=p_request_key 
      and nvl(sub_key, 'x')=nvl(p_sub_key, 'x')
      and time_window=trunc(sysdate, 'MI');
   if sql%rowcount = 0 then 
      insert into arcsql_request_count (
         request_key,
         sub_key,
         time_window,
         requests) values (
         p_request_key,
         p_sub_key,
         trunc(sysdate, 'MI'),
         1);
   end if;
end;

function get_request_count (
   -- Return the # requests which have occurred within the specified period of time.
   --
   -- Will not include any requests which are still within the current minute.
   -- You can get that by calling get_current_request_count.
   p_request_key in varchar2, 
   p_sub_key in varchar2 default null, 
   p_min in number default 1
   -- How many minutes prior to current time to include in the count.
   ) return number is 
   n number;
begin 
   select nvl(sum(requests), 0) into n 
     from arcsql_request_count
    where request_key=p_request_key
      and nvl(sub_key, 'x')=nvl(p_sub_key, nvl(sub_key, 'x'))
      and time_window < trunc(sysdate, 'MI')
      and time_window >= trunc(sysdate, 'MI')-p_min/1440;
   return n;
end;


function get_current_request_count (
   p_request_key in varchar2, 
   p_sub_key in varchar2 default null) return number is 
   -- See docs for get_request_count. This only returns the requests
   -- that have landed in the current minute. You may want to check
   -- this and get_request_count in the code that implements your 
   -- rate limiter.
   n number;
begin 
   select nvl(sum(requests), 0) into n 
     from arcsql_request_count
    where request_key=p_request_key
      and nvl(sub_key, 'x')=nvl(p_sub_key, nvl(sub_key, 'x'))
      and time_window >= trunc(sysdate, 'MI');
   return n;
end;

-- | -----------------------------------------------------------------------------------
-- | Event tracking 
-- | -----------------------------------------------------------------------------------

procedure purge_events is 
   -- Purge records from audsid_event that are older than 4 hours.
   v_hours number;
begin
   v_hours := get_setting('purge_event_hours');
   delete from audsid_event where start_time < sysdate-v_hours/24;
end;

procedure start_event (
   p_event_key in varchar2, 
   p_sub_key in varchar2, 
   p_name in varchar2) is 
-- Start an event timer (autonomous transaction).
-- event_key: Event group (string). Required.
-- sub_key: Event sub_key (string). Can be null.
-- name: Event name (string). Unique within a event_key/sub_group.
   v_audsid number := get_audsid;
   pragma autonomous_transaction;
begin 
   update audsid_event 
      set start_time=sysdate 
    where audsid=v_audsid
      and event_key=p_event_key
      and nvl(sub_key, 'x')=nvl(p_sub_key, 'x')
      and name=p_name;
   -- ToDo: If 1 we may need to log a "miss".
   if sql%rowcount = 0 then 
      insert into audsid_event (
         audsid,
         event_key,
         sub_key,
         name,
         start_time) values (
         v_audsid,
         p_event_key,
         p_sub_key,
         p_name,
         sysdate
         );
   end if;
   commit;
exception
   when others then
      rollback;
      raise;
end;

procedure stop_event (
   p_event_key in varchar2, 
   p_sub_key in varchar2, 
   p_name in varchar2) is 
-- Stop timing an event.
   v_start_time date;
   v_stop_time date;
   v_elapsed_seconds number;
   v_audsid number := get_audsid;
   pragma autonomous_transaction;
begin 
   -- Figure out the amount of time elapsed.
   begin
      select start_time,
             sysdate stop_time,
             round((sysdate-start_time)*24*60*60, 3) elapsed_seconds
        into v_start_time,
             v_stop_time,
             v_elapsed_seconds
        from audsid_event 
       where audsid=v_audsid
         and event_key=p_event_key
         and nvl(sub_key, 'x')=nvl(p_sub_key, 'x')
         and name=p_name;
   exception
      when no_data_found then 
         -- ToDo: Log the miss, do not raise error as it may break user's code.
         return;
   end;

   -- Delete the reference we use to calc elap time for this event/session.
   delete from audsid_event
    where audsid=v_audsid
      and event_key=p_event_key
      and nvl(sub_key, 'x')=nvl(p_sub_key, 'x')
      and name=p_name;

   -- Update the consolidated record in the arcsql_event table.
   update arcsql_event set 
      event_count=event_count+1,
      total_secs=total_secs+v_elapsed_seconds,
      last_start_time=v_start_time,
      last_end_time=v_stop_time
    where event_key=p_event_key
      and nvl(sub_key, '~')=nvl(p_sub_key, '~')
      and name=p_name;

   if sql%rowcount = 0 then 
      insert into arcsql_event (
         id,
         event_key,
         sub_key,
         name,
         event_count,
         total_secs,
         last_start_time,
         last_end_time) values (
         seq_event_id.nextval,
         p_event_key,
         p_sub_key,
         p_name,
         1,
         v_elapsed_seconds,
         v_start_time,
         v_stop_time
         );
   end if;
   commit;
exception
   when others then
      rollback;
      raise;
end;

procedure delete_event (
   p_event_key in varchar2, 
   p_sub_key in varchar2, 
   p_name in varchar2) is 
-- Delete event data.
   pragma autonomous_transaction;
   v_audsid number := get_audsid;
begin 
   delete from arcsql_event 
    where event_key=p_event_key
      and nvl(sub_key, 'x')=nvl(p_sub_key, 'x')
      and name=p_name;
   commit;
exception
   when others then 
      rollback;
      raise;
end;

-- | -----------------------------------------------------------------------------------
-- | Start/Stop ArcSQL jobs 
-- | -----------------------------------------------------------------------------------

procedure start_arcsql is 
   cursor tasks is 
   select * from user_scheduler_jobs 
    where job_name like 'ARCSQL%';
begin 
   for task in tasks loop 
      debug('start_arcsql: '||task.job_name);
      dbms_scheduler.enable(task.job_name);
   end loop;
   commit;
end;

procedure stop_arcsql is 
   cursor tasks is 
   select * from user_scheduler_jobs 
    where job_name like 'ARCSQL%';
begin 
   for task in tasks loop 
      debug('stop_arcsql: '||task.job_name);
      dbms_scheduler.disable(task.job_name);
   end loop;
   commit;
end;

-- | -----------------------------------------------------------------------------------
-- | Logging/Debug 
-- | -----------------------------------------------------------------------------------

function does_log_type_exist (p_log_type in varchar2) return boolean is 
   n number;
begin 
   select count(*) into n from arcsql_log_type 
    where lower(log_type)=lower(p_log_type);
   if n = 0 then 
      return false;
   else 
      return true;
   end if;
end;

procedure add_log_type (
   p_log_type in varchar2,
   p_sends_email in boolean default false,
   p_sends_sms in boolean default false) is 
   v_sends_email varchar2(1) default 'N';
   v_sends_sms varchar2(1) default 'N';
begin 
   if p_sends_email then 
      v_sends_email := 'Y';
   end if;
   if p_sends_sms then 
      v_sends_sms := 'Y';
   end if;
   if not does_log_type_exist(p_log_type) then 
      insert into arcsql_log_type (
         log_type, 
         sends_email,
         sends_sms) values (
         p_log_type, 
         v_sends_email,
         v_sends_sms);
   end if;
end;

procedure create_default_log_types_for_account is 
begin 
   -- Routes to email and sms
   add_log_type(p_log_type=>'sms', p_sends_email=>true, p_sends_sms=>true);
   -- Routes to email only
   add_log_type(p_log_type=>'email', p_sends_email=>true, p_sends_sms=>false);
   add_log_type(p_log_type=>'warning', p_sends_email=>true, p_sends_sms=>false);
   add_log_type(p_log_type=>'notice', p_sends_email=>true, p_sends_sms=>false);
   add_log_type(p_log_type=>'notify', p_sends_email=>true, p_sends_sms=>false);
   add_log_type(p_log_type=>'error', p_sends_email=>true, p_sends_sms=>false);
   add_log_type(p_log_type=>'audit', p_sends_email=>true, p_sends_sms=>false);
   -- Does not route to email or sms
   add_log_type(p_log_type=>'info', p_sends_email=>false, p_sends_sms=>false);
   add_log_type(p_log_type=>'log',    p_sends_email=>false, p_sends_sms=>false);
   add_log_type(p_log_type=>'debug', p_sends_email=>false, p_sends_sms=>false);
   add_log_type(p_log_type=>'debug2', p_sends_email=>false, p_sends_sms=>false);
   add_log_type(p_log_type=>'debug3', p_sends_email=>false, p_sends_sms=>false);
   add_log_type(p_log_type=>'deprecated', p_sends_email=>false, p_sends_sms=>false);
   add_log_type(p_log_type=>'fail', p_sends_email=>false, p_sends_sms=>false);
   add_log_type(p_log_type=>'pass', p_sends_email=>false, p_sends_sms=>false);
   add_log_type(p_log_type=>'debug_secret', p_sends_email=>false, p_sends_sms=>false);
end;

procedure log_interface (
   p_text in varchar2, 
   p_key in varchar2, 
   p_tags in varchar2,
   p_level in number,
   p_type in varchar2
   ) is 
   pragma autonomous_transaction;
begin
   if not does_log_type_exist(p_type) then 
      -- ToDo: This should probably generate an event that requires an ack.
      insert into arcsql_log_type (
         log_type) values (
         lower(p_type));
   end if;
   if arcsql_cfg.log_level >= p_level  then
      insert into arcsql_log (
      log_text,
      log_type,
      log_key,
      log_tags,
      audsid,
      username,
      process_id) values (
      substr(p_text, 1, 1000),
      lower(p_type),
      substr(p_key, 1, 120),
      substr(p_tags, 1, 120),
      get_audsid,
      user,
      g_process_id);
      commit;
   end if;
   commit;
exception 
   when others then 
      rollback;
      raise;
end;

procedure log (
   p_text in varchar2, 
   p_key in varchar2 default null, 
   p_tags in varchar2 default null,
   log_type in varchar2 default 'log') is 
begin
   log_interface (
      p_text=>p_text, 
      p_key=>p_key, 
      p_tags=>p_tags, 
      p_level=>0, 
      p_type=>log_type);
end;

procedure log_notify (
   p_text in varchar2, 
   p_key in varchar2 default null, 
   p_tags in varchar2 default null) is 
begin
   log_interface (
      p_text=>p_text, 
      p_key=>p_key, 
      p_tags=>p_tags, 
      p_level=>0, 
      p_type=>'notify');
end;

procedure notify (
   p_text in varchar2, 
   p_key in varchar2 default null, 
   p_tags in varchar2 default null) is 
begin
   log_interface (
      p_text=>p_text, 
      p_key=>p_key, 
      p_tags=>p_tags, 
      p_level=>0, 
      p_type=>'notify');
end;

procedure log_deprecated (
   p_text in varchar2, 
   p_key in varchar2 default null, 
   p_tags in varchar2 default null) is 
begin
   log_interface (
      p_text=>p_text, 
      p_key=>p_key, 
      p_tags=>p_tags, 
      p_level=>0, 
      p_type=>'deprecated');
end;

procedure log_audit (
   p_text in varchar2, 
   p_key in varchar2 default null, 
   p_tags in varchar2 default null) is 
begin
   log_interface (
      p_text=>p_text, 
      p_key=>p_key, 
      p_tags=>p_tags, 
      p_level=>0, 
      p_type=>'audit');
end;

procedure log_security_event (
   p_text in varchar2, 
   p_key in varchar2 default null, 
   p_tags in varchar2 default null) is 
begin
   log_interface (
      p_text=>p_text, 
      p_key=>p_key, 
      p_tags=>p_tags, 
      p_level=>0, 
      p_type=>'security');
end;

procedure log_err (
   p_text in varchar2, 
   p_key in varchar2 default null, 
   p_tags in varchar2 default null) is 
begin
   log_interface (
      p_text=>p_text, 
      p_key=>p_key, 
      p_tags=>p_tags, 
      p_level=>-1, 
      p_type=>'error');
end;

procedure debug (
   p_text in varchar2, 
   p_key in varchar2 default null, 
   p_tags in varchar2 default null) is 
begin
   log_interface (
      p_text=>p_text, 
      p_key=>p_key, 
      p_tags=>p_tags, 
      p_level=>1, 
      p_type=>'debug');
end;

procedure debug2 (
   p_text in varchar2, 
   p_key in varchar2 default null, 
   p_tags in varchar2 default null) is 
begin
   log_interface (
      p_text=>p_text, 
      p_key=>p_key, 
      p_tags=>p_tags, 
      p_level=>2, 
      p_type=>'debug2');
end;

procedure debug3 (
   p_text in varchar2, 
   p_key in varchar2 default null, 
   p_tags in varchar2 default null) is 
begin
   log_interface (
      p_text=>p_text, 
      p_key=>p_key, 
      p_tags=>p_tags, 
      p_level=>3, 
      p_type=>'debug3');
end;

procedure log_pass (
   p_text in varchar2, 
   p_key in varchar2 default null, 
   p_tags in varchar2 default null) is 
begin
   log_interface (
      p_text=>p_text, 
      p_key=>p_key, 
      p_tags=>p_tags, 
      p_level=>-1, 
      p_type=>'pass');
end;

procedure log_fail (
   p_text in varchar2, 
   p_key in varchar2 default null, 
   p_tags in varchar2 default null) is 
begin
   log_interface (
      p_text=>p_text, 
      p_key=>p_key, 
      p_tags=>p_tags, 
      p_level=>-1, 
      p_type=>'fail');
end;

procedure log_sms (
   p_text in varchar2, 
   p_key in varchar2 default null, 
   p_tags in varchar2 default null) is 
begin
   log_interface (
      p_text=>p_text, 
      p_key=>p_key, 
      p_tags=>p_tags, 
      p_level=>0, 
      p_type=>'sms');
end;

procedure log_email (
   p_text in varchar2, 
   p_key in varchar2 default null, 
   p_tags in varchar2 default null) is 
begin
   log_interface (
      p_text=>p_text, 
      p_key=>p_key, 
      p_tags=>p_tags, 
      p_level=>0, 
      p_type=>'email');
end;

procedure debug_secret ( -- | Used sparingly to log sensitive data when required. arcsql_cfg.allow_debug_secret must be true.
   p_text in varchar2, 
   p_key in varchar2 default null, 
   p_tags in varchar2 default null) is 
begin
   if arcsql_cfg.allow_debug_secret then
      log_interface (
         p_text=>p_text, 
         p_key=>p_key, 
         p_tags=>p_tags, 
         p_level=>1, 
         p_type=>'secret');
   end if;
end;

-- | -----------------------------------------------------------------------------------
-- | ## Unit testing 
-- | 
-- | Test results are stored in arcsql_log. If you want to see those or evaluate those
-- | then make sure you have ArcSQL logging enabled.
-- | -----------------------------------------------------------------------------------

procedure pass_test is -- | Pass the current test.
begin 
   test_passed := 1;
   test;
end;


procedure fail_test(fail_message in varchar2 default null) is -- | Fail the current test which will result in an error being raised.
begin 
   test_passed := 0;
   test;
end;


procedure test is -- | Closes out a test if pass_test or fail_test has not already been called.
begin
   if test_passed = 1 then 
      dbms_output.put_line('passed: '||arcsql.test_name);
      arcsql.log_pass(arcsql.test_name);
   elsif (test_passed = 0) or (assert_true != true or assert_false != false or assert != true) then
      dbms_output.put_line('failed: '||arcsql.test_name);
      arcsql.log_fail(arcsql.test_name);
      raise_application_error(-20001, 'failed: '||arcsql.test_name);
   else 
      dbms_output.put_line('passed: '||arcsql.test_name);
      arcsql.log_pass(arcsql.test_name);
   end if;
   test_is_running := false;
end;


procedure init_test(test_name varchar2) is -- | Initialize the start of a new test.
begin
   if test_is_running and arcsql.test_name is not null then 
      pass_test;
   end if;
   debug('init_test: '||test_name);
   delete from arcsql_log where process_id=test_name;
   arcsql.g_process_id := 'test: '||test_name;
   test_is_running := true;
   test_passed := -1;
   assert := true;
   assert_true := true;
   assert_false := false;
   arcsql.test_name := init_test.test_name;
end;

-- | -----------------------------------------------------------------------------------
-- | App testing/monitoring
-- | -----------------------------------------------------------------------------------

function app_test_profile_not_set return boolean is 
begin 
   if g_app_test_profile.profile_name is null then 
      return true;
   else 
      return false;
   end if;
end;


procedure add_app_test_profile (
   p_profile_name in varchar2,
   p_env_type in varchar2 default null,
   p_is_default in varchar2 default 'N',
   p_test_interval in number default 0,
   p_recheck_interval in number default 0,
   p_retry_count in number default 0,
   p_retry_interval in number default 0,
   p_retry_log_type in varchar2 default 'retry',
   p_failed_log_type in varchar2 default 'warning',
   p_reminder_interval in number default 60,
   p_reminder_log_type in varchar2 default 'warning',
   -- Interval is multiplied by this # each time a reminder is sent to set the next interval.
   p_reminder_backoff in number default 1,
   p_abandon_interval in varchar2 default null,
   p_abandon_log_type in varchar2 default 'abandon',
   p_abandon_reset in varchar2 default 'N',
   p_pass_log_type in varchar2 default 'passed'
   ) is
begin
   if not does_app_test_profile_exist(p_profile_name, p_env_type) then
      g_app_test_profile := null;
      g_app_test_profile.profile_name := p_profile_name;
      g_app_test_profile.env_type := p_env_type;
      g_app_test_profile.is_default := p_is_default;
      g_app_test_profile.test_interval := p_test_interval;
      g_app_test_profile.recheck_interval := p_recheck_interval;
      g_app_test_profile.retry_count := p_retry_count;
      g_app_test_profile.retry_interval := p_retry_interval;
      g_app_test_profile.retry_log_type := p_retry_log_type;
      g_app_test_profile.failed_log_type := p_failed_log_type;
      g_app_test_profile.reminder_interval := p_reminder_interval;
      g_app_test_profile.reminder_log_type := p_reminder_log_type;
      g_app_test_profile.reminder_backoff := p_reminder_backoff;
      g_app_test_profile.abandon_interval := p_abandon_interval;
      g_app_test_profile.abandon_log_type := p_abandon_log_type;
      g_app_test_profile.abandon_reset := p_abandon_reset;
      g_app_test_profile.pass_log_type := p_pass_log_type;
      save_app_test_profile;
   end if;
end;


procedure set_app_test_profile (
   p_profile_name in varchar2 default null,
   p_env_type in varchar2 default null) is 
   -- Set g_app_test_profile. If env type not found try where env type is null.
   n number;

   function set_exact_app_profile return boolean is 
   -- Match profile name and env type (could be null).
   begin 
      select * into g_app_test_profile 
        from app_test_profile 
       where profile_name=p_profile_name 
         and nvl(env_type, 'x')=nvl(p_env_type, 'x');
      return true;
   exception 
      when others then 
         return false;
   end;

   function set_default_app_profile return boolean is 
   -- Match default profile if configured.
   begin 
      select * into g_app_test_profile 
        from app_test_profile 
       where is_default='Y'
         and 'x'=nvl(p_profile_name, 'x')
         and 'x'=nvl(p_env_type, 'x');
      return true;
   exception 
      when others then 
         return false;
   end;

begin 
   if set_exact_app_profile then 
      return;
   end if;
   if set_default_app_profile then 
      return;
   end if;
   raise_application_error('-20001', 'Matching app profile not found.');
end;


procedure raise_app_test_profile_not_set is 
begin 
   if app_test_profile_not_set then 
      raise_application_error('-20001', 'Application test profile not set.');
   end if;
end;


procedure save_app_test_profile is 
  pragma autonomous_transaction;
begin  
   raise_app_test_profile_not_set;

   -- Each env type can only have one default profile associated with it.
   if g_app_test_profile.is_default='Y' then 
      update app_test_profile set is_default='N'
       where is_default='Y' 
         and nvl(env_type, 'x')=nvl(g_app_test_profile.env_type, 'x');
   end if;

   update app_test_profile set row=g_app_test_profile 
    where profile_name=g_app_test_profile.profile_name
      and nvl(env_type, 'x')=nvl(g_app_test_profile.env_type, 'x');

   if sql%rowcount = 0 then 
      insert into app_test_profile values g_app_test_profile;
   end if;

   commit;
exception 
   when others then 
      rollback;
      raise;
end;


function does_app_test_profile_exist (
   p_profile_name in varchar2,
   p_env_type in varchar2 default null) return boolean is 
   n number;
begin 
   select count(*) into n 
     from app_test_profile 
    where profile_name=p_profile_name
      and nvl(env_type, 'x')=nvl(p_env_type, 'x');
   if n > 0 then 
      return true;
   else 
      return false;
   end if;
end;


procedure set_default_app_test_profile is 
   n number;
begin 
   -- Try to set default by calling set with no parms.
   set_app_test_profile;
end;

procedure raise_app_test_not_set is 
begin
   if g_app_test.test_name is null then 
      raise_application_error('-20001', 'Application test not set.');
   end if;
end;


function init_app_test (p_test_name varchar2) return boolean is
   -- Returns true if the test is enabled and it is time to run the test.
   --
   pragma autonomous_transaction;
   n number;
   time_to_test boolean := false;

   function test_interval return boolean is 
   begin
      if nvl(g_app_test.test_end_time, sysdate-999) + g_app_test_profile.test_interval/1440 <= sysdate then 
         return true;
      else 
         return false;
      end if;
   end;

   function retry_interval return boolean is 
   begin 
      if g_app_test.test_end_time + g_app_test_profile.retry_interval/1440 <= sysdate then
         return true;
      else
         return false;
      end if;
   end;

   function recheck_interval return boolean is 
   begin 
      if nvl(g_app_test_profile.recheck_interval, -1) > -1 then 
         if g_app_test.test_end_time + g_app_test_profile.recheck_interval/1440 <= sysdate then 
            return true;
         end if;
      end if;
      return false;
   end;

begin
   if app_test_profile_not_set then 
      set_default_app_test_profile;
   end if;
   raise_app_test_profile_not_set;
   select count(*) into n from app_test 
    where test_name=p_test_name;
   if n = 0 then 
      insert into app_test (
         test_name,
         test_start_time,
         test_end_time,
         reminder_interval) values (
         p_test_name,
         sysdate,
         null,
         g_app_test_profile.reminder_interval);
      commit;
      time_to_test := true;
   end if;
   select * into g_app_test from app_test where test_name=p_test_name;
   if g_app_test.enabled='N' then 
      return false;
   end if;
   if not g_app_test.test_start_time is null and 
      g_app_test.test_end_time is null then 
      -- ToDo: Log an error here but do not throw an error.
      null;
   end if;
   if g_app_test.test_status in ('RETRY') and retry_interval then 
      if not g_app_test_profile.retry_log_type is null then
         arcsql.log(
            p_text=>'['||g_app_test_profile.retry_log_type||'] Application test '''||g_app_test.test_name||''' is being retried.',
            p_key=>'app_test');
      end if;
      time_to_test := true;
   end if;
   if g_app_test.test_status in ('FAIL', 'ABANDON') and (recheck_interval or test_interval) then 
      time_to_test := true;
   end if;
   if g_app_test.test_status in ('PASS') and test_interval then 
      time_to_test := true;
   end if;
   if time_to_test then 
      debug2('time_to_test=true');
      g_app_test.test_start_time := sysdate;
      g_app_test.test_end_time := null;
      g_app_test.total_test_count := g_app_test.total_test_count + 1;
      save_app_test;
      return true;
   else 
      debug2('time_to_test=false');
      return false;
   end if;
exception 
   when others then 
      rollback;
      raise;
end;


procedure reset_app_test_profile is 
begin 
   raise_app_test_profile_not_set;
   set_app_test_profile(
     p_profile_name=>g_app_test_profile.profile_name,
     p_env_type=>g_app_test_profile.env_type);
end;


procedure app_test_check is 
   -- Sends reminders and changes status to ABANDON when test status is currently FAIL.
   --

   function abandon_interval return boolean is 
   -- Returns true if it is time to abandon this test.
   begin 
      if nvl(g_app_test_profile.abandon_interval, 0) > 0 then 
         if g_app_test.failed_time + g_app_test_profile.abandon_interval/1440 <= sysdate then 
            return true;
         end if;
      end if;
      return false;
   end;

   procedure abandon_test is 
   -- Performs necessary actions when test status changes to 'ABANDON'.
   begin 
      g_app_test.abandon_time := sysdate;
      g_app_test.total_abandons := g_app_test.total_abandons + 1;
      if not g_app_test_profile.abandon_log_type is null then 
         arcsql.log(
            p_text=>'['||g_app_test_profile.abandon_log_type||'] Application test '''||g_app_test.test_name||''' is being abandoned after '||g_app_test_profile.abandon_interval||' minutes.',
            p_key=>'app_test');
      end if;
      -- If reset is Y the test changes back to PASS and will likely FAIL on the next check and cycle through the whole process again.
      if nvl(g_app_test_profile.abandon_reset, 'N') = 'N' then 
         g_app_test.test_status := 'ABANDON';
      else 
         g_app_test.test_status := 'PASS';
      end if;
   end;

   procedure set_next_reminder_interval is 
   begin 
      g_app_test.reminder_interval := g_app_test.reminder_interval * g_app_test_profile.reminder_backoff;
   end;

   function time_to_remind return boolean is 
   -- Return true if it is time to log a reminder for a FAIL'd test.
   begin 
      if nvl(g_app_test.reminder_interval, 0) > 0 and g_app_test.test_status in ('FAIL') then  
         if g_app_test.last_reminder_time + g_app_test.reminder_interval/1440 <= sysdate then
            set_next_reminder_interval;
            return true;
         end if;
      end if;
      return false;
   end;

   procedure do_app_test_reminder is 
   -- Perform actions required when it is time to send a reminder.
   begin 
      g_app_test.last_reminder_time := sysdate;
      g_app_test.reminder_count := g_app_test.reminder_count + 1;
      g_app_test.total_reminders := g_app_test.total_reminders + 1;
      if not g_app_test_profile.reminder_log_type is null then
         arcsql.log(
            p_text=>'['||g_app_test_profile.reminder_log_type||'] A reminder that application test '''||g_app_test.test_name||''' is still failing.',
            p_key=>'app_test');
      end if;
   end;

begin 
   raise_app_test_not_set;
   if g_app_test.test_status in ('FAIL') then 
      if abandon_interval then 
         abandon_test;
      elsif time_to_remind then 
         do_app_test_reminder;
      end if;
   end if;
   save_app_test;
end;


procedure app_test_fail (p_message in varchar2 default null) is 
   -- Called by the test developer anytime the app test fails.

   function retries_not_configured return boolean is
   -- Return true if retries are configured for the currently set app test profile.
   begin 
      if nvl(g_app_test_profile.retry_count, 0) = 0 then 
         return true;
      else 
         return false;
      end if;
   end;

   procedure do_app_test_fail is 
   -- Perform the actions required when a test status changes to FAIL.
   begin 
      g_app_test.test_status := 'FAIL';
      g_app_test.failed_time := g_app_test.test_end_time;
      g_app_test.last_reminder_time := g_app_test.test_end_time;
      g_app_test.total_failures := g_app_test.total_failures + 1;
      if not g_app_test_profile.failed_log_type is null then 
         arcsql.log(
            p_text=>'['||g_app_test_profile.failed_log_type||'] Application test '''||g_app_test.test_name||''' has failed.',
            p_key=>'app_test');
      end if;
   end;

   function app_test_pass_fail_already_called return boolean is 
   begin
      if not g_app_test.test_end_time is null then
         return true;
      else
         return false;
      end if;
   end;

begin 
   raise_app_test_not_set;
   if app_test_pass_fail_already_called then 
      return;
   end if;
   arcsql.debug2('app_test_fail');
   g_app_test.test_end_time := sysdate;
   g_app_test.message := p_message;
   if g_app_test.test_status in ('PASS') then 
      if retries_not_configured then 
         do_app_test_fail;
      else
         g_app_test.test_status := 'RETRY';
      end if;
   elsif g_app_test.test_status in ('RETRY') then 
      g_app_test.total_retries := g_app_test.total_retries + 1;
      g_app_test.retry_count := g_app_test.retry_count + 1;
      if nvl(g_app_test.retry_count, 0) >= g_app_test_profile.retry_count or 
         -- If retries are not configured they have been changed and were configured previously or we could
         -- never get to a RETRY state. We will simply fail if this is the case.
         retries_not_configured then 
         do_app_test_fail;
      end if;
   end if;
   app_test_check;
   save_app_test;
end;


procedure app_test_pass is 
   -- Called by the test developer anytime the app test passes.

   procedure do_app_pass_test is 
   begin 
      if g_app_test.test_status in ('RETRY') then 
         g_app_test.total_retries := g_app_test.total_retries + 1;
      end if;
      g_app_test.test_status := 'PASS';
      g_app_test.passed_time := g_app_test.test_end_time;
      g_app_test.reminder_count := 0;
      g_app_test.reminder_interval := g_app_test_profile.reminder_interval;
      g_app_test.retry_count := 0;
      if not g_app_test_profile.pass_log_type is null then
         arcsql.log (
            p_text=>'['||g_app_test_profile.pass_log_type||'] Application test '''||g_app_test.test_name||''' is now passing.',
            p_key=>'app_test');
      end if;
   end;

   function app_test_pass_fail_already_called return boolean is 
   begin
      if not g_app_test.test_end_time is null then
         return true;
      else
         return false;
      end if;
   end;

begin 
   raise_app_test_not_set;
   if app_test_pass_fail_already_called then 
      return;
   end if;
   arcsql.debug2('app_test_pass');
   g_app_test.test_end_time := sysdate;
   if g_app_test.test_status not in ('PASS') or g_app_test.passed_time is null then 
      do_app_pass_test;
   end if;
   save_app_test;
end;


procedure app_test_done is 
   -- Marks completion of test. Not required but auto passes any test if fail has not been called. 
   --
begin 
   -- This only runs if app_test_fail has not already been called.
   app_test_pass;
end;


procedure save_app_test is 
   pragma autonomous_transaction;
begin 
   update app_test set row=g_app_test where test_name=g_app_test.test_name;
   commit;
exception 
   when others then 
      rollback;
      raise;
end;


function cron_match (
   p_expression in varchar2,
   p_datetime in date default sysdate) return boolean is 
   v_expression varchar2(120) := upper(p_expression);
   v_min varchar2(120);
   v_hr varchar2(120);
   v_dom varchar2(120);
   v_mth varchar2(120);
   v_dow varchar2(120);
   t_min number;
   t_hr number;
   t_dom number;
   t_mth number;
   t_dow number;

   function is_cron_multiple_true (v in varchar2, t in number) return boolean is 
   begin 
      if mod(t, to_number(replace(v, '/', ''))) = 0 then 
         return true;
      end if;
      return false;
   end;

   function is_cron_in_range_true (v in varchar2, t in number) return boolean is 
      left_side number;
      right_side number;
   begin 
      left_side := get_token(p_list=>v, p_index=>1, p_sep=>'-');
      right_side := get_token(p_list=>v, p_index=>2, p_sep=>'-');
      -- Low value to high value.
      if left_side < right_side then 
         if t >= left_side and t <= right_side then 
            return true;
         end if;
      else 
         -- High value to lower value can be used for hours like 23-2 (11PM to 2AM).
         -- Other examples: minutes 55-10, day of month 29-3, month of year 11-1.
         if t >= left_side or t <= right_side then 
            return true;
         end if;
      end if;
      return false;
   end;

   function is_cron_in_list_true (v in varchar2, t in number) return boolean is 
   begin 
      for x in (select trim(regexp_substr(v, '[^,]+', 1, level)) l
                  from dual
                       connect by 
                       level <= regexp_count(v, ',')+1) 
      loop
         if to_number(x.l) = t then 
            return true;
         end if;
      end loop;
      return false;
   end;

   function is_cron_part_true (v in varchar2, t in number) return boolean is 
   begin 
      if trim(v) = 'X' then 
         return true;
      end if;
      if instr(v, '/') > 0 then 
         if is_cron_multiple_true (v, t) then
            return true;
         end if;
      elsif instr(v, '-') > 0 then 
         if is_cron_in_range_true (v, t) then 
            return true;
         end if;
      elsif instr(v, ',') > 0 then 
         if is_cron_in_list_true (v, t) then 
            return true;
         end if;
      else 
         if to_number(v) = t then 
            return true;
         end if;
      end if;
      return false;
   end;

   function is_cron_true (v in varchar2, t in number) return boolean is 
   begin 
      if trim(v) = 'X' then 
         return true;
      end if;
      for x in (select trim(regexp_substr(v, '[^,]+', 1, level)) l
                  from dual
                       connect by 
                       level <= regexp_count(v, ',')+1) 
      loop
         if not is_cron_part_true(x.l, t) then 
            return false;
         end if;
      end loop;
      return true;
   end;

   function convert_dow (v in varchar2) return varchar2 is 
       r varchar2(120);
   begin 
       r := replace(v, 'SUN', 0);
       r := replace(r, 'MON', 1);
       r := replace(r, 'TUE', 2);
       r := replace(r, 'WED', 3);
       r := replace(r, 'THU', 4);
       r := replace(r, 'FRI', 5);
       r := replace(r, 'SAT', 6);
       return r;
   end;

   function convert_mth (v in varchar2) return varchar2 is 
      r varchar2(120);
   begin 
      r := replace(v, 'JAN', 1);
      r := replace(r, 'FEB', 2);
      r := replace(r, 'MAR', 3);
      r := replace(r, 'APR', 4);
      r := replace(r, 'MAY', 5);
      r := replace(r, 'JUN', 6);
      r := replace(r, 'JUL', 7);
      r := replace(r, 'AUG', 8);
      r := replace(r, 'SEP', 9);
      r := replace(r, 'OCT', 10);
      r := replace(r, 'NOV', 11);
      r := replace(r, 'DEC', 12);
      return r;
   end;

begin 
   -- Replace * with X.
   v_expression := replace(v_expression, '*', 'X');
   raise_invalid_cron_expression(v_expression);

   v_min := get_token(p_list=>v_expression, p_index=>1, p_sep=>' ');
   v_hr := get_token(p_list=>v_expression, p_index=>2, p_sep=>' ');
   v_dom := get_token(p_list=>v_expression, p_index=>3, p_sep=>' ');
   v_mth := convert_mth(get_token(p_list=>v_expression, p_index=>4, p_sep=>' '));
   v_dow := convert_dow(get_token(p_list=>v_expression, p_index=>5, p_sep=>' '));

   t_min := to_number(to_char(p_datetime, 'MI'));
   t_hr := to_number(to_char(p_datetime, 'HH24'));
   t_dom := to_number(to_char(p_datetime, 'DD'));
   t_mth := to_number(to_char(p_datetime, 'MM'));
   t_dow := to_number(to_char(p_datetime, 'D'));

   if not is_cron_true(v_min, t_min) then 
      return false;
   end if;
   if not is_cron_true(v_hr, t_hr) then 
      return false;
   end if;
   if not is_cron_true(v_dom, t_dom) then 
      return false;
   end if;
   if not is_cron_true(v_mth, t_mth) then 
      return false;
   end if;
   if not is_cron_true(v_dow, t_dow) then 
      return false;
   end if;
   return true;
end;

-- | -----------------------------------------------------------------------------------
-- | Sensors
-- | -----------------------------------------------------------------------------------

procedure set_sensor (p_key in varchar2) is 
begin 
   select * into g_sensor from arcsql_sensor where sensor_key=p_key;
end;

function does_sensor_exist (p_key in varchar2) return boolean is 
   n number;
begin
   select count(*) into n from arcsql_sensor where sensor_key=p_key;
end;


function sensor (
   p_key in varchar2,
   p_input in varchar2,
   p_fail_count in number default 0) return boolean is 
begin 
   update arcsql_sensor 
      set matches=decode(p_input, input, 'Y', 'N'),
          old_input=input,
          input=p_input,
          old_updated=updated,
          updated=sysdate,
          fail_count=fail_count+decode(p_input, input, 0, 1)
    where sensor_key=p_key;
   if sql%rowcount = 0 then 
      insert into arcsql_sensor (
         sensor_key,
         old_input,
         input,
         old_updated,
         updated,
         matches,
         fail_count) values (
         p_key,
         p_input,
         p_input,
         sysdate,
         sysdate,
         'Y',
         0);
      commit;
      return false;
   end if;
   select * into g_sensor from arcsql_sensor where sensor_key=p_key;
   if g_sensor.matches = 'Y' then 
      return false;
   else 
      g_sensor.sensor_message := 'Sensor change detected: '''||g_sensor.sensor_key||'''.
Old input: '||g_sensor.old_input||'
New input :'||g_sensor.input;
      update arcsql_sensor set sensor_message=g_sensor.sensor_message where sensor_key=p_key;
      commit;
      return true;
   end if;
end;

-- | -----------------------------------------------------------------------------------
-- | Messaging
-- | -----------------------------------------------------------------------------------

-- The messaging interface queue leverages the logging interface.
procedure send_message (
   p_text in varchar2,  
   -- ToDo: Need to set up a default log_type.
   p_log_type in varchar2 default 'email',
   -- ToDo: key is confusing, it sounds unique but it really isn't. Need to come up with something clearer.
   -- p_key in varchar2 default 'arcsql',
   p_tags in varchar2 default null) is 
begin 
   log_interface(
      p_type=>p_log_type,
      p_text=>p_text, 
      p_key=>'message',
      p_tags=>p_tags, 
      p_level=>0);
end;

procedure assert_not_null (
   p_value in varchar2, 
   p_error_message in varchar2 default 'Value should not be null!') is
begin
   if p_value is null then
      raise_application_error(-20001, p_error_message);
   end if;
end;

procedure assert_not_null (
   p_timestamp in timestamp, 
   p_error_message in varchar2 default 'Timestamp should not be null!') is
begin
   if p_timestamp is null then
      raise_application_error(-20001, p_error_message);
   end if;
end;

procedure assert_not_null (
   p_date in date, 
   p_error_message in varchar2 default 'Date should not be null!') is
begin
   if p_date is null then
      raise_application_error(-20001, p_error_message);
   end if;
end;

/*

### kill_sessions (procedure)

Kills sessions for given user if last call et is >= to the input value.

* **p_username** - The database user name.
* p_last_call_et - Kills session older than N seconds.

Requires user to have ALTER SYSTEM privs which are not given by default.

*/

procedure kill_sessions (
   p_username in varchar2,
   p_last_call_et in number default 600) is 
   cursor sessions_to_kill is 
   select inst_id, sid, serial#
     from gv$session
    where username=p_username 
      and last_call_et >= p_last_call_et;
begin 
   for s in sessions_to_kill loop 
      execute immediate 'alter system kill session ''' ||s.sid|| ',' ||s.serial# || ',' || '@' || s.inst_id || ''' immediate';
   end loop;
end;


end;
/



create or replace package body k2_json as 

procedure json_to_data_table_handle_array ( -- Parses each element in a JSON array and inserts into a table.
   p_json_data clob,
   p_json_key in varchar2,
   p_json_path in varchar2,
   p_depth in number,
   p_data_key in varchar2) is 
   j json_array_t;
   v_data_value clob;
   v_data_type varchar2(30);
   v_json_path varchar2(120);
   v_data_size number;
begin 
   arcsql.debug2('json_to_data_table_handle_array: '||p_json_key);
   j := json_array_t(p_json_data);
   for i in 0 .. j.get_size - 1 loop 
      v_data_value := null;
      v_data_type := null;
      v_json_path := p_json_path||'.'||to_char(i+1);
      if j.get(i).is_object then 
         v_data_type := 'object';
         json_to_data_table (
            p_json_data=>j.get(i).to_clob,
            p_json_key=>p_json_key,
            p_json_path=>v_json_path,
            -- ToDo: Not entirely sure if I need to increase depth here.
            p_depth=>p_depth+1,
            p_data_index=>i+1);
      elsif j.get(i).is_array then 
         v_data_type := 'array';
         json_to_data_table_handle_array (
            p_json_data=>j.get(i).to_clob,
            p_json_key=>p_json_key,
            p_json_path=>v_json_path,
            p_depth=>p_depth,
            p_data_key=>p_data_key);
      elsif j.get(i).is_string then
         v_data_type := 'string';
         v_data_value := j.get_string(i);
      elsif j.get(i).is_number then
         v_data_type := 'number';
         v_data_value := to_char(j.get_number(i));
      elsif j.get(i).is_true then
         v_data_type := 'boolean';
         v_data_value := '1';
      elsif j.get(i).is_false then
         v_data_type := 'boolean';
         v_data_value := '0';
      elsif j.get(i).is_null then
         v_data_type := 'unknown';
         v_data_value := null;
      end if;
      v_data_size := 1;
      insert into json_data (
         json_key,
         json_path, 
         data_type,
         data_size,
         data_value,
         data_index,
         data_key) values (
         p_json_key,
         v_json_path,
         v_data_type,
         v_data_size,
         v_data_value,
         i+1,
         p_data_key);
   end loop;
end;

procedure json_to_data_table ( -- Parses each element in a JSON object and inserts into a table.
   p_json_data in clob,
   p_json_key in varchar2,
   p_json_path in varchar2 default 'root',
   p_depth in number default 0,
   p_data_index in number default 0,
   p_root_key in varchar2 default null) is
   j json_object_t;
   k json_key_list;
   v_data_value clob;
   v_data_type varchar2(30);
   v_data_key varchar2(120);
   v_json_path varchar2(120);
   v_data_size number;
begin
   arcsql.debug2('json_to_data_table: '||p_json_key);
   if p_root_key is null then 
      j := json_object_t (p_json_data);
   else 
      j := json_object_t ('{"'||p_root_key||'": '||p_json_data||'}');
   end if;
   if p_depth = 0 then 
      delete from json_data where json_key=p_json_key;
   end if;
   
   k := j.get_keys;
   -- Note indexing diff if you are looping over keys or array, one is 1 and the latter is 0.
   for key in 1..k.count loop
      v_data_value := null;
      v_data_type := null;
      v_data_key := k(key);
      v_json_path := p_json_path||'.'||v_data_key;
      v_data_size := j.get(k(key)).get_size;
      arcsql.debug2('name='||v_data_key||', size='||v_data_size);
      if j.get(k(key)).is_array then
         arcsql.debug2('is array');
         v_data_type := 'array';
         if v_data_size > 0 then
            json_to_data_table_handle_array (
               p_json_data=>j.get(k(key)).to_clob,
               p_json_key=>p_json_key,
               p_json_path=>v_json_path,
               p_depth=>p_depth,
               p_data_key=>v_data_key);
         end if;
      end if;
      if j.get(k(key)).is_object then
         v_data_type := 'object';
         arcsql.debug2('is object');
         json_to_data_table(
            p_json_data=>j.get_object(k(key)).to_clob, 
            p_json_key=>p_json_key,
            p_json_path=>v_json_path,
            p_depth=>p_depth+1);
      end if;
      if j.get(k(key)).is_string then
         v_data_type := 'string';
         v_data_value := j.get_string(k(key));
      elsif j.get(k(key)).is_number then
         v_data_type := 'number';
         v_data_value := to_char(j.get_number(k(key)));
      elsif j.get(k(key)).is_true then
         v_data_type := 'boolean';
         v_data_value := '1';
      elsif j.get(k(key)).is_false then
         v_data_type := 'boolean';
         v_data_value := '0';
      elsif j.get(k(key)).is_null then
         v_data_type := 'unknown';
         v_data_value := null;
      end if;
      insert into json_data (
         json_key,
         json_path, 
         data_type,
         data_size,
         data_value,
         data_index,
         data_key) values (
         p_json_key,
         v_json_path,
         v_data_type,
         v_data_size,
         v_data_value,
         p_data_index,
         v_data_key);
   end loop;
exception
   when others then
      arcsql.log_err('json_to_data_table: '||p_depth||', '||p_json_path||', '||sqlerrm);
      raise;
end;

function get_json_data_string ( -- Return a value from json_data table as a string.
   p_json_key in varchar2,
   p_json_path in varchar2) return varchar2 is 
   r varchar2(4000);
begin 
   select to_char(data_value) into r from json_data where json_key = p_json_key and json_path = p_json_path;
   return r;
end;

function get_json_data_number ( -- Return a value from json_data table as a number.
   p_json_key in varchar2,
   p_json_path in varchar2) return varchar2 is 
   r number;
begin 
   select to_number(data_value) into r from json_data where json_key = p_json_key and json_path = p_json_path;
   return r;
end;

function get_json_from_store ( -- Return json of json datatype from the json_store table.
   p_json_key in varchar2) return json is 
   r json;
begin
   select json_data into r from json_store where json_key=p_json_key;
   return r;
end;

function get_clob_from_store (
   p_json_key in varchar2) return clob is 
   j json;
   r clob;
begin 
   return k2_json.to_clob(p_json=>get_json_from_store(p_json_key=>p_json_key));
end;

procedure store_data ( -- Stores p_json_data in a table called json_store using p_json_key.
   /*
   This is an easy way to store JSON in a look up table using a key.
   If p_json_key already exists the record will get deleted and new value will get inserted.
   */
   p_json_key in varchar2,
   p_json_data in clob) is
begin
   delete from json_store 
    where json_key=p_json_key;
   insert into json_store (
      json_key,
      json_data) values (
      p_json_key,
      p_json_data);
end;

function to_clob ( -- Convert json datatype to clob.
   p_json in json) return clob is 
   r clob;
begin
   select json_mergepatch('{"foo": "1"}', p_json returning clob) into r from dual;
   return r;
end;

function get_json_from_url ( -- | Makes a get request and returns the response as CLOB.
   p_url in varchar2)
   return clob is
   response clob;
begin 
   apex_web_service.g_request_headers.delete();
   apex_web_service.g_request_headers(1).name := 'content-type';
   apex_web_service.g_request_headers(1).value := 'application/json'; 
   response := apex_web_service.make_rest_request (
      p_url         => p_url, 
      p_http_method => 'GET');
   apex_json.parse(response);
   return response;
end;

end;
/

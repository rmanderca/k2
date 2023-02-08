
-- uninstall: exec drop_package('k2_json');

create or replace package k2_json as 

   -- ToDo: This may need to support only json or both json and clob. Need some tests.
   procedure json_to_data_table (
      p_json_data in clob,
      p_json_key in varchar2,
      p_json_path in varchar2 default 'root',
      p_depth in number default 0,
      p_data_index in number default 0,
      p_root_key in varchar2 default null);

   procedure store_data (
      p_json_key in varchar2,
      p_json_data in clob);

   function get_json_data_string (
      p_json_key in varchar2,
      p_json_path in varchar2) return varchar2;

   function get_json_data_number (
      p_json_key in varchar2,
      p_json_path in varchar2) return varchar2;

   function get_json_from_store (
      p_json_key in varchar2) return json;

   function get_clob_from_store (
      p_json_key in varchar2) return clob;

   function to_clob (
      p_json in json) return clob;
   
   function get_json_from_url (
      p_url in varchar2) return clob;

end;
/

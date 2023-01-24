
-- uninstall: exec drop_package('k2_json');

create or replace package k2_json as 

   procedure json_to_data_table (
      p_json_data in clob,
      p_json_key in varchar2,
      p_json_path in varchar2 default 'root',
      p_depth in number default 0);

   procedure store_data (
      p_json_key in varchar2,
      p_json_data in clob);

   function get_json_data_string (
      p_json_key in varchar2,
      p_json_path in varchar2) return varchar2;

   function get_json_data_number (
      p_json_key in varchar2,
      p_json_path in varchar2) return varchar2;
   
end;
/

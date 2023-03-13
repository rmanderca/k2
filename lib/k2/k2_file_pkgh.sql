
-- uninstall: exec drop_package('k2_file');
create or replace package k2_file as 

   procedure create_file_from_sql (
      p_file_store_key in varchar2,
      p_file_name in varchar2,
      p_sql in varchar2,
      p_file_format in varchar2,
      p_file_tags in varchar2 default null,
      p_user_id in number default null,
      p_user_name in varchar2 default null);

   function get_file_store_row (
      p_file_store_key in varchar2) return file_store%rowtype;

   procedure download_file (
      p_file_store_key in varchar2);

end;
/

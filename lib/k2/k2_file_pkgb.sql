create or replace package body k2_file as 

/*

### add_row_to_file_store (procedure)

Add a row to FILE_STORE table.

* **p_file_store_key** - Unique key that identifies the file in the file_store table.
* **p_export** - apex_data_export.t_export object.
* **p_file_format** - The format of the file to be created (e.g., CSV, XLSX, PDF, etc.).
* p_file_tags - Tags associated with the file. 
* p_user_id - User ID

*/

procedure add_row_to_file_store (
   p_file_store_key in varchar2,
   p_export in apex_data_export.t_export,
   p_file_format in varchar2,
   p_file_tags in varchar2 default null,
   p_user_id in number default null) 
   is
begin 
   delete from file_store where file_store_key=p_file_store_key;

   insert into file_store columns (
      file_store_key,
      file_name,
      file_format,
      file_mimetype,
      file_blob,
      file_tags,
      user_id) values (
      p_file_store_key,
      p_export.file_name,
      upper(p_file_format),
      p_export.mime_type,
      p_export.content_blob,
      p_file_tags,
      p_user_id);   
end;

function get_file_store_row (
   p_file_store_key in varchar2) return file_store%rowtype is
   r file_store%rowtype;
begin 
   select * into r from file_store where file_store_key=p_file_store_key;
   return r;
end;

/*

### create_file_from_sql (procedure)

Creates a file from a provided SQL statement and stores it in the FILE_STORE table. 

* **p_file_store_key** - Unique key that identifies the file in the file_store table.
* **p_file_name** - The name of the file to be created.
* **p_sql** - The SQL statement used to generate the file content.
* **p_file_format** - Export format. Valid values are: XLSX, PDF, HTML, CSV, XML and JSON.
* p_file_tags - Tags associated with the file. 
* p_user_id - User ID

It would be a good idea to review the docs for apex_data_export.export. There are a lot of options that are not exposed here.

*/

procedure create_file_from_sql ( -- | Create a file from SQL and store it in the file_store table.
   p_file_store_key in varchar2,
   p_file_name in varchar2,
   p_sql in varchar2,
   p_file_format in varchar2,
   p_file_tags in varchar2 default null,
   p_user_id in number default null) is 
   v_context apex_exec.t_context; 
   v_export apex_data_export.t_export;
begin
   arcsql.debug('create_file_from_sql: ' || p_file_store_key || ', ' || p_file_name || ', ' || p_sql || ', ' || p_file_format || ', ' || p_file_tags || ', ' || p_user_id);
   
   -- Prevents the "ORA-20001: This procedure must be invoked from within an application session." error when run outside an APEX session.
   wwv_flow_api.set_security_group_id;

   v_context := apex_exec.open_query_context (
      p_location=>apex_exec.c_location_local_db,
      p_sql_query=>p_sql);

   v_export := apex_data_export.export (
      p_context=>v_context,
      p_format=>p_file_format,
      p_file_name=>p_file_name);

   apex_exec.close(v_context);

   add_row_to_file_store (
      p_file_store_key=>p_file_store_key,
      p_export=>v_export,
      p_file_format=>p_file_format,
      p_file_tags=>p_file_tags,
      p_user_id=>p_user_id);

exception
   when others then
      apex_exec.close(v_context);
      raise;
end;

/*

### download_file (procedure)

Downloads a file from the FILE_STORE table.

* **p_file_store_key** - Unique key that identifies the file in the file_store table.

Note the page must set "Reload on submit" to "Always". Create a process which calls this proc after submit. Create a button that submits the page. Depending on file type it may open in the browser window as opposed to downloading. Recommended you use the FOS download plugin instead of this process if it is available.

*/

procedure download_file (
   p_file_store_key in varchar2) is 
   v_blob_content blob;
   v_mime_type varchar2(512);
   v_filename varchar2(512);
begin
   arcsql.debug('download_file: ' || p_file_store_key);
   select file_blob,
          file_mimetype,
          file_name
     into v_blob_content,
          v_mime_type,
          v_filename
     from file_store 
    where file_store_key=p_file_store_key;
   sys.htp.init;
   sys.owa_util.mime_header(v_mime_type, false);
   sys.htp.p('Content-Length: ' || dbms_lob.getlength(v_blob_content));
   sys.htp.p('Content-Disposition: filename="' || v_filename || '"');
   sys.owa_util.http_header_close;
   sys.wpg_docload.download_file(v_blob_content);
   apex_application.stop_apex_engine;
exception
   when apex_application.e_stop_apex_engine then
      null;
   when others then 
      raise;
end;

end;
/

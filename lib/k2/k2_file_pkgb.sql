create or replace package body k2_file as 

-- ToDo: DO NOT REQUIRE USER_ID in other k2 modules if NOBODY is ever user!

function gets_export_from_context (
   p_context in apex_exec.t_context,
   p_file_format in varchar2,
   p_file_name in varchar2)
   return apex_data_export.t_export is 
begin
   return apex_data_export.export (
      p_context=>p_context,
      p_format=>p_file_format,
      p_file_name=>p_file_name);
end;

function gets_context_from_sql (
   p_sql in varchar2)
   return apex_exec.t_context is 
begin
   return apex_exec.open_query_context (
      p_location=>apex_exec.c_location_local_db,
      p_sql_query=>p_sql);
end;

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
   
procedure create_file_from_sql ( -- | Create a file from SQL and store it in the file_store table.
   p_file_store_key in varchar2,
   p_file_name in varchar2,
   p_sql in varchar2,
   p_file_format in varchar2,
   p_file_tags in varchar2 default null,
   -- Can be called with user id or user name.
   p_user_id in number default null,
   p_user_name in varchar2 default null) is 
   v_context apex_exec.t_context; 
   v_export apex_data_export.t_export;
   v_user_id number := p_user_id;
begin
   arcsql.debug('create_file_from_sql: ' || p_file_store_key || ', ' || p_file_name || ', ' || p_sql || ', ' || p_file_format || ', ' || p_file_tags || ', ' || p_user_id || ', ' || p_user_name);
   
   -- Prevents the "ORA-20001: This procedure must be invoked from within an application session." error when run outside an APEX session.
   wwv_flow_api.set_security_group_id;

   if v('APP_USER') != 'nobody' and v_user_id is null then
      v_user_id := saas_auth_pkg.to_user_id(p_user_name=>p_user_name);
   end if;

   v_context := gets_context_from_sql(p_sql=>p_sql);

   v_export := gets_export_from_context (
      p_context=>v_context,
      p_file_format=>p_file_format,
      p_file_name=>p_file_name);

   apex_exec.close(v_context);

   add_row_to_file_store (
      p_file_store_key=>p_file_store_key,
      p_export=>v_export,
      p_file_format=>p_file_format,
      p_file_tags=>p_file_tags,
      p_user_id=>v_user_id);

exception
   when others then
      apex_exec.close(v_context);
      raise;
end;

procedure download_file ( -- | Called from a page to download a file.
   /*
   Note the page must set "Reload on submit" to "Always". Create a process which calls this proc after submit.
   Create a button that submits the page. Depending on file type it may open in the browser window
   as opposed to downloading. Recommended you use the FOS download plugin instead of this process
   if it is available.
   */
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

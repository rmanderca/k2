
exec k2_test.setup;

declare
   v_file_store file_store%rowtype;
begin
	arcsql.init_test('Create a file');
	k2_file.create_file_from_sql(
		p_file_store_key=>'test_file',
		p_file_name=>'test_file.csv',
		p_sql=>'select * from dual',
		p_file_format=>'csv',
		p_file_tags=>'test',
		p_user_id=>k2_test.user_id);
	arcsql.pass_test;
    
   arcsql.init_test('Send file as email attachement');
   v_file_store := k2_file.get_file_store_row('test_file');
   app_send_email_attachement(
      p_to=>app_config.app_owner_email,
      p_from=>app_config.app_from_email,
      p_body=>'Test email with attachement.',
      p_subject=>'Test email with attachement '||sysdate,
      p_blob=>v_file_store.file_blob,
      p_mimetype=>v_file_store.file_mimetype,
      p_file_name=>v_file_store.file_name
      );
   arcsql.pass_test;
    
exception
	when others then
		raise;
end;
/

commit;

@k2_test_result.sql

select * from arcsql_log order by 1 desc;
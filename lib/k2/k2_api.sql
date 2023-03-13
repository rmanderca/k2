
begin

   if k2_config.enable_ords then 
      ords.enable_schema;
   else
      ords.enable_schema(false);
   end if;

   -- ToDo: Remove this 
   ords.delete_module (
      p_module_name=>'api_v1');

   ords.delete_module (
      p_module_name=>'k2_api_v1');

   ords.define_module (
      p_module_name=>'k2_api_v1',
      p_base_path=>'k2/v1/',
      p_items_per_page=>1000,
      p_status=>'PUBLISHED',
      p_comments=>'K2 API');

   ords.define_template (
      p_module_name=>'k2_api_v1',
      p_pattern=>'status',
      p_comments=>'Check status of the API');

   -- Just showing another way to return status here.
   -- ords.define_handler (
   --    p_module_name=>'api_v1',
   --    p_pattern=>'status',
   --    p_method=>'GET',
   --    p_mimes_allowed=>'',
   --    p_source_type=>ords.source_type_query_one_row,
   --    p_source=>q'<select 'ok' message from dual>');

   ords.define_handler (
      p_module_name=>'k2_api_v1',
      p_pattern=>'status',
      p_method=>'GET',
      p_mimes_allowed => '',
      p_source_type=>ords.source_type_plsql,
      p_source=>'begin k2_api.status_v1; end;');

   commit;

end;
/

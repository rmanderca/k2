

begin 
   arcsql.create_contact_group('admin');
   arcsql.add_contact_to_contact_group(
      p_group_name=>'admin',
      p_email_address => app_config.admin_email,
      p_sms_address => app_config.admin_sms);
end;
/

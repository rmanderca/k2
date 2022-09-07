

begin 
   arcsql.create_contact_group('admin');
   arcsql.add_contact_to_contact_group(
      p_group_name=>'admin',
      p_email_address => 'post.ethan@gmail.com',
      p_sms_address => '9312303317@txt.att.net');
end;
/

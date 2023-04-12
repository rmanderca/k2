

begin
    -- Get these values from your provider!
    apex_instance_admin.set_parameter('SMTP_HOST_ADDRESS', 'smtp.email.us-phoenix-1.oci.oraclecloud.com');
    apex_instance_admin.set_parameter('SMTP_USERNAME', 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx');
    apex_instance_admin.set_parameter('SMTP_PASSWORD', 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx');
    commit;
end;
/

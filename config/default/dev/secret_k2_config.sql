
-- uninstall: exec drop_package('k2_config');
create or replace package k2_config as 

    -- This should be null or match the actual v('APP_ID') value. It is set here
    -- in order to support testing from SQL*Developer since the context of APP_ID
    -- does not otherwise exist.
    app_id number := 0;

    -- Used to form links to the application from the outside world.
    -- These values should not end with a slash /.
    external_app_domain varchar2(120) := 'https://xxxxxxxxxxxxxxxxxxx.adb.us-phoenix-1.oraclecloudapps.com';
    internal_app_domain varchar2(120) := 'https://xxxxxxxxxxxxxxxxxxx.adb.us-phoenix-1.oraclecloudapps.com';
    -- This is 'ords' on Oracle Cloud and 'apex' on Maxapex.
    ords_url_prefix varchar2(12) := 'ords';

    -- Determines if ords is enabled for the schema.
    enable_ords boolean := true;

    secret_key varchar2(100) := 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';

    -- Do not include a trailing slash. '/v1/' or other versions will be appended to the base path.
    api_base_path varchar2(120) := '/api';

end;
/


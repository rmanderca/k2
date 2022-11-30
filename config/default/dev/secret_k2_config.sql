
-- uninstall: exec drop_package('k2_config');
create or replace package k2_config as 

    -- Used to determine which env we are working in. Usually dev, tst, prd.
    env varchar2(12) := 'dev';

    -- Application name. May want to include the env for non prod environments.
    app_name varchar2(120) := 'My Default App (dev)';
    app_version number := 20221019;

    -- This should be null or match the actual v('APP_ID') value. It is set here
    -- in order to support testing from SQL*Developer since the context of APP_ID
    -- does not otherwise exist.
    app_id number := 0;

    -- Used to form links to the application from the outside world.
    -- These values should not end with a slash /.
    external_app_domain varchar2(120) := 'https://k2.maxapex.net';
    internal_app_domain varchar2(120) := 'https://k2.maxapex.net';
    -- This is 'ords' on Oracle Cloud and 'apex' on Maxapex.
    ords_url_prefix varchar2(12) := 'apex';

    -- Set to a default timezone to use in cases when you don't know time zone.
    default_timezone varchar(120) := 'US/Eastern';

    -- Adds prefix to message of k2.debug* calls when it forwards to apex_debug.
    -- This makes it a little easier to see what calls are specifically yours when
    -- viewing debug or querying apex_debug_messages. Set to blank or null to disable.
    apex_debug_prefix varchar(25) := 'k2: ';
    -- Do you want messages forwarded to apex_debug?
    enable_apex_debug boolean := true;
    -- Do you want messages forwards to arcsql_debug?
    enable_arcsql_logging boolean := true;

    -- Do you want to enable the statzilla job which processes buckets?
    enable_statzilla boolean := true;
    
    -- Do you want to collect oracle metrics?
    enable_statzilla_get_oracle_metrics boolean := true;

    -- Do you want K2 to collect metrics?
    enable_k2_metrics boolean := true;

    -- This disables email if send_email procedure references it(see long story file 11/4/2022).
    disable_email boolean := false;

    -- Determines if ords is enabled for the schema.
    enable_ords boolean := true;

    secret_key varchar2(100) := 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';

end;
/


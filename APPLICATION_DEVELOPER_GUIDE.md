
# APPLICATION DEVELOPER GUIDE

9/17/2022 – This document is a work in progress.

### Environments

The name you assign your environment should be maintained in the ```k2_config.env``` configuration value. It can be used to conditionally apply code to particular environments. K2 has no opinion on what you use here. 

### Soft versioning

Soft versioning means that the version numbers are not “real” versions. They are used and advanced as needed. They are number. My preferred format is ```YYYYMMDD```.

K2 version is maintained by K2 team and referenced from ```K2_APP.VERSION```. Located in ```./_k2_install.sql```.
The version for the application is maintained by the developer and referenced from ```APP_CONFIG.VERSION```. Located in ```./config/${app}/${env}/secret_app_config.sql.```

Soft versions are used in app code or install code, something like this…**"do this if app_config.version < 20220916"**. Then change the version number in secret_app_config.sql to 20220916 and the block will run the next time the app is deployed and only run once.

In most cases it is best if you avoid referencing versions all together to patch/upgrade code and just write idempotent code.
Soft versioning might also be needed to feature flag features. Example, **"if app_config.version < 20220916 then call “the old code” else call “the new code”**.

### What if your application needs specific permissions/grants?

Add your grants to ```./app/${app}/${env}/app_grants.sql```. It is up to the developer to apply the grants to the application user by running the script from an administrative account. When new environments are being initiated you should run the script after running the ```./k2_grants.sql``` script.

You could optionally reference the ```app_grants.sql``` script from ```./k2_grants.sql``` but will need to be careful to keep the change when upgrading K2.

### How do I upgrade K2?

### How do I write unit tests?

### How do I add test users to my application?

### Oracle metrics

Statzilla (a component of K2) installs a job to collect Oracle metrics into the stat* tables. See config variables in ```K2_CONFIG``` package. Stats are associated with the 'oracle (local)' Statzilla bucket. Also see the ```./lib/statzilla/statzilla_get_oracle_metrics.prc``` file.

# Available libraries

## APEX utility package

This package contains miscellaneous functions for Oracle APEX environments. See the ```apex_utl2``` package for more information.

## K2 utility package
This package contains miscellaneous functions for K2. See the ```k2``` package for more information.

## ArcSQL

### Schema  management
ArcSQL provides functions and procedures ( --> ```./lib/arcsql/arcsql_schema_support.sql``) to help you manage the schema within single idempotent file. This code can run standalone in any environment and does not require any other K2 or ArcSQL dependencies. So if you like this way of doing things you can grab this code and use it anywhere.

### Datetime Functions
There are a couple of datetime functions; ```secs_between_timestamps``` and ```secs_since_timestamp```. Many more could be added as needed. 

### Timer
Use ```start_timer``` and ```get_timer``` if you need to time something or loop until some numbers of seconds have passed. This is not meant to be a high-speed timer.

### Strings
There are quite a few string functions. See the package for more information. Too many to list here.

### Numbers 
There are a few functions which get values related to variances and a random gaussian value. These were added for an app I worked on and not sure how much value they currently have.

### Utilities
Miscellaneous utilities. See package for more information.

### A simple key/value data store
### Dynamic configuration items
### SQL monitoring
### Counter
### Event duration/count tracking
### Logging/debug
### Contact group management
### Unit testing
### Application testing/monitoring 
### Sensors
### Messaging
### Alerting

## SAAS authorization package

This library contains code for creating accounts, email verification, generating auto-login tokens, resetting passwords, login, and logout. 

## Statzilla metrics tracking package

This library is used to collect and track metrics.

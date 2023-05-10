
-- IMPORTANT: The files below should be idempotent (https://en.wikipedia.org/wiki/Idempotence).

-- WARNING: You may want to exclude files starting with secret* from git. See the .gitignore file.

@demo_config.sql
@app_patch.sql
@app_schema.sql
@app_pkgh.sql
@app_pkgb.sql
@app_api_pkgh.sql
@app_api_pkgb.sql
@app_api.sql

-- Authentication (create account, verify email, login, forgot password) features.
@app_events.sql

-- Automatically pre-create users you need for your app.
@app_users.sql

-- app_send_email procedure over-ride. Replace the delivery proc with your proc to interface with your email solution.
@app_send_email.sql

-- Things that need to run towards the end of the install.
@app_post_install.sql

-- Install any scheduled jobs using the dbms job scheduler.
@app_schedules.sql

@app_alert.sql

@app_test.sql

commit;

select 'APP install complete.' message from dual;

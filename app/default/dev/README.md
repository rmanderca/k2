### ./app/default/dev

Most of your application code should reside in these files and folder.

#### Included files

| Name | Purpose |
| -- | -- | 
| app_grants.sql | Add grants that need to be given to your application user(s) here. You are responsible for running this file from an account with admin privs. |
| app_install.sql | This script calls most of the files here. You should add your application's files to this script also. |
| app_scheduler_jobs.sql | Add your app's dbms_scheduler jobs here. |
| app_todo.md | An easy place to jot down to do items. |
| app_contact_groups.sql | Your contact groups to use for notifications and alerting. | 
| build_app_uninstall.sh | Run this to build or update the uninstall script. |
| patch.sql | Add code that needs to run to when you app is being upgraded. |
| saas_app_post_install.sql | Statements that should run at the end of the install process. |
| saas_auth_events.sql | Modify these procedures to hook your app into one or more authentication events. |
| send_email.sql | Modify this file to enable email. |
| users.sql | This file contains default user accounts you want to add to your application. |

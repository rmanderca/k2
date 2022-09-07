# K2 

The fastest way to build and prototype applications on Oracle APEX. Subscribe to my Oracle APEX focused [YouTube channel](https://www.youtube.com/channel/UC8cIGO-lRvWM-mPtJdO_9XQ) for updates.

## How to install the K2 framework

1. Run the ./lib/arcsql/arcsql_user.sql script to create your application user.
2. As the application user run ./install/demo/dev/demo_install.sql
3. Import the APEX application from ./exports/demo folder.

* [How to install K2 updated Sep 6 2022](https://youtu.be/FKdsuL_oYgw)

## Adding scheduled tasks to your application

Add scheduled tasks to the app_scheduler_jobs.sql file. If they need to be dynamically enabled/disabled by environment consider adding confg values to the app_config package and referencing them from your code in the jobs file.

* [How I create recurring tasks using K2 instead of APEX Automations and why](https://youtu.be/WxwzxSFhuS4)


# K2 

The fastest way to build and prototype applications on Oracle APEX. Subscribe to the [APEX Reloaded]](https://www.youtube.com/channel/UC8cIGO-lRvWM-mPtJdO_9XQ) YouTube channel for updates.

Share K2 with others using the link [builtonapex.com/k2](builtonapex.com/k2) which redirects here!

## How to install the K2 framework (quick)

1. Edit and run ./ks_user.sql as admin to create an app user.
2. Edit and run ./ks_grants.sql as admin to grant permissions to the app user.
3. As the app user run ./install/default/dev/default_install.sql
4. As APEX admin link the app user schema to an APEX workspace.
5. Import the starter app from ./exports/default folder into your APEX workspace.

* [How to install K2 updated - 9/6/22](https://youtu.be/FKdsuL_oYgw)

## Getting started 

Note: This section could simply replace step 2 above and achieves the same thing but in this case you end up with the folders you need to begin developing your app.

* Copy ./app/default folder ./app/your_app
* Copy ./config/default to ./config/your_app
* Copy ./install/default to ./install/your_app
* Modify the settings for each config file in ./config/your_app folder.
* Replace the 'default' path in ./install/your_app/default_install.sql and rename the file to your_app_install.sql.
* Replace the 'default' paths in ./app/your_app/app_install.sql with the path of your app.
* Consider filtering files starting with secret* from git. See the .gitignore file.
* If everything is good you should be able to run ./install/your_app/dev/your_app_install.sql as your application user without errors. If there are errors try running again. If you still get errors open an issue here.

## Logging and debugging

Look at k2 for debug/logging related procedures. k2 calls are just a wrapper so that your calls are sent to both arcsql.* and apex_debug.*. You can add a prefix to the apex_debug calls using k2_config.apex_debug_prefix variable.
```
begin
	k2.debug(p_text=>'My debug message.', p_key=>'My App');
end;
/
```
There are other calls like debug2, log, log_audit, log_security_event. See the k2 and arcsql packages for more info.

## Adding scheduled tasks to your application

Add scheduled tasks to the app_scheduler_jobs.sql file. If they need to be dynamically enabled/disabled by environment consider adding confg values to the app_config package and referencing them from your code in the jobs file.

* [How I create recurring tasks using K2 instead of APEX Automations and why - 9/7/22](https://youtu.be/WxwzxSFhuS4)

## Other helpful resources

* [How I implemented Dark and Light theme selection in my Oracle APEX app](https://youtu.be/naY-bzWPxmM)
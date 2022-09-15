
# K2 

The fastest way to build and prototype applications on Oracle APEX. Subscribe to my Oracle APEX focused [YouTube channel](https://www.youtube.com/channel/UC8cIGO-lRvWM-mPtJdO_9XQ) for updates.

Share K2 with others using the link [builtonapex.com/k2](builtonapex.com/k2) which redirects here!

## How to install the K2 framework (quick)

1. Run the ./lib/arcsql/arcsql_user.sql script to create your application user.
2. As the application user run ./install/demo/dev/demo_install.sql. 
3. Import the APEX application from ./exports/demo folder.

* [How to install K2 updated - 9/6/22](https://youtu.be/FKdsuL_oYgw)

## Getting started 

Note: This section could simply replace step 2 above and achieves the same thing but in this case you end up with the folders you need to begin developing your app.

* Copy ./app/demo folder ./app/your_app
* Copy ./config/demo to ./config/your_app
* Copy ./install/demo to ./install/your_app
* Modify the settings for each config file in ./config/your_app folder.
* Replace the 'demo' path in ./install/your_app/demo_install.sql and rename the file to your_app_install.sql.
* Replace the 'demo' paths in ./app/your_app/app_install.sql with the path of your app.
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
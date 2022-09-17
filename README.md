# K2 

The fastest way to build and prototype applications on Oracle APEX. Subscribe to the [APEX Reloaded](https://www.youtube.com/channel/UC8cIGO-lRvWM-mPtJdO_9XQ) YouTube channel for updates.

Share K2 with others using the link [builtonapex.com/k2](builtonapex.com/k2) which redirects here!

## How to install K2 and set up folders for your new app

* [How to install K2 updated - 9/17/22](https://youtu.be/b5jL91Kej7E)

Edit and run ```./ks_user.sql``` as an **administrator** to create an app user

Edit and run ```./ks_grants.sql``` as an **administrator**  to grant permissions to the app user.

```
# Run the script to create the folders and files for your new app.
# For our example the new app name will be 'foo'.
./new_app.sh "foo"
```

Review and edit the configuration files in ```./config/foo/dev``` .

As the new **database application user** run ```./install/foo/dev/foo_install.sql```.

As an **APEX admin** link the app user schema to an APEX workspace.

As an **APEX user** Import the starter app from ```./exports/default``` folder into your APEX workspace.

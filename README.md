# K2 

The fastest way to build and prototype applications on Oracle APEX. Subscribe to the [APEX Reloaded YouTube channel](https://www.youtube.com/channel/UC8cIGO-lRvWM-mPtJdO_9XQ) for updates.

Share K2 with others using the link [builtonapex.com/k2](builtonapex.com/k2) which redirects here!

## Project goal and focus

K2 focuses on your ability to build a proof of concept (POC) or minimal viable product (MVP) in the shortest amount of time possible. It is a starting point for your application, it is not the end.

Using K2 you will be able to build a basic monitized SAAS application in as little as a few hours that has the look and feel of any other application. 

K2 is not only a framework, it is a file layout and development methodology that enhances the productivity of developers.

K2 comes with API "enabled". This means that you can easily build a REST API for your application. You can also easily build a mobile application using the K2 API.

Minimize costs. K2 will make it easy to deploy multiple applications and keep costs at a minimum.

## How to install K2 and set up folders for your new app

* [How to install K2 updated - 9/17/22](https://youtu.be/b5jL91Kej7E)

Edit and run ```./ks_user.sql``` as an **administrator** to create the database application user

Edit and run ```./ks_grants.sql``` as an **administrator**  to grant permissions to the user you just created.

```
# Run the script to create the folders and files for your new app.
# For our example the new app name will be 'foo'.
./create_app.sh "foo"
```

Review and edit the configuration files in ```./config/foo/dev``` .

As the new **database application user** run ```./install/foo/dev/foo_install.sql```.

As an **APEX admin** link the app user schema to an APEX workspace.

As an **APEX user** Import the starter app from ```./exports/k2``` folder into your APEX workspace.

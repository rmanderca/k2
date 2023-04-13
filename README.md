# K2 App Development Framework for Oracle and Oracle APEX

Main branch is on APEX 22.2.4. Last release date for main was 4/12/2023. Video playlist of project setup from scratch [here](https://www.youtube.com/playlist?list=PLoJwJp6kmzqULxbD3NDqie_ZbPdTnDfCj).

You can also just follow the steps below and start with the DEMO app in the ./exports/demo folder. This is much easier but as the demo app gets more complex may contain more than you care to start with.

## Project goal and focus

K2 provides a set of pre-written code and tools that developers use to build applications. The main purpose of a K2 is to simplify the development process and reduce the time and effort required to build an application. To achieve this, K2 provides a consistent file layout, tools, and development methodology that enhances the productivity of developers.

## How to install K2 and set up folders for your new app

* [How to install K2 updated - 3/13/23](https://youtu.be/7O_n2gaHs6M)

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

Follow me on [YouTube](builtonapex.com/youtube) and [Twitter](builtonapex.com/twitter).

# Readme 

Generic utility library for Oracle that I use to build things.

## Installation

Super easy to install. Instructions found here...

https://e-t-h-a-n.com/how-to-install-arcsql

## Starting and Stopping

Start/stop DBMS_SCHEDULER jobs associated with ArcSQL (any job name that begins with ARCSQL).

```
exec arcsql.start_arcsql;
exec arcsql.stop_arcsql;
```

## Uninstall

As the user who owns the ArcSQL objects run the arcsql_uninstall.sql script or drop the user and any related scheduled jobs.

Thanks,
Ethan 
https://e-t-h-a-n.com/ 

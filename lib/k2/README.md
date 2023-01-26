# K2 

Main library for K2.

## Logging and debugging

How do I add debug calls?

ArcSQL has three levels of debug.

```
-- Level 1
exec arcsql.debug(p_text=>'foo');
-- Level 2 
exec arcsql.debug2('foo');
-- Level 3 (most detail)
exec arcsql.debug3('foo');
```

Transactions are autonomous so they commit the data to the ARCSQL_LOG table even if you issue a rollback.

How do I set the log level?

The log level is set in the arcsql_cfg package. It defaults to 1.

```
exec arcsql_cfg.log_level := 2;
```

You can add a key which can be used to filter data when you query the ARCSQL_LOG table.

```
exec arcsql.debug(p_text=>'foo', p_key=>'mymodule');
select * from arcsql_log where log_key='mymmodule' order by entry_id;
```

You can also add tags. Tags should be separated using commas. Whatever you provide is simply passed on through to the table. In general I rarely use p_key and have never found a good reason to use p_tags.

```
exec arcsql.debug(p_text=>'foo', p_key=>'mymodule', p_tags=>'foo, bar, fiz');
```

All of the examples above are just wrappers that call arcsql.log_interface. There are a number of other types of logging calls you can make and it is fairly simple to add new ones.

log
log_notify
notify
log_deprecated
log_audit
log_security_event
log_err
debug
debug2
debug3
log_pass
log_fail
log_sms
log_email
debug_secret

The different log types are stored in ARCSQL_LOG_TYPE table.

```
select * from arcsql_log_type;
```

The table contains columns which determine if a log entry of the given type results in an SMS (via SMS email address) or an email message.

> ToDo: **Note the SMS/email feature is currently broken (as far as I can tell) due to moving contact groups into K2. This should be a priority to fix since it is actually useful!**

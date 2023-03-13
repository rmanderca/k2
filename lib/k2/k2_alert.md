### An overview of alerting

Alerts have priorities.

```
select * from alert_priorities;
```

Priorities are defined within a priority groups. 

```
select * from alert_groups;
```

When you create a new priority group...

```
begin
	k2_alert.create_alert_priority_group (
		p_group_key=>'default',
		p_group_name=>'foo',
		p_user_id=>1);
end;
/
```

Five priorities are associated with the new group. You can add more or remove these as you please.

1.	critical
1.	high
1.	moderate
1.	low
1.	info

Priorities are assigned numeric values. The lower the value the higher the priority. Zero is reserved and should not be used.

With each priority you can…

1.	Enable or disable it. You can define the time period it is enabled using a cron expression.
1.	Set it as a default priority. The highest enabled priority will be used as the default when a priority is not specified.
1.	Have it trigger SMS texts (via an SMS email address) or emails to the members of the priority group.
1.	Set reminder interval properties.
1.	Set abandon interval properties.
1.	Set close interval properties.

A scheduled job checks the alerts once a minute to see if a new actions need to be taken.


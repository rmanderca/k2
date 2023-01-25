### A quick overview of alerting

Alerts have priorities. Priorities are defined within a priority group. When you create a new priority group 5 default priorities are defined.

1.	critical
1.	high
1.	moderate
1.	low
1.	info

Alert priorities are assigned a numeric value. The lower the value the higher the priority. Zero is reserved and should not be used.

Each priority can…

1.	Be enabled or disabled. You can define the time period it is enabled during using a cron expression.
1.	Be set as the default priority. The highest enabled priority will be used as the default when a priority is not specified.
1.	Trigger an attempt to send a SMS text (via an SMS email address) or an email to the members of the priority group.
1.	Set the reminder interval characteristics.
1.	Set the abandon interval characteristics.
1.	Set the close interval characteristics.

A scheduled job checks the alerts once a minute to see if a new action needs to be taken.


### ArcSQL

A large/rich library for features for doing many things. This library is installed by default when you install K2.

#### Installation

Create a user if you don't have one. 

Grant the user permissions  (```arcsql_grants.sql```) .

As the user install ArcSQL (```arcsql_install.sql```).

#### Contact groups

A contact group is made up of one or more members. Use ```arcsql.create_contact_group``` to create a new contact group.

Contact groups can be enabled or disabled. Contact groups can be put on hold. You can disable SMS texts for a contact group. You can define how long messages sit in the queue before being sent. You can define how long a queue can remain idle (no new messages) before sending the messages in the queue. You can set a threshold for the number of messages a queue can hold before they are sent.

Each contact in the group can have a single email and/or SMS address (which also needs to be an email for now). Most mobile providers have a way of sending texts to your phone via an email address. Google it. Use ```arcsql.add_contact_to_contact_group``` to add a contact to the contact group.

#### ArcSQL views

The ./arcsql_views folder contains a number of views which may be helpful. There are some additional grants required for these views which is why they are not necessarily installed by default. 

To install run ```./arcsql_views_grants.sql``` as an administor. Then Run ```./arcsql_views_install.sql``` as the schema owner.

#### ArcSQL logging

Log entries made with one of the ArcSQL logging calls (i.e debug, info, warn, error, fatal) are stored in the ```arcsql_log``` table. 

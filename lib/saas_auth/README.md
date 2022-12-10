
## Ethan's Oracle APEX SAAS_AUTH Package

This package is used to support the custom authentication form which is part of the K2 demo app.

### Credits
The code here has been inspired and borrowed from [this post](https://dgielis.blogspot.com/2017/08/create-custom-authentication-and.html) by Dimitri Gielis. 


### Change Log

**12/6/2022**

I added a new role called 'system' which can be used if a user_id is needed on the back end.

You might need a user_id on the back end to create an object which requires user_id (stat_bucket, contact_group, ...).

There was no way to assign a role, I added assign_user_role procedure as a way to do this.

I added a test file. It is just a start.



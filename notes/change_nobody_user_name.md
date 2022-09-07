# Change 'nobody' to 'guest' or some other name.

https://community.oracle.com/tech/developers/discussion/2193536/apex-nobody-account

* Create new Application Process in Shared Components.
* Process Point should be On Load: Before Header...
* Give it a name.
* Type is Execute Code
* Code is below.

```
if v('APP_USER') = 'nobody' then
    null;
    apex_custom_auth.set_user('Guest');
end if;
```

Note: this had the effect of breaking menu items which should have been protected from view to public users. The links associated with the menu items did not work, so the content was protected but the menu items still appeared, even when limited to non-public users. Version 21.1 on Oracle Cloud. In general I do not recommend doing this but understand that 'nobody' getting displayed when a user is not logged in is not good UI design.


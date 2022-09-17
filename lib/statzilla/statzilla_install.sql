
exec drop_package('statzilla_version');
exec drop_package('statzilla_b');
@statzilla_patch.sql
@statzilla_schema.sql
@statzilla_pkgh.sql
@statzilla_pkgb.sql
@statzilla_trg.sql

select 'APP install complete.' MESSAGE from dual;

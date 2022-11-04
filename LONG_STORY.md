# Long Story File

## 11/4/2022

send_email procedure initially uses arcsql_cfg.disable_email but ArcSQL is refreshed often by itself in development and ends up over-writing my apps version of arcsql_cfg. I have created k2_config.disable_email to reference instead which is far less likely to be over-written. One solution to all this is to always run a full app install when making a change to one of the libraries but this extends test cycles.
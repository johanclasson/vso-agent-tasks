# DbUp Migration

If you usually do migrations by comparing the schema of two databases, now is an opportunity for you to do something better.

Besides schema and security, a database also consists of data, and data is troublesome. Large tables take both time and resources to alter. A schema compare tool cannot always generate resource efficient migrations, nor take domain specific decisions like for example where the data in a dropped column should go instead.

Therefore, you will probably have to write at least some of your migrations yourself. If you think about it, the simple scenarios that a tool could generate migration scripts for is not that hard to write manually. Then why not make all migration scripts yourself?

## What is DbUp?

> *DbUp is a .NET library that helps you to deploy changes to SQL Server databases. It tracks which SQL scripts have been run already, and runs the change scripts that are needed to get your database up to date.*

Read more about DbUp in the [DbUp Documentation](http://dbup.readthedocs.io)

### Disclaimer

I am not the author of DbUp, but a mere user of that awesome library.

## How to Get Started

You will find the *DbUp Migration*-build and release task under the *deploy* category.

<img src="https://github.com/johanclasson/vso-agent-tasks/raw/master/DbUpMigration/example.png" alt="DbUp Migration User Interface" width="500" height="291">

### Parameters

| Name | Description |
|------|-------------|
| Connection String | The connection string used to connect to the database. |
| Script Folder Path | The path where the migration scripts to run are. |
| Journal To SQL Table | If set, each migration script will only be run once. A journal of the already run scripts is kept in the table `_SchemaVersions`. |
| Script File Filter | A regular expression used against the full path of the migration scripts to select which to run. |
| Transaction Strategy | Select one of *No Transactions*, *Transaction Per Script* and *Single Transaction*. |

#### An Example

Granted that you might have two type of scripts. Some that are meant to only be run once which are named like `1612312359-alterstuff.sql`. And some that are meant to be run on each deploy which are named like `everytime-storedprocedures.sql` .

You can configure two *DbUp Migration*-tasks. The first with *Journal To SQL Table* checked and with *Script File Filter* set to `\d{10}-.*`. The second with *Journal To SQL Table* unchecked and with *Script File Filter* set to `everytime-.*`.

*Since stored procedures do not keep data, it is convenient to let them be recreated during each deploy. That way you can update their scripts instead of having to add new with slightly modified content.* 

## Offline Scenarios

The *DbUp Migration*-task downloads the latest version of DbUp during its first execution. If you intend to use this task on a machine that has not got access to the Internet, you have to download the DbUp.dll manually and place it in the following path:

`%TEMP%\DatabaseMigration\dbup.*\lib\net35\DbUp.dll`

## Limitations

Although DbUp supports many databases, this extension currently only works with Microsoft SQL Server or Microsoft SQL Azure. You can contribute to this extension through its [GitHub Repository](https://github.com/johanclasson/vso-agent-tasks/tree/master/DbUpMigration).

## Release Notes

| When | Version | What |
|------|---------|------|
| 2016-11-07 | 0.10.5 | Fixed timeut issue. |
| 2016-10-23 | 0.10.3 | Fixed log issue on TFS2015, and added transaction selection feature. |
| 2016-10-20 | 0.9.0 | Initial release. |
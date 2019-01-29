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

<img src="https://github.com/johanclasson/vso-agent-tasks/raw/master/DbUpMigration/example.png" alt="DbUp Migration User Interface" width="500" height="445">

### Parameters

| Name | Description |
|------|-------------|
| Connection String | The connection string used to connect to the database. |
| Script Folder Path | The path where the migration scripts to run are. |
| Include Subfolders | Controls if scripts in subfolders are executed or not. |
| Script Execution Order | Select one of *Filename*, *File Path* and *Folder Structure*. |
| Script File Filter | A regular expression used against the full path of the migration scripts to select which to run. |
| Script Encoding | The encoding used to read script files from the file system. |
| Transaction Strategy | Select one of *No Transactions*, *Transaction Per Script* and *Single Transaction*. |
| Journal To SQL Table | If set, each migration script will only be run once. |
| Journal Table Name | The name of the table where the journal of the already run scripts are stored. |
| Perform Variable Substitution | If set, SQL variable substitution will be made with matching environment variables. |
| Variable Substitution Prefix | Filters what environment variables that is used in variable substitution. |
| Log Script Output | If information and warning logs raised from the SQL scripts should be visible in the log output. |

#### An Example

Granted that you might have two type of scripts. Some that are meant to only be run once which are named like `1612312359-alterstuff.sql`. And some that are meant to be run on each deploy which are named like `everytime-storedprocedures.sql` .

You can configure two *DbUp Migration*-tasks. The first with *Journal To SQL Table* checked and with *Script File Filter* set to `\d{10}-.*`. The second with *Journal To SQL Table* unchecked and with *Script File Filter* set to `everytime-.*`.

*Since stored procedures do not keep data, it is convenient to let them be recreated during each deploy. That way you can update their scripts instead of having to add new with slightly modified content.*

## Custom DbUp Scenarios

The *DbUp Migration*-task brings its own DbUp-dlls. If you intend to use the task with a custom version, you can place its dlls in the following paths:

* `%LOCALAPPDATA%\DatabaseMigration\dbup-core*\lib\net35\dbup-core.dll`
* `%LOCALAPPDATA%\DatabaseMigration\dbup-sqlserver*\lib\net35\dbup-sqlserver.dll`
* `%LOCALAPPDATA%\DatabaseMigration\System.Data.SqlClient.*\lib\netstandard1.3\System.Data.SqlClient.dll`

## Limitations

Although DbUp supports many databases, this extension currently only works with Microsoft SQL Server or Microsoft SQL Azure. You can contribute to this extension through its [GitHub Repository](https://github.com/johanclasson/vso-agent-tasks/tree/master/DbUpMigration).

## Release Notes

| When | Version | What |
|------|---------|------|
| 2019-01-29 | 1.3.0 | Updated DbUp tp 4.2.0. |
| 2018-07-24 | 1.2.0 | Disable DbUp variables when skipping variable substitution. |
| 2018-06-26 | 1.1.4 | Removed use of NuGet and bundled DbUp with task. |
| 2018-04-16 | 1.1.3 | Set DbUp version to 3.3.5. |
| 2018-04-03 | 1.1.2 | Added encoding selection feature. |
| 2018-02-01 | 1.0.1 | Fixed offline issue. |
| 2017-08-15 | 1.0.0 | Added variable substitution feature, and fixed sorting issue. |
| 2017-08-09 | 0.12.0 | Added scripts in subfolders-, and logging features. |
| 2017-04-27 | 0.11.0 | Added configurable journal table name feature. |
| 2017-04-13 | 0.10.7 | Fixed NuGet issue. |
| 2016-11-07 | 0.10.5 | Fixed timeout issue. |
| 2016-10-23 | 0.10.3 | Fixed log issue on TFS2015, and added transaction selection feature. |
| 2016-10-20 | 0.9.0 | Initial release. |

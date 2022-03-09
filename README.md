# ben-liquibase-nodejs

The docker build pipeline generates a container that can be used to build and manage database schemas through pipelines.

At the time of writing the container only supports MSSQL RDS, but could be extended to support many different types of database in the cloud or on saas solutions.

   ## Quick starter pre-requisits to run this build container in a pipeline. (not locally in developer mode)
    
   - You need to have provisioned a database.
   - You need to have provisioned an AWS secret containing user account access - values dictated under section "aws secret contents".
   - You need to provision an AWS role that the DevopsDeploymentRole can assume that has access to the customer assets account secrets.
   - You need to configure your folder structure for presql and liquibase sql files.
   - You need to configure one or more database in your json config file.
   - You need to add all relevant enviroment variables discussed in the following document to your pipeline.

   ## Whats installed in the container?

   - liquibase binaries.
   - mssql development tools and sqlcmd binary.
   - mssql driver.
   - node js.
   - node.js wrapper script custom written for bendigo bank tentacles pipeline & SQL development.

   ## How is the image used.

   - Locally using docker compose to build a development environment networked with a parallel container of the chosen db type.
   - Run via the gitlab runner pipeline against a cloud database instance.

   ##  Running in developer mode.

   At the time of writing there was only a single developer mode make file entry for mssql but it is anticipated that for each new database added for support to this image there will be a new development environment make file entry that follows the same pattern.

   make liquibase-development-mssql

   Will produce 2 networked containers, one will be this node js liquibase container and the second will be an mssql database. The 2 containers are networked together and the password, IP address and port are injected into the liquibase container so that it can instantly access the database. When the make command is run the user is instantly logged into the liquibase container and can begin development on SQL scripts or make amendments to the node js liquibase wrapper script to add support for new databases for example.

   The node js wrapper script commands can then be run manually, a detailed explanation of the wrapper script can be found later in this document.

   native binary commands can also be run against the db container example below. 

   sqlcmd -U sa -P $PASSWORD -S $IP,1433

   The environment variables used in development mode are all set for you and can be retrieved using.
```
   DEVELOPMENT - set to true.
   PASSWORD = set to Test1234@
   IP = set to the IP address of the target database container.
```
   The database config file when run locally always defaults to databases-local.json for any secrets params etc.

   ## Running the container in a gitlab runner pipeline.
  
   When run in the pipeline the container takes an arguement to the entry point of the docker container via the make file depending on the job to run - a detailed list of those commands is found later in this document under the wrapper script details.

   The pipeline run works with AWS secrets manager and at the time of writing database credentials must be stored in aws secrets. Possible alternate connections methods would need to be added to the script in future should there be a need for it - ie AD.
   
   The following steps are conducted by the wrapper script regardless of the command being run.

   1.   The script grabs the web identity token and federated role from the following environment variables AWS_ROLE_ARN and AWS_WEB_IDENTITY_TOKEN_FILE, these env vars are baked into the runners, the script then assumes the role.
   2.   The script then assumes a second non federated role from env variable AWS_ROLE, this variable should always be set to the DevopsDeploymentRole and be set via the gitlab pipeline variables.
   3.   The script then assumes a specific role in the customer AWS account terraformed by the application team that has access to the database secrets from the environment variable STSASSUMEROLE again set via gitlab environment variables.
   4.   The custom database json file is then loaded from the gitlab environment variable DATABASE_LOAD_FILE.
   5.   The script then iterates through the custom config file to retrieve database hostnames, ports secret names etc to connect to the cloud db instance and then perform the desired tasks. Further explanation of the wrapper script and config load is found below.

  # The wrapper script.

  The container works off a custom configuration file mounted into the build along with a liquibase change log and SQL script. It should be noted that the changelog references include files to run - no native liquibase commands are run as part of this process allowing for native database sql scripts only.

  ## Folder\File layout.

  An example layout to follow is found in the liquibase folder of this pipeline. In the example below we have a database-config.json file which would reference 2 databases database.name and database.name2. within each of these databases we have 2 folders liqui-sql and pre-sql, the sql scripts under pre-sql would be run once to instantiate the database instance and create any users\roles, the liqui-sql scripts would be managed\tracked by liquibase using metadata in the database tables to create\control the database schema going forward.

```
  liquibase
  databases-config.json
    database.name
      changelog.xml
      liqui-sql
        SQL files ...
      pre-sql
        SQL files ...
    database.name2
      changelog.xml
      liqui-sql
        SQL files ...
      pre-sql
        SQL files ...
```

   ## Supported script commands.

   The actual node js script is loaded into the /src directory of the container and consists of 3 files\objects index.js, process.js and execute.js.

   The script is run by running the following command and switches.

   node index.js >command<

   where command is one of the following commands
   
   These commands are tested and supported there after, how ever the scirpt is simply a wrapper script to run the sqlcmd\liqibase binaries and in theory could support anything the binaries can support should there be a need to in the future.

   ### node index.js status

   The status command is a liquibase command and produces a list of pending changesets with additional information that includes the id, author, and file path name. The status command does not modify the database, it will test connectivity.

   ### node index.js validate

   The validate command is a liquibase command and checks and identifies any possible errors in a changelog that can cause the update command to fail.

   ### node index.js presql

   The presql command is a non liquibase custom command that will run the presql scripts in the config file outside of liquibase with a native command line tool such as sqlcmd or pgadmin, presql jobs should only be run once and would be responsable for initial db & role creation.

   ### node index.js updateSQL

   The updateSQL command is a liquibase command that allows you to inspect the SQL Liquibase will run while using the update command. Think of it like terraform plan, its going to tell you the difference between the changelog and the actual schema and what its going to do about it if an update is run.

   ### node index.js update

   The update command deploys any changes that are in the changelog file and that have not been deployed to your database yet.
  
   ## Database custom configuration file explained.

```
   [
	  {
        "type": "mssql", 
           ### Should be mssql until new databases are added in this controls
               how the commands are constructed for the specific db type.
        "changeLogFile": "../liquibase/example.ms_example/changelog/changelog.xml",
           ### Path to the liquibase changelog file, paths are relative to the src 
               folder of the container, absolute paths are not supported.
        "host": "test.bendigo.au",
           ### Fully qualled name of the hostname of the database instance to connect to. 
               Overwrittan to local IP address in developer mode.
        "port": "1433",
           ### Database port number.
        "param.database": "mandatepayments",
           ### The actual database name within the instance. This is also passed to all 
               scripts as an environment variable with the prefix "param." dropped. Any 
               liquibase SQL scripts do not need to include the target database it will be 
               included in the url to the db for liquibase commands.
        "param.anything1": "example value 1",
        "param.anything2": "example value 1",        
        "param.anything3": "example value 1", 
           ### Any additional paramaters you want to pass to your script, again prefix "param."
             will be dropped.
        "secrets":[
            {"master": "master_secret_password"},
            ### Secrets manager secrets master must be set to the value of the secret that 
                holds the master password of the database for the first time this script is 
                run against a cloud database. there after the secret value can be replaced 
                with any secret credentials of other schema owners that you wish to use to 
                manage the schema. The master secret must contain the object values described 
                in ## AWS Secrets contents.
            {"param.password_ro": "ro_secret_password"},
            {"param.password_dbo": "dbo_secret_password"},
            {"param.password_rw": "rw_secret_password"}
            ### Any other secrets in this section other than master must be specified with the
                prefix "param.", these secrets will be retrieved and passed as environment
                variables to the scripts with the prefix dropped. In the examples above the 
                passwords for various db users are retrieved and added to the preql scripts 
                that create the initial users\roles. All secrets must contain the object values 
                described in ## AWS Secrets contents.

        ],
        "presql":[
            "../liquibase/example.ms_example/pre-sql/db_1_createdb.sql",
            "../liquibase/example.ms_example/pre-sql/db_2_create_roles.sql"
            ### The pre sql scripts are again relative to the /src dir of the container,
                the pre sql scripts are genrally written by the DBA team, currently there is 
                no versioning of these scripts but it could be something to look at in the 
                future per database instance. pre sql sc ripts are triggered by the presql 
                switch on the script and should be run only once.
        ]  
      }
   ]
```
   ## Changelog.xml file explained.

   In the following example we have 2 include files for schema\data SQL to be managed by liquibase, users simply need to create their SQL files in the folder structure and then reference them in the include stanza within the change log file to be managed by liquibase.

```
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog  
    xmlns="http://www.liquibase.org/xml/ns/dbchangelog"  
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"  
    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
                        http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-3.9.xsd"> 
    <include file="../work/liquibase/mandate_payments.ms_mandate_payments/liqui-sql/MANDATE_STATUS.sql"/>
    <include file="../work/liquibase/mandate_payments.ms_mandate_payments/liqui-sql/MANDATE_ACTION.sql"/>
</databaseChangeLog> 
```
   ## AWS Secrets contents.

   The value of the secret credentials must contain the following oject values.
```
   {
       username: value
       password: value
   }
```

   ## Adding new databases.

   To add a new database you would need to complete the following tasks.

   - Update the docker image to include the driver the liquibase binary requires for the new database type.
   - Update the docker image to include the new presql native command line tool for the presql steps for db\user creation.
   - Update the process.js script to include a new type switch on line 36.
   - Update the process.js script to include a new paramater construction arguement for the new native command line tool on line 29.
   - Update the process.js script to include a new function for the new db type to construct the commands for the db similar to the mssql function on line 71. The format of which will be near identical to mssql just the driver and native command bin\switches will change.
   - Upadate the database-local.json to include an additional example database of the new type and create the folder structure to match with example presql and changelog scripts.
   - Add a new local make file development job that includes the liqui container and db container of the new type.
   - Finally get tentacles pattern extended to support the new DB type.

   ## Tentacles pipeline documentation.


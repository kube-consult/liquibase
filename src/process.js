const Execute = require("./execute");
const AWS = require('aws-sdk');
const { threadId } = require("worker_threads");
AWS.config.update({region: 'ap-southeast-2'});

class Process {
	constructor(params = {}){
    const defaultParams = {
			liquibase: '/usr/local/bin/liquibase',
		};
		this.params = Object.assign({}, defaultParams, params);
    this.DEVELOPMENT = process.env.DEVELOPMENT;
    this.PASSWORD = process.env.PASSWORD;
    this.IP = process.env.IP;
    this.paramSQLCMD = ""
    this.paramLIQUI = ""
    this.cmd
    this.database
	}

  async processParams(arg) {
    this.arg = arg
    for (const prop in this.params.secrets) {
        await this.getSecretValueAWS(this.params.secrets[prop])
    }
    Object.keys(this.params).forEach(key => {
      if (key.includes('param')) {
        let strippedkey = key.replace('param.','')
        this.paramSQLCMD = `${this.paramSQLCMD} ${strippedkey}='${this.params[key]}'`
        this.paramLIQUI  = `${this.paramLIQUI} -D ${strippedkey}='${this.params[key]}'`
        if ( key === "param.database" ){
          this.database = this.params[key];
        }
      }
    });
    if (this.params.type == 'mssql'){
      await this.mssql()
    }
  }

  async getSecretValueAWS(secrets) {
    let secretsmanager = new AWS.SecretsManager();
    const secretname = Object.values(secrets)[0];
    const paramname = Object.keys(secrets)[0];
    console.log('Retrieving secret values for ' + secretname)
    const secret = {
      SecretId: secretname
    };
    let Promise = secretsmanager.getSecretValue(secret).promise();
    Promise.then(data => {
      if (paramname == "master") {
        this.params.username = JSON.parse(data.SecretString).username
        this.params.password = JSON.parse(data.SecretString).password
        if (this.DEVELOPMENT){
          this.params.username = "sa"
          this.params.password = this.PASSWORD
          this.params.host = this.IP
          this.params.port = "1433"
        }
      } else {
        this.params[paramname] = JSON.parse(data.SecretString).password
      }
    console.log('Successfully retrieved secret value')
    }).catch((err) => {
        console.log('fail', err);
        process.exit(1);
    });
    return Promise
  }

  async mssql(){
    console.log('Processing MSSQL command arguements and executing command:' + this.arg)
    if (this.arg == "presql"){
      for (const prop in this.params.presql) {   
        console.log("running presql script " + this.params.presql[prop])
        this.cmd = `/opt/mssql-tools/bin/sqlcmd \
                    -U ${this.params.username} \
                    -P '${this.params.password}' \
                    -S ${this.params.host},${this.params.port} \
                    -i ${this.params.presql[prop]} \
                    -v ${this.paramSQLCMD}`;
        await this.exec();
      }
    } else {
      this.cmd = `${this.params.liquibase} \
                  --logLevel=debug \
                  --changeLogFile=${this.params.changeLogFile} \
                  --username=${this.params.username} \
                  --password='${this.params.password}' \
                  --driver=com.microsoft.sqlserver.jdbc.SQLServerDriver \
                  --classpath=/usr/local/lib/liquibase/mssql-jdbc-9.4.0.jre11.jar \
                  --url='jdbc:sqlserver://${this.params.host}:${this.params.port};databaseName=${this.database}' ${this.arg} ${this.paramLIQUI}`
      await this.exec();   
    }
  }

  async exec(){
    await Execute()
    .run(this.cmd)
    .then(() => 
       console.log('Ran command successfully'))
    .catch((err) => {
      const output = JSON.parse(JSON.stringify(err).replace(/passwor\S+=\S+/g,"password=###MASKED###"))
      console.log('failed to run command.',output);
      process.exit(1);
    });
  }
}

module.exports = params => new Process(params);

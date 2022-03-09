const Process = require("./process");
const fs = require("fs");
const util = require("util");
const readFileAsync = util.promisify(fs.readFile);
const AWS = require('aws-sdk');
AWS.config.update({region: 'ap-southeast-2'});

class Config {
  constructor() {
    this.conf;
    this.DEVELOPMENT = process.env.DEVELOPMENT;
    this.DBLOAD = process.env.DATABASE_LOAD_FILE;
    this.Args = process.argv.slice(0,4);
    this.AllowedCommands = ['status','validate','presql','updateSQL','update'];
    this.STSASSUMEROLE = process.env.STSASSUMEROLE;
    this.AWS_ACCOUNT_ID = process.env.AWS_ACCOUNT_ID
    this.AWS_ROLE = process.env.AWS_ROLE;
    this.AWS_ROLE_ARN = process.env.AWS_ROLE_ARN;
    this.AWS_WEB_IDENTITY_TOKEN_FILE = process.env.AWS_WEB_IDENTITY_TOKEN_FILE;
  }

  async loadFile() {
    this.evaluateArgs()
    if (this.DEVELOPMENT) {
      this.DBLOAD = "databases-local.json"
    } 
    const data = await readFileAsync("/work/liquibase/" + this.DBLOAD, "utf8");
    this.conf = JSON.parse(data);
    if (!this.DEVELOPMENT){
      await this.assumeRoleWebIdentityAWS(this.AWS_ROLE_ARN,this.AWS_WEB_IDENTITY_TOKEN_FILE)
      await this.assumeRoleAWS("arn:aws:iam::" + this.AWS_ACCOUNT_ID + ":role/" + this.AWS_ROLE)
      await this.assumeRoleAWS("arn:aws:iam::" + this.AWS_ACCOUNT_ID + ":role/" + this.STSASSUMEROLE)
    }
  }

  evaluateArgs(){
    if ((this.AllowedCommands.indexOf(this.Args[2]) == -1) || (((this.Args[3])))) {
      console.log('\n',"Usage!",'\n\n',"Accepted arguments are " + this.AllowedCommands)
      console.log('\n','\n'," node index.js status    ->>  The status command produces a list of pending changesets with additional information that includes the id, author, and file path name. The status command does not modify the database.",'\n','\n'," \
node index.js validate  ->>  The validate command checks and identifies any possible errors in a changelog that can cause the update command to fail.",'\n','\n'," \
node index.js presql    ->>  The presql command is a non liquibase custom command that will run the presql scripts in the config file outside of liquibase with a native command line tool such as sqlcmd or pgadmin, presql jobs should only be run once and would be responsable for initial db & role creation.",'\n','\n'," \
node index.js updateSQL ->>  The updateSQL command is a helper command that allows you to inspect the SQL Liquibase will run while using the update command.",'\n','\n'," \
node index.js update    ->>  The update command deploys any changes that are in the changelog file and that have not been deployed to your database yet.",'\n')
      process.exit(1)
    }
  }

  async assumeRoleAWS(roleArn){
    let sts = new AWS.STS();
    let Promise = await sts.assumeRole({
      RoleArn: roleArn,
      RoleSessionName: 'secretsManagerAssume'
    }).promise().then(data => {
      console.log('Assumed role successfully :' + roleArn);
      AWS.config.update({
        accessKeyId: data.Credentials.AccessKeyId,
        secretAccessKey: data.Credentials.SecretAccessKey,
        sessionToken: data.Credentials.SessionToken
      });
    }).catch(err => {
      console.log('Cannot assume role', err);
      process.exit(1);
    });
    return Promise
  }

  async assumeRoleWebIdentityAWS(roleArn,webIdentityToken){
    let sts = new AWS.STS();
    const token = await readFileAsync(webIdentityToken, "utf8");
    let Promise = await sts.assumeRoleWithWebIdentity({
      RoleArn: roleArn,
      RoleSessionName: 'initialAssume',
      WebIdentityToken: token
    }).promise().then(data => {
      console.log('Assumed webIdentity role successfully :' + roleArn);
      AWS.config.update({
        accessKeyId: data.Credentials.AccessKeyId,
        secretAccessKey: data.Credentials.SecretAccessKey,
        sessionToken: data.Credentials.SessionToken
      });
    }).catch((err) => {
      console.log('Cannot assume role', err);
      process.exit(1);
    });
    return Promise
  }

  createInstances() {
    this.conf.forEach((params) => {
      console.log('\n' + '####################################################' + '\n' +'## Processing ' + params['param.database'] )
      Process(params)
        .processParams(this.Args[2])
        .then(() => console.log('## Finished processing ' + params['param.database'] +  ' successfully' + '\n' + '####################################################' + '\n'))
        .catch((err) => { 
          console.log('fail', err);
          process.exit(1);
        })      
    })
  }
}

const configs = new Config();
const init = async () => {
  try {
    await configs.loadFile();
    configs.createInstances();
  } catch (err) {
    console.log(err);
    process.exit(1);
  }
}
init();
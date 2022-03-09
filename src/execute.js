const childProcess = require('child_process');

class Execute {
	constructor() {
	}
	exec(command, options = {}) {
		let child;
		let promise = new Promise((resolve, reject) => {
			child = childProcess
				.exec(command, options, async (error, stdout, stderr) => {
					if (error) {
						error.stderr = stderr
						return reject(error);
					}
					console.log(stdout)
					resolve({stdout: stdout});
				});
		});
		promise.child = child;
		return promise;
	}
    run(cmd) {
        return this.exec(`${cmd}`);
	}
}
module.exports = params => new Execute();
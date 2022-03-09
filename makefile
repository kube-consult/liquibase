DRY_RUN ?= false
REPOSITORY_URL = 
# Image name will be combined with your destination docker registry.
IMAGE_NAME=$(REPOSITORY_URL)/$(APP_NAME_TARGET)
RUNNER = docker-compose run -T --rm
RUNNER-HADOLINT = $(RUNNER) hadolint
RUNNER-JFROG = docker-compose -f docker-compose-jfrog.yml run --rm jfrog

SA_PASSWORD = Test1234@@
RUNNER-LIQUIBASE = docker-compose run -e PASSWORD='$(SA_PASSWORD)' -e DEVELOPMENT='true' -e IP="`docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' mssql`" --entrypoint "" liquibase sh
RUNNER-MSSQL = docker-compose run -d --name 'mssql' -e ACCEPT_EULA='Y' -e SA_PASSWORD='$(SA_PASSWORD)' -e MSSQL_PID='Express' mssql
RUNNER-RM-LIQUIBASE = docker-compose rm -s --force liquibase
RUNNER-RM-MSSQL = docker-compose rm -s --force  mssql
#JFROG_API_KEY = ${JFROG_API_KEY_NONPROD}
RUNNER-LIQUIBASE-2 = $(RUNNER) liquibase2

.env:
	cp .env.template .env
.PHONY: .env

# Used to run a lint on Commit. Please see readme to set this up locally on your machine.
pre-commit:
	make lint
.PHONY: pre-commit

# Runs a Lint on your DockerFile and docker-compose files giving you a report on how well your DockerFile is coded.
lint: _env-REPOSITORY_URL _env-APP_NAME _env-BUILD_VERSION

	if [ -f docker-compose.yml ]; then \
		docker-compose -f docker-compose.yml config -q; \
	fi

	# Check for the usage of the "latest" tag
	for file in docker-compose*.yml; do \
		$(RUNNER-HADOLINT) yq read $${file} services.*.image | grep :latest \
			&& echo !!ERROR cannot use \"latest\" in $${file}!! && exit 1 \
			|| echo $${file} passed docker-compose test; \
	done
.PHONY: lint

# Test your DockerFile
test: build
	# To be implemented
.PHONY: build

# The Primary command to run a Docker Build. Customise this based on your requirments (DockerFile Build or Pull Push Build)
build:
	# Use make pull-build if you don't need a Dockerfile to build the image
	make file-build
.PHONY: build

# "make pull-build" will pull your required base image and push directly to Artifactory, not running the local DockerFile.
# This is useful where you just require the public image as is, in Artifactory.
pull-build: _env-SOURCE_REPOSITORY_URL _env-APP_NAME _env-BUILD_VERSION _env-IMAGE_NAME _env-CI_PIPELINE_IID
	docker pull $(SOURCE_REPOSITORY_URL)/$(APP_NAME):$(BUILD_VERSION)
	docker tag $(SOURCE_REPOSITORY_URL)/$(APP_NAME):$(BUILD_VERSION) $(IMAGE_NAME):$(BUILD_VERSION)-$(CI_PIPELINE_IID)
	docker tag $(SOURCE_REPOSITORY_URL)/$(APP_NAME):$(BUILD_VERSION) $(IMAGE_NAME):$(BUILD_VERSION)
	docker tag $(SOURCE_REPOSITORY_URL)/$(APP_NAME):$(BUILD_VERSION) $(IMAGE_NAME):latest
.PHONY: pull-build

# "make file-build" will run the Docker Build using the DockerFile in your repository.
# This requires IMAGE_NAME SOURCE_REPOSITORY_URL BUILD_VERSION APP_NAME environment vars to be declared if running locally.
file-build: _env-SOURCE_REPOSITORY_URL _env-APP_NAME _env-BUILD_VERSION _env-IMAGE_NAME _env-CI_PIPELINE_IID _env-JFROG_URL _env-JFROG_API_KEY _env-JFROG_USER_DEV
	docker build \
		-t $(IMAGE_NAME):latest \
		--build-arg SOURCE_REPOSITORY=$(SOURCE_REPOSITORY_URL) \
		--build-arg VERSION=$(BUILD_VERSION) \
		--build-arg APP_NAME=$(APP_NAME) \
		--build-arg JFROG_URL=$(JFROG_URL) \
		--build-arg JFROG_USER_DEV=$(JFROG_USER_DEV) \
		--build-arg JFROG_API_KEY=$(JFROG_API_KEY) \
	.
	docker tag $(IMAGE_NAME):latest $(IMAGE_NAME):$(BUILD_VERSION)-$(CI_PIPELINE_IID)
.PHONY: file-build

publish: .env build _env-DEV_REPOSITORY _env-CI_PROJECT_NAME _env-CI_PIPELINE_IID _env-JFROG_URL _env-JFROG_API_KEY _env-JFROG_USER _env-DRY_RUN _env-BUILD_VERSION _env-IMAGE_NAME
	$(RUNNER-JFROG) jfrog rt docker-push $(IMAGE_NAME):$(BUILD_VERSION)-$(CI_PIPELINE_IID) $(DEV_REPOSITORY) \
		--build-name=$(CI_PROJECT_NAME) --build-number=$(CI_PIPELINE_IID) \
		--url $(JFROG_URL) --apikey $(JFROG_API_KEY) --user $(JFROG_USER)

	$(RUNNER-JFROG) jfrog rt build-publish $(CI_PROJECT_NAME) $(CI_PIPELINE_IID) \
		--url $(JFROG_URL) --apikey $(JFROG_API_KEY) --user $(JFROG_USER) -dry-run=$(DRY_RUN)
.PHONY: publish

# Used within the GitLab Pipeline to run a JFrog Xray Scan on your container to find any Vulnerabilities
scan: .env _env-CI_PROJECT_NAME _env-JFROG_URL _env-JFROG_API_KEY _env-JFROG_USER _env-CI_PIPELINE_IID
	$(RUNNER-JFROG) make _scan
.PHONY: scan

_scan:
	jfrog rt build-scan $(CI_PROJECT_NAME) $(CI_PIPELINE_IID) \
		--url $(JFROG_URL) --apikey $(JFROG_API_KEY) --user $(JFROG_USER) > $(XRAY_SCAN_REPORT) || true

	python3 $$XRAY_CONVERTER $(XRAY_SCAN_REPORT)
.PHONY: _scan

promote-test: .env build _env-TEST_REPOSITORY _env-CI_PROJECT_NAME _env-CI_PIPELINE_IID _env-JFROG_URL _env-JFROG_API_KEY _env-JFROG_USER
	$(RUNNER-JFROG) jfrog rt build-promote $(CI_PROJECT_NAME) $(CI_PIPELINE_IID) $(TEST_REPOSITORY) --copy=true --source-repo=$(DEV_REPOSITORY) \
		--url $(JFROG_URL) --apikey $(JFROG_API_KEY) --user $(JFROG_USER)
.PHONY: scan

promote-prod: .env build _env-PROD_REPOSITORY _env-CI_PROJECT_NAME _env-CI_PIPELINE_IID _env-JFROG_URL _env-JFROG_API_KEY _env-JFROG_USER
	$(RUNNER-JFROG) jfrog rt build-promote $(CI_PROJECT_NAME) $(CI_PIPELINE_IID) $(PROD_REPOSITORY) --copy=true --source-repo=$(TEST_REPOSITORY) \
		--url $(JFROG_URL) --apikey $(JFROG_API_KEY) --user $(JFROG_USER)
.PHONY: scan

# Checks if your local Environment Vars are setup.
_env-%:
	@ if [ "${${*}}" = "" ]; then \
			echo "Environment variable $* not set"; \
			echo "Please check README.md for variables required"; \
			exit 1; \
	fi

# -e TF_VAR_aws_account_id=$(AWS_ACCOUNT_ID) 
# -e TF_VAR_aws_role=$(AWS_ROLE) 

liquibase-development-mssql:
	aws-adfs login --adfs-host=adfs.bendigoadelaide.com.au --region ap-southeast-2
	$(RUNNER-RM-LIQUIBASE)
	$(RUNNER-RM-MSSQL)
	$(RUNNER-MSSQL)
	${RUNNER-LIQUIBASE} 
.PHONY: liquibase-development-mssql

liquibase2:
	${RUNNER-LIQUIBASE-2} 
.PHONY: liquibase2
ARG SOURCE_REPOSITORY
ARG APP_NAME
ARG JFROG_USER_DEV
ARG JFROG_API_KEY

###  Project build
FROM ${SOURCE_REPOSITORY}/${APP_NAME}:latest

ENV LIQUIBASE_VERSION=4.2.0 \
    LIQUIBASE_PREFIX=/usr/local/lib \
    LIQUIBASE_BIN=/usr/local/bin \
    LIQUIBASE_NODEJS=/src \
    JDBC_POSTGRES_VERSION=42.2.18 \
    JDBC_MYSQL_VERSION=2.7.1 \
    PATH=/opt/mssql-tools/bin:/usr/local/bin:/usr/sbin:/usr/bin:/src:$PATH \
    NODE_PATH=/usr/lib/node_modules 
WORKDIR /tmp
RUN set -x \
##############################################################################
# Install dependencies
##############################################################################
    && apk add --update --no-cache \
        nodejs \
        npm \
        # bash \
        curl \
        gnupg \
        openjdk11 \
    # Packages
    && npm install -g aws-sdk \
    # && npm install -g node-liquibase \
##############################################################################
# Install Liquibase
##############################################################################
    && mkdir ${LIQUIBASE_PREFIX}/liquibase \
    && curl -o /tmp/liquibase-${LIQUIBASE_VERSION}.tar.gz -sSL https://github.com/liquibase/liquibase/releases/download/v${LIQUIBASE_VERSION}/liquibase-${LIQUIBASE_VERSION}.tar.gz \
    && tar -zxf /tmp/liquibase-${LIQUIBASE_VERSION}.tar.gz -C ${LIQUIBASE_PREFIX}/liquibase \
    && sed -i "s|bash$|ash|" ${LIQUIBASE_PREFIX}/liquibase/liquibase \
    && chmod +x ${LIQUIBASE_PREFIX}/liquibase/liquibase \
    && ln -s ${LIQUIBASE_PREFIX}/liquibase/liquibase ${LIQUIBASE_BIN} \
    && mkdir /changelogs \
##############################################################################
# Install JDBC drivers postrgess 
##############################################################################

##############################################################################
# Install postgres clienbt psql
##############################################################################
    # && apk add --update --no-cache postgresql-client \

##############################################################################
# Install and set up MSSQL tools driver and driver.
##############################################################################
    && curl -O https://download.microsoft.com/download/e/4/e/e4e67866-dffd-428c-aac7-8d28ddafb39b/msodbcsql17_17.8.1.1-1_amd64.apk \
    && curl -O https://download.microsoft.com/download/e/4/e/e4e67866-dffd-428c-aac7-8d28ddafb39b/mssql-tools_17.8.1.1-1_amd64.apk \
    && curl -O https://download.microsoft.com/download/e/4/e/e4e67866-dffd-428c-aac7-8d28ddafb39b/msodbcsql17_17.8.1.1-1_amd64.sig \
    && curl -O https://download.microsoft.com/download/e/4/e/e4e67866-dffd-428c-aac7-8d28ddafb39b/mssql-tools_17.8.1.1-1_amd64.sig \
    && curl https://packages.microsoft.com/keys/microsoft.asc  | gpg --import - \
    && gpg --verify msodbcsql17_17.8.1.1-1_amd64.sig msodbcsql17_17.8.1.1-1_amd64.apk \
    && gpg --verify mssql-tools_17.8.1.1-1_amd64.sig mssql-tools_17.8.1.1-1_amd64.apk \
    && apk add --allow-untrusted msodbcsql17_17.8.1.1-1_amd64.apk \
    && apk add --allow-untrusted mssql-tools_17.8.1.1-1_amd64.apk \
    && curl -O https://go.microsoft.com/fwlink/?linkid=2168494
    COPY Drivers/mssql-jdbc-9.4.0.jre11.jar ${LIQUIBASE_PREFIX}/liquibase/
##############################################################################
# Copy node js wrapper scripts.
##############################################################################
    RUN mkdir /src
    COPY src/* ${LIQUIBASE_NODEJS}/
##############################################################################
# Clean up
##############################################################################
    RUN apk del \
         curl \
    && rm -rf \
        /tmp/* \
        /var/cache/apk/*
##############################################################################
# Docker stuff.
##############################################################################
WORKDIR /src
ENTRYPOINT ["/usr/bin/node","/src/index.js"]
RUN addgroup -g 1000 -S liquibase && adduser -u 1000 -S liquibase -G liquibase
USER liquibase



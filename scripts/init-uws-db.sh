#!/bin/bash -ex

# Initialize the local UWS PostgreSQL database so the app can create the schema
# and tables it expects when the service boots.
#
# This script is intended for the local docker stack used by this repo and
# targets the PostgreSQL container named "uws-db".
#
# Usage:
#   ./scripts/init-uws-db.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKER_DIR="$ROOT_DIR/docker"
COMPOSE_FILE="$DOCKER_DIR/docker-compose.yml"

if docker compose version >/dev/null 2>&1; then
    compose_cmd() {
        docker compose -f "$COMPOSE_FILE" "$@"
    }
else
    compose_cmd() {
        docker-compose -f "$COMPOSE_FILE" "$@"
    }
fi

CID=$(compose_cmd ps -q uws-db)
if [ -z "$CID" ]; then
    echo "uws-db is not running. Start the stack first: cd $DOCKER_DIR && docker compose up -d"
    exit 1
fi

# This is the schema expected by the Java UWS init action.
docker exec -i "$CID" bash -lc "psql -U postgres -d postgres <<'SQL'
CREATE SCHEMA IF NOT EXISTS uws;

CREATE TABLE IF NOT EXISTS uws.job (
    jobid varchar(16) NOT NULL,
    runid varchar,
    ownerid varchar,
    executionphase varchar(16) NOT NULL,
    executionduration bigint NOT NULL,
    creationtime timestamp NOT NULL,
    destructiontime timestamp,
    quote timestamp,
    starttime timestamp,
    endtime timestamp,
    error_summarymessage varchar,
    error_type varchar(16),
    error_documenturl varchar,
    requestpath varchar,
    remoteip varchar,
    jobinfo_content text[],
    jobinfo_contenttype varchar,
    jobinfo_valid smallint,
    deletedbyuser smallint DEFAULT 0,
    lastmodified timestamp NOT NULL,
    PRIMARY KEY (jobid)
);

CREATE TABLE IF NOT EXISTS uws.jobdetail (
    jobid varchar(16) NOT NULL,
    name varchar(128) NOT NULL,
    value text,
    PRIMARY KEY (jobid, name),
    CONSTRAINT fk_jobdetail_job FOREIGN KEY (jobid) REFERENCES uws.job(jobid)
);

CREATE TABLE IF NOT EXISTS uws.jobparameter (
    jobid varchar(16) NOT NULL,
    name varchar(128) NOT NULL,
    value text,
    PRIMARY KEY (jobid, name),
    CONSTRAINT fk_jobparameter_job FOREIGN KEY (jobid) REFERENCES uws.job(jobid)
);

CREATE TABLE IF NOT EXISTS uws.jobresult (
    jobid varchar(16) NOT NULL,
    name varchar(128) NOT NULL,
    value text,
    PRIMARY KEY (jobid, name),
    CONSTRAINT fk_jobresult_job FOREIGN KEY (jobid) REFERENCES uws.job(jobid)
);
SQL"

# The repo also includes a database availability table used by the UWS job availability checks.
docker exec -i "$CID" bash -lc "psql -U postgres -d postgres <<'SQL'
CREATE TABLE IF NOT EXISTS public.jobavailability (
    value char(1) NULL
);
SQL"

echo "UWS database initialized."

#!/bin/bash -ex

# Initialize the TAP metadata tables in the PostgreSQL tap-schema container.
# This matches the schema contract expected by the current cadc-tap-schema
# dependency, which is PostgreSQL-oriented.
#
# Usage:
#   ./scripts/init-tap-schema.sh

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

CID=$(compose_cmd ps -q tap-schema-db)
if [ -z "$CID" ]; then
    echo "tap-schema-db is not running. Start the stack first: cd $DOCKER_DIR && docker compose up -d"
    exit 1
fi

for i in $(seq 1 30); do
    if docker exec -i "$CID" env PGPASSWORD=TAP_SCHEMA psql -U TAP_SCHEMA -d tap_schema -c 'SELECT 1' >/dev/null 2>&1; then
        break
    fi
    echo "Waiting for PostgreSQL tap-schema-db to accept connections... ($i/30)"
    sleep 2
done

docker exec -i "$CID" env PGPASSWORD=TAP_SCHEMA psql -U TAP_SCHEMA -d tap_schema <<'SQL'
CREATE SCHEMA IF NOT EXISTS tap_schema;

CREATE TABLE IF NOT EXISTS tap_schema.schemas11 (
    schema_name varchar(64) NOT NULL,
    utype varchar(512),
    description varchar(512),
    schema_index integer,
    owner_id varchar(256),
    read_anon integer,
    read_only_group varchar(128),
    read_write_group varchar(128),
    api_created integer,
    PRIMARY KEY (schema_name)
);

CREATE TABLE IF NOT EXISTS tap_schema.tables11 (
    schema_name varchar(64) NOT NULL,
    table_name varchar(128) NOT NULL,
    table_type varchar(8) NOT NULL,
    view_target varchar(128),
    utype varchar(512),
    description varchar(512),
    table_index integer,
    owner_id varchar(256),
    read_anon integer,
    read_only_group varchar(128),
    read_write_group varchar(128),
    api_created integer,
    PRIMARY KEY (table_name)
);

CREATE TABLE IF NOT EXISTS tap_schema.columns11 (
    table_name varchar(128) NOT NULL,
    column_name varchar(64) NOT NULL,
    utype varchar(512),
    ucd varchar(64),
    unit varchar(64),
    description varchar(512),
    datatype varchar(64) NOT NULL,
    arraysize varchar(16),
    xtype varchar(64),
    "size" integer,
    principal integer NOT NULL,
    indexed integer NOT NULL,
    std integer NOT NULL,
    column_index integer,
    column_id varchar(32),
    owner_id varchar(256),
    read_anon integer,
    read_only_group varchar(128),
    read_write_group varchar(128),
    PRIMARY KEY (table_name, column_name)
);

CREATE TABLE IF NOT EXISTS tap_schema.keys11 (
    key_id varchar(64) NOT NULL,
    from_table varchar(128) NOT NULL,
    target_table varchar(128) NOT NULL,
    utype varchar(512),
    description varchar(512),
    PRIMARY KEY (key_id)
);

CREATE TABLE IF NOT EXISTS tap_schema.key_columns11 (
    key_id varchar(64) NOT NULL,
    from_column varchar(64) NOT NULL,
    target_column varchar(64) NOT NULL
);

CREATE TABLE IF NOT EXISTS tap_schema.obscore (
    obs_publisher_did varchar(256) NOT NULL,
    obs_id varchar(128),
    obs_collection varchar(32),
    dataproduct_type varchar(5),
    calib_level varchar(20),
    access_url text,
    access_format varchar(16),
    access_estsize bigint,
    target_name varchar(256),
    s_ra double precision,
    s_dec double precision,
    s_fov double precision,
    s_region text,
    s_resolution double precision,
    t_min timestamp,
    t_max timestamp,
    t_exptime double precision,
    t_resolution double precision,
    em_min double precision,
    em_max double precision,
    em_res_power double precision,
    o_ucd varchar(35),
    pol_states varchar(64),
    facility_name varchar(32),
    instrument_name varchar(32),
    PRIMARY KEY (obs_publisher_did)
);

CREATE UNIQUE INDEX IF NOT EXISTS columns_column_id
    ON tap_schema.columns11 (column_id)
    WHERE column_id IS NOT NULL;
SQL

# Seed the minimal TAP_SCHEMA record expected by the service.
docker exec -i "$CID" env PGPASSWORD=TAP_SCHEMA psql -U TAP_SCHEMA -d tap_schema <<'SQL'
INSERT INTO tap_schema.schemas11 (
    schema_name, utype, description, schema_index, owner_id, read_anon, read_only_group, read_write_group, api_created
)
SELECT 'TAP_SCHEMA', NULL, 'TAP metadata schema', 1, NULL, 0, NULL, NULL, 1
WHERE NOT EXISTS (SELECT 1 FROM tap_schema.schemas11 WHERE schema_name = 'TAP_SCHEMA');

INSERT INTO tap_schema.tables11 (
    schema_name, table_name, table_type, view_target, utype, description, table_index,
    owner_id, read_anon, read_only_group, read_write_group, api_created
)
SELECT 'TAP_SCHEMA', 'TAP_SCHEMA.obscore', 'table', NULL, NULL, 'ObsCore table', 1,
       NULL, 0, NULL, NULL, 1
WHERE NOT EXISTS (SELECT 1 FROM tap_schema.tables11 WHERE table_name = 'TAP_SCHEMA.obscore');

INSERT INTO tap_schema.columns11 (
    table_name, column_name, utype, ucd, unit, description, datatype, arraysize, xtype,
    "size", principal, indexed, std, column_index, column_id, owner_id, read_anon,
    read_only_group, read_write_group
)
SELECT 'TAP_SCHEMA.obscore', 'obs_publisher_did', 'obscore:Curation.PublisherDID', 'meta.ref.url;meta.curation', NULL,
       'publisher dataset identifier', 'adql:VARCHAR', '256', NULL, NULL, 1, 1, 1, 1, NULL, NULL, 0, NULL, NULL
WHERE NOT EXISTS (
    SELECT 1 FROM tap_schema.columns11 WHERE table_name = 'TAP_SCHEMA.obscore' AND column_name = 'obs_publisher_did'
);
SQL

echo "TAP schema initialized on PostgreSQL."

# LSST TAP Service

This repository contains the LSST TAP service.  It is based on the CADC TAP service
code and uses this as a dependency, and then adds special logic to work with QServ.

## Build and local execution

The project is a Java/Gradle application packaged as a WAR and deployed locally with
Docker Compose. The recommended local workflow is:

1. Make sure you have Docker, Docker Compose, Java 11, and Git installed.
2. Build the WAR:

   `./gradlew clean war`

3. Build the Docker images and start the local stack:

   `./build.sh`

   This script does the following:
   - finds the WAR generated in `build/libs`
   - copies it into the Docker context
   - builds the app and DB images
   - runs `docker compose up -d --build`
   - waits for the containers to become healthy
   - initializes the PostgreSQL UWS DB and TAP metadata schema

4. If you want to run the steps manually instead of through `./build.sh`, use:

   ```bash
   cd docker
   docker compose down -v --remove-orphans
   docker compose up -d --build
   ./waitForContainersReady.sh
   cd ..
   ./scripts/init-uws-db.sh
   ./scripts/init-tap-schema.sh
   ```

5. Validate the service is responding:

   ```bash
   curl -i http://localhost:8080/tap/availability
   ```

6. Validate a TAP query:

   ```bash
   curl -L -d 'QUERY=SELECT+TOP+1+*+FROM+TAP_SCHEMA.obscore&LANG=ADQL' http://localhost:8080/tap/sync
   ```

The service is available at `http://localhost:8080/tap`.

### Important notes for local execution

- Use `docker compose`, not the legacy `docker-compose` command.
- The generated WAR must be named `tap.war` so Tomcat exposes the application under `/tap`.
- The local stack includes:
  - `mock-qserv` (MySQL-based mock backend)
  - `uws-db` (PostgreSQL for UWS job state)
  - `tap-schema-db` (PostgreSQL for TAP metadata)
  - `lsst-tap-service` (Tomcat app container)
- The TAP metadata schema is created in PostgreSQL because the currently pinned `cadc-tap-schema`
  dependency expects the PostgreSQL-compatible schema layout (`schemas11`, `tables11`, `columns11`, etc.).

## Deployment

### Docker
After the [Build and local execution](#build-and-local-execution) steps above, the service is ready for use locally. You can then point a TAP client or tool (for example `curl`, TOPCAT, or pyvo) to:

`http://localhost:8080/tap`

### Pushing to hub.docker.com

After building a set of images (with the `dev` tag), and testing them out, you
can run the `./push.sh` script providing a docker tag to push to.  For example

`./push.sh new_feature_test`

will create a set of containers with the tag `new_feature_test`.  These can
then be used in a k8s environment with the Helm chart located here:

https://github.com/lsst-sqre/charts/tree/master/cadc-tap

## Configuration

### BigQuery Backend

When using the BigQuery backend, the following system properties must be configured:

- `tap.bigquery.project` - BigQuery project ID (required)
- `tap.bigquery.dataset` - BigQuery dataset name (required)
- `tap.bigquery.schema` - Schema name for ADQL table mappings (optional, default: `ppdb`)

The `tap.bigquery.schema` property determines how table names in ADQL queries are mapped to BigQuery tables. 
For example, if set to `ppdb_lsstcam`, then queries using `ppdb_lsstcam.DiaSource` will be mapped to the `DiaSource` table in the configured BigQuery dataset.

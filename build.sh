#!/bin/bash -ex
# Build the TAP service, build Docker images, deploy the local stack,
# initialize the local databases, wait for readiness, run the availability
# checks, and leave the environment ready to exercise the TAP service.
# Run: ./gradlew clean war && ./build.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

WAR_PATH="$(find build/libs -maxdepth 1 -type f -name 'tap*.war' | head -n 1)"
if [ -z "$WAR_PATH" ]; then
    echo "No WAR file found in build/libs. Run ./gradlew clean war first." >&2
    exit 1
fi

rm -f docker/*.war
cp "$WAR_PATH" docker/

docker build . -t lsstdax/lsst-tap-service:dev -f docker/Dockerfile.lsst-tap-service
docker build . -t lsstdax/uws-db:dev -f docker/Dockerfile.uws-db
docker build . -t lsstdax/mock-qserv:dev -f docker/Dockerfile.mock-qserv

if docker compose version >/dev/null 2>&1; then
    COMPOSE=(docker compose)
else
    COMPOSE=(docker-compose)
fi

cd "$ROOT_DIR/docker"
"${COMPOSE[@]}" down -v --remove-orphans || true
"${COMPOSE[@]}" up -d --build

./waitForContainersReady.sh

# Initialize the metadata databases used by the service.
# The UWS PostgreSQL and TAP schema MySQL init scripts are run separately because
# they depend on the database containers being online and ready.
cd "$ROOT_DIR"
./scripts/init-uws-db.sh || true
./scripts/init-tap-schema.sh || true

echo "TAP stack started. Validate manually with:"
echo "  curl -L -d 'QUERY=SELECT+TOP+1+*+FROM+TAP_SCHEMA.obscore&LANG=ADQL' http://localhost:8080/tap/sync"
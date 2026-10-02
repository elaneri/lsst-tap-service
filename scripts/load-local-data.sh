#!/bin/bash -ex

# Load or verify the local demo data packaged in this repo.
#
# Note: the mock-qserv image already executes the SQL files in docker/mock-qserv/
# via /docker-entrypoint-initdb.d when the container is created. Re-running them
# as root is not supported by this image because the root account is locked down.
#
# Usage:
#   ./scripts/load-local-data.sh [mock|oracle|all]
#
# - mock: verifies that the mock-qserv database was initialized by the image
# - oracle: loads docker/sql/*.sql into the Oracle container (if you are using the Oracle image)
# - all: runs the supported checks for both environments

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKER_DIR="$ROOT_DIR/docker"
COMPOSE_FILE="$DOCKER_DIR/docker-compose.yml"
TARGET="${1:-all}"

if docker compose version >/dev/null 2>&1; then
    compose_cmd() {
        docker compose -f "$COMPOSE_FILE" "$@"
    }
else
    compose_cmd() {
        docker-compose -f "$COMPOSE_FILE" "$@"
    }
fi

load_mock_qserv() {
    echo "== Verifying mock-qserv data =="
    MOCK_CONTAINER=$(compose_cmd ps -q mock-qserv || true)
    if [ -z "$MOCK_CONTAINER" ]; then
        echo "mock-qserv is not running; starting it now..."
        compose_cmd up -d mock-qserv
        MOCK_CONTAINER=$(compose_cmd ps -q mock-qserv)
    fi

    if docker exec -i "$MOCK_CONTAINER" bash -lc "mysql -u qsmaster -D wise_00 -e 'SHOW TABLES;'" >/dev/null 2>&1; then
        echo "mock-qserv initialization already present; no manual reload required."
        return 0
    fi

    echo "The mock-qserv image initializes itself through /docker-entrypoint-initdb.d."
    echo "This container does not permit root login without a configured password, so a manual root reload is not supported."
    echo "If the DB is empty, recreate the container with:"
    echo "  cd $DOCKER_DIR && docker compose down -v --remove-orphans && docker compose up -d mock-qserv"
    return 1
}

load_oracle_sql() {
    echo "== Loading docker/sql files =="
    if [ ! -d "$DOCKER_DIR/sql" ]; then
        echo "No $DOCKER_DIR/sql directory found. Nothing to load." >&2
        return 0
    fi

    ORACLE_CONTAINER=$(compose_cmd ps -q tap-oracle || true)
    if [ -z "$ORACLE_CONTAINER" ]; then
        echo "No Oracle container is running. The SQL files in docker/sql are Oracle-specific and require the Oracle image stack." >&2
        echo "If you are using the Oracle image, start it and re-run: $0 oracle" >&2
        return 0
    fi

    for sql_file in "$DOCKER_DIR"/sql/*.sql; do
        [ -e "$sql_file" ] || continue
        echo "Loading $sql_file"
        docker exec -i "$ORACLE_CONTAINER" bash -lc "sqlplus -S system/system@//localhost/XE < $sql_file" || {
            echo "The file $sql_file is not compatible with the current database image." >&2
            echo "These scripts are Oracle-oriented and may need to be run against the opencadc/tap-oracle image." >&2
            return 1
        }
    done
}

case "$TARGET" in
    mock)
        load_mock_qserv
        ;;
    oracle)
        load_oracle_sql
        ;;
    all)
        load_mock_qserv
        load_oracle_sql
        ;;
    *)
        echo "Unknown target: $TARGET" >&2
        echo "Use: mock, oracle, or all" >&2
        exit 1
        ;;
esac

echo "Data check complete."

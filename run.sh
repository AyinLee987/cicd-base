#!/usr/bin/env bash
# Build and run the cicd-base Spring Boot app locally (no Docker required).
#
# pom.xml pins java.version=23, but the bundled lombok 1.18.36 does not
# support newer JDKs (24/25) and fails to compile on them. JDK 17 works
# reliably, so this script forces JDK 17 for both build and run, overriding
# java.version via -Djava.version=17.
#
# Usage:
#   ./run.sh                 # build + run on the default port (8080)
#   ./run.sh --skip-build    # just run the jar already in target/
#   ./run.sh --port 3000     # build + run on a custom port
#   JDK_HOME=/path/to/jdk17 ./run.sh
set -euo pipefail

DEFAULT_JDK_HOME="/c/Program Files/Eclipse Adoptium/jdk-17.0.20.8-hotspot"
JDK_HOME="${JDK_HOME:-$DEFAULT_JDK_HOME}"
SKIP_BUILD=0
PORT=""

while [ $# -gt 0 ]; do
    case "$1" in
        --skip-build) SKIP_BUILD=1; shift ;;
        --port) PORT="$2"; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

if [ ! -x "$JDK_HOME/bin/java" ] && [ ! -f "$JDK_HOME/bin/java.exe" ]; then
    echo "JDK 17 not found at '$JDK_HOME'. Install one, or set JDK_HOME=<path>." >&2
    exit 1
fi

export JAVA_HOME="$JDK_HOME"
export PATH="$JDK_HOME/bin:$PATH"

echo "Using JDK:"
java -version

cd "$(dirname "$0")"

if [ "$SKIP_BUILD" -eq 0 ]; then
    echo
    echo "Building (mvnw clean package -DskipTests -Djava.version=17)..."
    ./mvnw.cmd clean package -DskipTests -Djava.version=17
fi

JAR="$(ls target/*.jar 2>/dev/null | grep -v sources | head -n 1 || true)"
if [ -z "$JAR" ]; then
    echo "No jar found in target/. Run without --skip-build first." >&2
    exit 1
fi

RUN_ARGS=(-jar "$JAR")
if [ -n "$PORT" ]; then
    RUN_ARGS+=("--port=$PORT")
fi

echo
echo "Starting $JAR ..."
exec java "${RUN_ARGS[@]}"

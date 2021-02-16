#!/bin/bash -eux

source "${BASH_SOURCE%/*}/../lib/flaky-tests.sh"

# getconf is a POSIX way to get the number of processors available which works on both Linux and macOS
LIMITS_CPU=${LIMITS_CPU:-$(getconf _NPROCESSORS_ONLN)}
MAVEN_PARALLELISM=${MAVEN_PARALLELISM:-$LIMITS_CPU}
SUREFIRE_FORK_COUNT=${SUREFIRE_FORK_COUNT:-}
JUNIT_THREAD_COUNT=${JUNIT_THREAD_COUNT:-}
MAVEN_PROPERTIES=(
  -DtestMavenId=2
  -Dsurefire.rerunFailingTestsCount=7
)
tmpfile=$(mktemp)

if [ ! -z "$SUREFIRE_FORK_COUNT" ]; then
  MAVEN_PROPERTIES+=("-DforkCount=$SUREFIRE_FORK_COUNT")
  # if we know the fork count, we can limit the max heap for each fork to ensure we're not OOM killed
  export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS} -XX:MaxRAMPercentage=$((100 / (MAVEN_PARALLELISM * $SUREFIRE_FORK_COUNT)))"
fi

if [ ! -z "$JUNIT_THREAD_COUNT" ]; then
  MAVEN_PROPERTIES+=("-DjunitThreadCount=$JUNIT_THREAD_COUNT")
fi

mvn -o -B --fail-never -T${MAVEN_PARALLELISM} -s ${MAVEN_SETTINGS_XML} verify -P skip-unstable-ci,skip-random-tests,parallel-tests -pl qa/integration-tests,update-tests "${MAVEN_PROPERTIES[@]}" | tee ${tmpfile}
status=${PIPESTATUS[0]}

# delay checking the maven status after we've analysed flaky tests
analyseFlakyTests "${tmpfile}" "./FlakyTests.txt" || exit $?

if [[ $status != 0 ]]; then
  exit $status;
fi

if grep -q "\[INFO\] Build failures were ignored\." ${tmpfile}; then
  exit 1
fi

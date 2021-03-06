#!/bin/bash

AWK=`which gawk`
[ $? -ne 0 ] && AWK=awk

# config
TMPDIR=./tmp
# arguments

SDIR=$(cd `dirname $0`; pwd)

HELP="$0 FRAMEWORK BENCH [THREAD=1] [BENCH_TIME=30s] [NBENCH=10] [PORT=8080] [MACHINE=`uname -n`]
    FRAMEWORK: apiary, scotty, Spock
    BENCH: HELLO, PARAM, DEEP, AFTER_DEEP"

if [ $# -eq 2 ]; then
  PROG=$1
  BENCH=$2
  THREAD=1
  BENCHTIME="30s"
  NBENCH=10
  PORT=8080
  MACHINE=`uname -n`
elif [ $# -eq 3 ]; then
  PROG=$1
  BENCH=$2
  THREAD=$3
  BENCHTIME="30s"
  NBENCH=10
  PORT=8080
  MACHINE=`uname -n`
elif [ $# -eq 4 ]; then
  PROG=$1
  BENCH=$2
  THREAD=$3
  BENCHTIME=$4
  NBENCH=10
  PORT=8080
  MACHINE=`uname -n`
elif [ $# -eq 5 ]; then
  PROG=$1
  BENCH=$2
  THREAD=$3
  BENCHTIME=$4
  NBENCH=$5
  PORT=8080
  MACHINE=`uname -n`
elif [ $# -eq 6 ]; then
  PROG=$1
  BENCH=$2
  THREAD=$3
  BENCHTIME=$4
  NBENCH=$5
  PORT=$6
  MACHINE=`uname -n`
elif [ $# -eq 7 ]; then
  PROG=$1
  BENCH=$2
  THREAD=$3
  BENCHTIME=$4
  NBENCH=$5
  PORT=$6
  MACHINE=$7
else
  echo "$HELP"
  exit 1
fi

GHCVERSION=`ghc --numeric-version`
FRAMEWORKVERSION=`cabal sandbox hc-pkg list | grep -v 'conf.d:' | grep $PROG | xargs echo`

WRK="wrk -t2 -c800 -d$BENCHTIME"

HELLO_URL="http://localhost:$PORT/echo/hello-world"
PARAM_URL="http://localhost:$PORT/echo/plain/hello/12"
DEEP_URL="http://localhost:$PORT/deep/foo/bar/baz/100"
AFTER_DEEP_URL="http://localhost:$PORT/after"

if   [ "$BENCH" == "HELLO" ]; then
  URL=$HELLO_URL
elif [ "$BENCH" == "PARAM" ]; then
  URL=$PARAM_URL
elif [ "$BENCH" == "DEEP" ]; then
  URL=$DEEP_URL
elif [ "$BENCH" == "AFTER_DEEP" ]; then
  URL=$AFTER_DEEP_URL
fi

if ! which wrk > /dev/null; then
  echo "wrk not found." >&2
  exit 127
fi

# start server 
echo -n "server start." >&2
if [ -e $SDIR/../dist/build/$PROG/$PROG ]; then
  $SDIR/../dist/build/$PROG/$PROG $PORT +RTS -N$THREAD &
  sleep 3
  pid=$!
  echo "pid: $pid" >&2
else
  echo .. failure.
  echo "$HELP"
  exit 2
fi

trap "echo server stop pid: $pid >&2 && kill $pid && echo remove $TMPDIR >&2 && rm -rf $TMPDIR" EXIT

echo make $TMPDIR directory >&2
mkdir $TMPDIR

# bench configuration

bench () {
  tmp=`mktemp $TMPDIR/bench.XXXXXXXXXXX`
  for i in `seq 1 $NBENCH`; do
    echo "-----------------------------------------------"
    echo bench $i start >&2
    result=$($WRK $1)
    echo "$result" | awk '/^Requests\/sec:/{print $2}' >> $tmp
    echo "$result"
  done

  echo "=================== summary ==================="
  echo "machine:      $MACHINE"
  echo "ghc version:  $GHCVERSION"
  echo "bench target: $FRAMEWORKVERSION"
  echo "bench:        $BENCH"
  echo "bench mode:   $BENCHTIME * $NBENCH"
  ave=`$AWK -f $SDIR/average.awk $tmp`
  echo "average:      $ave"
  stdev=`$AWK -vave=$ave -f $SDIR/stdev.awk $tmp`
  echo "stdev:        $stdev"
  echo "=================== oneline ==================="
  echo "$MACHINE,$GHCVERSION,$FRAMEWORKVERSION,$BENCH,$BENCHTIME,$NBENCH,$ave,$stdev"
}

echo "Benchmarking $BENCH"
bench $URL

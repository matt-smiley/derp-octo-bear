#!/bin/bash

if [[ $( whoami ) != "postgres" ]] ; then
  echo "WARNING: This script is intended to run as the same user who owns the Postgres postmaster process."
  echo "Continuing anyway, in case you are running the postmaster as some other username."
fi

GDB_COMMAND_FILE="$( dirname "$0" )/.gdb_backtrace_command"

if [[ -x /sbin/sysctl && $( /sbin/sysctl -n kernel.yama.ptrace_scope 2> /dev/null ) -gt 0 ]] ; then
  echo "ERROR: You do not seem to have permission to attach gdb to running processes."
  echo "On hardened kernels, gdb and strace can only attach to running processes that are direct descendants."
  echo "Being the process owner is no longer sufficient to allow attaching to other processes you own."
  echo "See: https://wiki.ubuntu.com/SecurityTeam/Roadmap/KernelHardening#ptrace"
  echo
  echo "To temporarily allow any user to attach to any process it owns (same uid), run:"
  echo "    sudo /sbin/sysctl -w kernel.yama.ptrace_scope=0"
  echo "And to revert to the safer mode (if your :"
  echo "    sudo /sbin/sysctl -w kernel.yama.ptrace_scope=1"
  exit 1
fi

echo "Start time: $( date '+%Y-%m-%d %H:%M:%S' )"
uptime

if [[ -e "$GDB_COMMAND_FILE" && ! -w "$GDB_COMMAND_FILE" ]] ; then
  echo "ERROR: Cannot write/overwrite the gdb command file.  Aborting script in case any existing file has unexpected commands."
  exit 2
fi
touch "$GDB_COMMAND_FILE"
if [[ $? == 0 ]] ; then
  chmod 644 "$GDB_COMMAND_FILE"
  # Modern versions of Postgres are built with --enable-threadsafety, so it should be fine to request traces of all threads in case more than one is present.
  # If we get no traces from "thread apply all bt ...", the switch back to plain "bt ...".
  # Also, normally backtrace ("bt") only gives the frames themselves, but go ahead and request the local variables for each frame too ("bt full").
  echo "thread apply all bt full" > $GDB_COMMAND_FILE
#  echo "bt full" > $GDB_COMMAND_FILE
else
  echo "ERROR: Could not write the gdb command file."
  exit 2
fi

# Find PIDs of non-idle local or remote Pg sessions for Pg instance run by current user (not necessarily named "postgres").
PG_SESSION_PIDS=$( pgrep -fl -u $(whoami) | awk '/[p]ostgres: [^ ]+ [^ ]+ (\[local\]|[0-9\.]+\()/ && $6 != "idle" { print $1 }' )

for PID in $PG_SESSION_PIDS
do
  echo

  EXECUTABLE=$( ls -l /proc/$PID/exe | sed 's/.* -> //' )
  if [[ $( echo "$EXECUTABLE" | grep -c 'postgres' ) -gt 0 ]] ; then
    echo "Stack trace for PID: $PID"
    gdb -batch -n -x "$GDB_COMMAND_FILE" "$EXECUTABLE" $PID
  else
    echo "ERROR: Executable for PID $PID does not appear to be postgres: '$EXECUTABLE'"
    exit 3
  fi
done

echo
uptime
echo "End time: $( date '+%Y-%m-%d %H:%M:%S' )"

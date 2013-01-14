#!/bin/bash

PGDATA="/run/shm/toy_db"
PGPORT=9000
DBNAME="toy_db"
RUNDIR="$( dirname $0 )"

echo "Confirming PATH includes required Postgres executables."
for EXECUTABLE in initdb psql pg_ctl postgres createdb pgbench
do
    if [[ ! -x $( which $EXECUTABLE ) ]] ; then
        echo "ERROR: Cannot find $EXECUTABLE in PATH."
        exit 1
    fi
done

echo "Postgres version is: $( psql --version | awk '/psql/ {print $3}' )"

echo "Making PGDATA dir at: $PGDATA"
if [ -d $PGDATA ] ; then
    echo "Directory for PGDATA already exists!  Aborting."
    exit 2
fi

mkdir -p $PGDATA
RETVAL=$?
if [ $RETVAL -ne 0 ] ; then
    echo "ERROR: Could not create PGDATA directory at: $PGDATA"
    echo 3
fi

echo "Initializing postgres data dir."
initdb $PGDATA

echo
echo "Replacing default postgresql.conf."
mv $PGDATA/postgresql.conf $PGDATA/postgresql.conf.ORIG
cp -p $RUNDIR/postgresql.conf.minimal $PGDATA/postgresql.conf
echo "port = $PGPORT" >> $PGDATA/postgresql.conf

echo "Starting postgres."
pg_ctl -w -D $PGDATA start
RETVAL=$?
if [ $RETVAL -ne 0 ] ; then
    echo "ERROR: Failed to start postgres."
    exit 4
fi

echo "Creating database."
createdb -p $PGPORT $DBNAME
RETVAL=$?
if [ $RETVAL -ne 0 ] ; then
    echo "ERROR: Failed to create database in new postgres instance."
    exit 5
fi

echo "Populating tables in db $DBNAME."
psql -X -p $PGPORT $DBNAME < $RUNDIR/pgbench_init_custom_tables_with_histograms.sql
if [ $RETVAL -ne 0 ] ; then
    echo "ERROR: Failed to cleanly create and populate tables."
    exit 6
fi

echo
echo "Done!"

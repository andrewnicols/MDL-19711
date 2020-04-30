#!/bin/sh

ORIG=$PGDATA.orig
CONFFILE="$PGDATA"/postgresql.conf
HBAFILE="$PGDATA"/pg_hba.conf
ARCHIVEDIR="${PGDATA}/archive/"
RECOVERYCONF="${PGDATA}/recovery.conf"

# Stop the server before doing anything.
# This function comes courtesy of /docker-entrypoint.sh
docker_temp_server_stop

# Ensure that the postgresql data directory is owned by the postgres user.
# These scripts run as 'postgres' so we must use gosu to do so.
gosu root chown postgres:postgres /var/lib/postgresql
gosu root chown postgres:postgres $PGDATA

# Move the original PGDATA to a new location
mkdir -p "${ORIG}"
chmod 700 "${ORIG}"
chown -R postgres:postgres "${ORIG}"
mv $PGDATA/* $ORIG/

sleep 2

echo "Polling until master is available"
until psql -h master -U moodle initial -c '\q'; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

echo "Restoring backup from master"
pg_basebackup -h master -U moodle -D "${PGDATA}" -P --xlog

echo "Copying postgresql.conf in place"
cp $PGDATA.orig/postgresql.conf $CONFFILE

# Set the postgres configuration for a slave.
echo "Configuring $CONFFILE as a slave"
cat << EOF >> $CONFFILE
wal_level = hot_standby
synchronous_commit = local
max_wal_senders = 2
wal_keep_segments = 10
synchronous_standby_names = 'slave'
hot_standby = on

log_statement = 'all'
log_directory = 'pg_log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
logging_collector = on
log_min_error_statement = error
EOF

echo "Copying recovery.conf in place"
cat << EOF >> "${RECOVERYCONF}"
standby_mode = 'on'
primary_conninfo = 'host=master port=5432 user=moodle application_name=moodle'
restore_command = 'cp ${ARCHIVEDIR}%f %p'
trigger_file = '/tmp/postgresql.trigger.5432'
EOF
chmod 600 "${RECOVERYCONF}"

# Restart postgres.
docker_temp_server_start

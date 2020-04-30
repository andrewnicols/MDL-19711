#!/bin/sh

CONFFILE="$PGDATA"/postgresql.conf
HBAFILE="$PGDATA"/pg_hba.conf
ARCHIVEDIR="${PGDATA}/archive/"

# Create the archive directory for WAL logs.
mkdir -p "${ARCHIVEDIR}"
chmod 700 "${ARCHIVEDIR}"
chown -R postgres:postgres "${ARCHIVEDIR}"

# Configure the postgresql.conf for hot standby and more logging.
cat << EOF >> $CONFFILE
wal_level = hot_standby
synchronous_commit = local
archive_mode = on
archive_command = 'cp %p ${ARCHIVEDIR}%f'
max_wal_senders = 2
wal_keep_segments = 10
synchronous_standby_names = 'slave'

log_statement = 'all'
log_directory = 'pg_log'
log_filename = 'postgres.log'
logging_collector = on
log_min_error_statement = error
EOF

# Trust the world.
cat << EOF >> $HBAFILE
# Localhost
local   replication     moodle                                trust

# PostgreSQL Master IP address
host    replication     moodle        127.0.0.1/32            trust

# PostgreSQL SLave IP address
host    replication     moodle        127.0.0.1/0             trust
EOF

# Create an initial database.
createdb -U moodle -E UTF8 -O moodle moodle

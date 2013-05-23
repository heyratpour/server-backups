#!/bin/bash
#--------------------------------Config--------------------------------#

# Server's name
SERVER=$(hostname)

# Backup directory
BACKDIR=/path/to/backup/output/dir
# Temp directory
TEMPDIR=/path/to/temp/dir

# LOG
LOG_FILE=$BACKDIR/backup.log
TAR_LOG_FILE=/dev/null
GZIP_LOG_FILE=/dev/null

# Date format filename's
#DATENAME=`date +'%y-%m-%d__%H-%M-%S__%N'`
DATENAME=`date +'%d'`

# Date format log's
DATELOG=`date +'%Y-%m-%d %H:%M:%S'`

# Date format log file's, spilit by this format
DATELOG_FILES=`date +'%Y_%m_%d'`

# Path log files
#LOG_PATH=/var/log/backups_daily/

# MySQL server
HOST=localhost

# MySQL username
USER=root

# MySQL password
PASS=Root_Password

# List all of the MySQL databases that you want to backup, separated by a space
# set to 'ALL' if you want to backup all your databases
DBS="ALL"

# -------------------- #
#	LOCATIONS	#
# -------------------- #

# List all files and directories you wanna tar, separated by a space ARCHIVE_FILES
# List all files & directories which have probability of change during tar job, separated by a space in ARCHIVE_VAR_FILES
# Var files whould be completely addressed
# Relative addresses R related to `TEMPDIR`
ARCHIVE_FILES="/etc /opt /selinux /var"
ARCHIVE_VAR_FILES="/var/log"

# ------------- #
#	SCP	#
# ------------- #

# Server hostname or IP Address which will be used for SCP and SSH
SCP_SERVER="MySafeServer.com"

# Server username which will be used for SCP and SSH
SCP_USER="server_username"

# Server password which will be used for SCP and SSH
# You can also share public key and provide no password
# SCP_PASS="Password"

# Location on server which will be used for SCP
SCP_LOC="/path/on/secure/server/to/upload/backup"

# Maximum SCP and MD5 Check retry in case of failure
MAX_SCP_RETRY=1

# ---------------------------- #
#	ALERTS AND EMAILS	#
# ---------------------------- #

# Email configs
FAILURE_EMAIL_SEND=1
FAILURE_EMAIL_SUBJECT="Backup failed on"
FAILURE_EMAIL_TO="notify@mailserver.com"
FAILURE_EMAIL_BODY_FILENAME=$TEMPDIR/failure_mail

SUCCESS_EMAIL_SEND=1
SUCCESS_EMAIL_SUBJECT="Backup successfully finished on"
SUCCESS_EMAIL_TO="notify@mailserver.com"
SUCCESS_EMAIL_BODY_FILENAME=$TEMPDIR/success_mail

#Debug option. Set to 1 if you wanna get msgs
DEBUG_MODE=0

BK_INC_CONFIG=1
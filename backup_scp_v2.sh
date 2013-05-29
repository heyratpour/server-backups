#!/bin/bash

# TO DO
#    1. Correct output in bk_ssh when password is provided
#    2. Get Log files as argument
#    3. Make verbose optional by -v switch
#    4. Select expired backups by created dates

__DIR__=$(dirname $0)
source $__DIR__/header.sh

bk_log "~~~---------------------------------------------------~~~"
bk_log "        Server: $SERVER"
bk_log "        Date: $DATELOG"
bk_log "        Filename: $DATENAME"
bk_log_separator

SUCCESS=0

# check if the backup and temp directory exists
# if not, create it
bk_mkdirIfNotExists $BACKDIR
bk_mkdirIfNotExists $TEMPDIR

# optimize filenames
ARCHIVE_FILES=$(bk_optimizeFilenames "$ARCHIVE_FILES")
ARCHIVE_VAR_FILES=$(bk_optimizeFilenames "$ARCHIVE_VAR_FILES")

if [ "$DBS" = "ALL" ]; then
  bk_log "Creating list of all your databases:"
  DBS=`mysql -h $HOST --user=$USER --password=$PASS -Bse "show databases;" | tr '\n' ' '`
  bk_log "Done"
fi

bk_debug "Listing DBs done: $DBS"

bk_optimizeDatabases "$DBS" $HOST $USER $PASS

bk_debug "Optimizing DBs done."

ARCHIVE_SQL_FILES=$(bk_backupMySQL "$DBS" $HOST $USER $PASS $TEMPDIR)

bk_debug "Dumped DBS: $ARCHIVE_SQL_FILES"

bk_log_separator

bk_compress "$ARCHIVE_SQL_FILES $ARCHIVE_FILES" "$ARCHIVE_VAR_FILES" "$BACKDIR/$DATENAME.tar"
TAR_OUTPUT=$?

bk_log_separator

case $TAR_OUTPUT in
  "0")
    bk_log "Successfully tarred!"

    bk_gzip "$BACKDIR/$DATENAME.tar"
    GZ_OUTPUT=$?

    case $GZ_OUTPUT in
      "0"|"2")

	if [ $GZ_OUTPUT = "2" ]; then
	  bk_log "gzip finished with some warnings"
	else
          bk_log "Successfully gzipped"
	fi
	
	if [ $MAX_SCP_RETRY -ge 0 ]; then
	  scpRetryCount=0
	  while [ $SUCCESS -eq 0 ] && [ $scpRetryCount -le $MAX_SCP_RETRY ]
	  do
	    if [ $SSH_PASS_IS_SET -eq 1 ]; then
	      bk_scp "$BACKDIR/$DATENAME.tar.gz" "$SCP_USER@$SCP_SERVER:$SCP_LOC/$DATENAME.tar.gz" "$SCP_PASS"
	      bk_md5Check "$BACKDIR/$DATENAME.tar.gz" "$SCP_LOC/$DATENAME.tar.gz" "$SCP_USER" "$SCP_SERVER" "$SCP_PASS"
	    else
	      bk_scp "$BACKDIR/$DATENAME.tar.gz" "$SCP_USER@$SCP_SERVER:$SCP_LOC/$DATENAME.tar.gz"
	      bk_md5Check "$BACKDIR/$DATENAME.tar.gz" "$SCP_LOC/$DATENAME.tar.gz" "$SCP_USER" "$SCP_SERVER"
	    fi
	    SUCCESS=$?
	    let "scpRetryCount++"
	  done
	else
	  SUCCESS=1
	fi
	;;

      "1")
	bk_log "An internal error occured while gzipping"
	;;

      "137")
	bk_log "Gzip killed!"
	;;

      *)
	bk_log "There was an error with Gzip"
	;;
    esac
    ;;

  "137")
    bk_log "Tar Killed!"
    ;;

  *)
    bk_log "There was a problem with tar: "$TAR_OUTPUT
    ;;
esac

if [ $SUCCESS -eq 1 ]; then
  bk_log "Backup successfully finished."
  
  if [ $SUCCESS_EMAIL_SEND -eq 1 ]; then
    touch $SUCCESS_EMAIL_BODY_FILENAME
    echo "On $(bk_getTime) $DATELOG backup succeed" > $SUCCESS_EMAIL_BODY_FILENAME
    lineNumbers=$(wc -l $LOG_FILE)
    lineNumbers=${lineNumbers% *}
    lineNumbers=$((lineNumbers))
    currentLogStartLineNumber=$(echo "$(grep -n "Date: $DATELOG" $LOG_FILE | tail -1)" | cut -d ':' -f 1)
    currentLogStartLineNumber=$((currentLogStartLineNumber-3))
    linesDifference=$((lineNumbers-currentLogStartLineNumber))
    currentLog=$(tail -n $linesDifference $LOG_FILE)
    echo -e "$currentLog" >> $SUCCESS_EMAIL_BODY_FILENAME
    
    bk_email "$SUCCESS_EMAIL_SUBJECT $(bk_getTime)" $SUCCESS_EMAIL_TO $SUCCESS_EMAIL_BODY_FILENAME
    
    rm $SUCCESS_EMAIL_BODY_FILENAME
  fi
  
  # Remove temp
  rm -rf $TEMPDIR/*
  
  # Remove expired backup
  expiredBackup=`date -d $BACKUP_EXPIRE_DAYS' day ago' +'%d'`
  bk_log "Removing $BACKDIR/$expiredBackup.tar"
  rm $BACKDIR/$expiredBackup.tar
else
  bk_log "! FAILURE occured while BACKing UP."
  
  if [ $FAILURE_EMAIL_SEND -eq 1 ]; then
    touch $FAILURE_EMAIL_BODY_FILENAME
    echo "On $(bk_getTime) $DATELOG backup failed" > $FAILURE_EMAIL_BODY_FILENAME
    lineNumbers=$(wc -l $LOG_FILE)
    lineNumbers=${lineNumbers% *}
    lineNumbers=$((lineNumbers))
    currentLogStartLineNumber=$(echo "$(grep -n "Date: $DATELOG" $LOG_FILE | tail -1)" | cut -d ':' -f 1)
    currentLogStartLineNumber=$((currentLogStartLineNumber-3))
    linesDifference=$((lineNumbers-currentLogStartLineNumber))
    currentLog=$(tail -n $linesDifference $LOG_FILE)
    echo -e "$currentLog" >> $FAILURE_EMAIL_BODY_FILENAME
    
    bk_email "$FAILURE_EMAIL_SUBJECT $(bk_getTime)" $FAILURE_EMAIL_TO $FAILURE_EMAIL_BODY_FILENAME
    
    rm $FAILURE_EMAIL_BODY_FILENAME
  fi
fi

bk_log_separator
bk_log "@@@###################################################@@@"
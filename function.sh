#!/bin/bash

#--------------------------------Functionz--------------------------------#

#--------------Indicators

bk_debug(){
  if [ $DEBUG_MODE -eq 1 ]; then
    echo "$1"
  fi
}

bk_getResult(){
  # Echo after substring 'return:'
  local str="$1"
  echo ${str:7}
}

bk_getTime(){
  echo "[$(date "+"%H:%M:%S"")]"
}

bk_notify(){
  echo "[$(bk_getTime)] $1"
}

bk_log(){
  bk_notify "$1" >> $LOG_FILE
}

bk_log_separator(){
  bk_log "      ~~~---------------------------------------~~~"
}

#--------------~~~~~~~~~

# Makes directory if not exists
bk_mkdirIfNotExists(){
  # Arguments:
  #   1: Directory Path

  if  [ ! -d $1 ]; then
    bk_log "Creating $1:"
    mkdir -p $1
    bk_log "Done"
  fi
}

# Removes '/' after directory name
bk_optimizeFilenames(){
  # Arguments:
  #   1: Filename(s) separated by space
  
  filenames=$1
  
  tmpFilenames=""
  for filename in $filenames
  do
    # remove extra slashes
    correctFilename=$(echo "$filename" | sed s#//*#/#g)

    # remove leading slash
    if [ ! "$correctFilename" = "/" ]; then
      correctFilename=${correctFilename%/}
    fi

    tmpFilenames="$tmpFilenames$correctFilename "
  done
  
  echo "$tmpFilenames"
}

bk_backupMySQL(){
  # Arguments:
  #   1: Databases' names
  #   2: MySQL Server
  #   3: MySQL Username
  #   4: MySQL Password
  #   5: Output directory
  
  databases=$1
  server=$2
  username=$3
  password=$4
  outdir=$5

  local sqlFiles=""
  bk_log "MySQL dump beginning:"
  for database in $databases
  do
    bk_log "Backing up $database:"
    nice -n 19 mysqldump -h "$server" -u$username -p$password --opt "$database" > $outdir/$database.sql
    sqlFiles="$sqlFiles $database.sql"
    bk_log "Done"
  done

  echo $sqlFiles
}

bk_optimizeDatabases(){
  # Arguments:
  #   1: Databases' names
  #   2: MySQL Server
  #   3: MySQL Username
  #   4: MySQL Password
  
  databases=$1
  server=$2
  username=$3
  password=$4
  
  loginPhrase="-u $username --password=$password -h $server"
  
  for db in $databases
  do
    TABLES=$(echo "USE $db; SHOW TABLES;" | mysql $loginPhrase |  grep -v Tables_in_)
    bk_log "Switching to database $db: "
    for table in $TABLES
    do
      bk_debug "* Optimizing table $table ..."
      echo "USE $db; OPTIMIZE TABLE $table" | mysql $loginPhrase  >/dev/null
      bk_debug "done."
    done
  done
}

bk_compress(){
  # Arguments:
  #   1: Files and directories separated by space
  #   2: Variable files and directories separated by space
  #   3: Output .tar path
  
  filesToArchive=$1
  varFilesToArchive=$2
  archiveFile=$3

  cd $TEMPDIR
  
  bk_debug "Files to archive: $filesToArchive"
  bk_debug "Variable files to archive: $varFilesToArchive"
  
  excludeStatement=""
  frozenVarFiles=""
  bk_log "Caching variable files:"
  for varFile in $varFilesToArchive
  do
    excludeStatement="$excludeStatement --exclude=$varFile"
    bk_debug "Exclude statement: $excludeStatement"
    bk_debug "Copying $varFile"
    cp -r --parent $varFile .
    frozenVarFiles="$frozenVarFiles ${varFile:1}"
    bk_debug "Cached here: $frozenVarFiles"
  done

  bk_log "Tar is gonna begin:"
  bk_debug "It's running: tar cf $archiveFile $excludeStatement --ignore-failed-read $filesToArchive $frozenVarFiles"
  nice -n 19 tar cf $archiveFile $excludeStatement --ignore-failed-read $filesToArchive $frozenVarFiles 2> $TAR_LOG_FILE
  local tarOutput=$?
  bk_log "Tar returned: "$tarOutput

  return $tarOutput
}

bk_gzip(){
  # Arguments:
  #   1: Tar file path to gzip
  
  TAR=$1

  bk_log "Gzipping is gonna begin:"
  bk_debug "It's running: gzip -f --fast $TAR"
  nice -n 19 gzip -f --fast $TAR 2> $GZIP_LOG_FILE
  local gzipOutput=$?
  bk_log "Gzip returned: "$gzipOutput

  return $gzipOutput
}

bk_ssh(){
  # Arguments:
  #   1: Username
  #   2: Server
  #   3: Command
  #   4: Password
  
  USER=$1
  Server=$2
  CMD=$3
  PWD=$4
  
  set local result
  
  if [ -z "$PWD" ]; then
    result=$(ssh $USER@$Server "$CMD")
  else
    result=$(expect -c "
spawn ssh $USER@$Server \"$CMD\"
expect \"*?assword:*\"
send -- \"$PWD\r\"
expect \"\n\"
expect \"\n\"" | tr '\n' ' ')
    
    result=${result#*assword}
  fi
  
  echo $result
}

bk_scp(){
  # Arguments:
  #   1: Source filename
  #   2: Destination filename
  #   3: Password
  
  SRC=$1
  DES=$2
  PWD=$3

  bk_log "Secure copy is gonna begin: $1 -> $2"
  if [ -z "$PWD" ]; then
    scp $SRC $DES >> $LOG_FILE
  else
    /usr/bin/expect <<EOD >> $LOG_FILE
    spawn scp $SRC $DES
    expect "*?assword:*"
    send -- "$PWD\r"
    expect "\n"
    expect "\n"
EOD
  fi
  bk_log "Secure copy finished."
}

bk_md5Check(){
  # Arguments:
  #   1: Local filename
  #   2: Remote filename
  #   3: Remote Username
  #   4: Remote Server
  #   5: Password
  
  localFilename=$1
  remoteFilename=$2
  remoteUsername=$3
  remoteServer=$4
  pass=$5
  
  bk_log "MD5s R gonna B checked"
  
  local localFileMD5=$(md5sum $localFilename)
  localFileMD5=${localFileMD5% *}
  bk_log "Local MD5: $localFileMD5"
  
  set local remoteFileMD5
  if [ -z "$pass" ]; then
    remoteFileMD5=$(bk_ssh $remoteUsername $remoteServer "md5sum $remoteFilename")
  else
    remoteFileMD5=$(bk_ssh $remoteUsername $remoteServer "md5sum $remoteFilename" "$pass")
  fi
  remoteFileMD5=${remoteFileMD5% *}
  bk_log "Remote MD5: $remoteFileMD5"
  
  if [ $localFileMD5 = $remoteFileMD5 ]; then
    bk_log "MD5s match"
    return 1;
  else
    return 0;
    bk_log "MD5s doesn't match"
  fi
}

bk_remoteRemove(){
  # Arguments:
  #   1: Remote filename
  #   2: Remote Username
  #   3: Remote Server
  #   4: Password
  
  remoteFilename=$1
  remoteUsername=$2
  remoteServer=$3
  pass=$4
  
  bk_log "Gonna remove: $remoteUsername@$remoteServer:$remoteFilename"
  
  set local removeCommandResult
  if [ -z "$pass" ]; then
    removeCommandResult=$(bk_ssh $remoteUsername $remoteServer "rm $remoteFilename")
  else
    removeCommandResult=$(bk_ssh $remoteUsername $remoteServer "rm $remoteFilename" "$pass")
  fi
  
  return 1;
}

bk_email(){
  # Arguments:
  #   1: Subject
  #   2: Recipient email
  #   3: Body filename
  
  mail -s "$1" "$2" < $3
}

#======================================================================#

BK_INC_FUNCTION=1
#!/bin/bash
#######################################################################
# Copyright (c) 2009 & onwards. MapR Tech, Inc., All rights reserved
#######################################################################
#
# Configure script for Kafka connect
#
# This script is normally run by the core configure.sh to setup Kafka 
# connect during install. If it is run standalone, need to correctly 
# initialize the variables that it normally inherits from the master
# configure.sh
#######################################################################


RETURN_SUCCESS=0
RETURN_ERR_MAPR_HOME=1
RETURN_ERR_ARGS=2
RETURN_ERR_MAPRCLUSTER=3
RETURN_ERR_OTHER=4


# Initialize API and globals

MAPR_HOME=${MAPR_HOME:-/opt/mapr}

. ${MAPR_HOME}/server/common-ecosystem.sh  2> /dev/null
{ set +x; } 2>/dev/null

initCfgEnv

if [ $? -ne 0 ] ; then
  echo '[ERROR] MAPR_HOME seems to not be set correctly or mapr-core not installed.'
  exit $RETURN_ERR_MAPR_HOME
fi


KAFKA_HOME="/opt/mapr/kafka/kafka-0.9.0/"
KAFKA_CONNECT_HOME="/opt/mapr/kafka-connect*/kafka-connect*"
KAFKA_CONNECT_HDFS_HOME="/opt/mapr/kafka-connect-hdfs/kafka-connect-hdfs-2.0.1/"
KAFKA_CONNECT_JDBC_HOME="/opt/mapr/kafka-connect-jdbc/kafka-connect-jdbc-2.0.1/"
WARDEN_KAFKA_CONNECT_DEST_CONF="$MAPR_HOME/conf/conf.d/warden.kafka-connect.conf"
WARDEN_KAFKA_CONNECT_FILE="$KAFKA_HOME/config/warden.kafka-connect.conf"
KAFKA_VERSION_FILE=${MAPR_HOME}/kafka/kafkaversion
DAEMON_CONF=${MAPR_HOME}/conf/daemon.conf
VERSION=0.9.0
MAPR_RESTART_SCRIPTS_DIR=${MAPR_RESTART_SCRIPTS_DIR:-${MAPR_HOME}/conf/restart}
KAFKA_CONNECT_RESTART_SRC=${KAFKA_CONNECT_RESTART_SRC:-${MAPR_RESTART_SCRIPTS_DIR}/kafka-connect-2.0.1.restart}


function write_version_file() {
    if [ -f $KAFKA_VERSION_FILE ]; then
        rm -f $KAFKA_VERSION_FILE
    fi
    echo $VERSION > $KAFKA_VERSION_FILE
}

function change_permissions() {
    if [ -f $DAEMON_CONF ]; then
        MAPR_USER=$( awk -F = '$1 == "mapr.daemon.user" { print $2 }' $DAEMON_CONF)
        MAPR_GROUP=$( awk -F = '$1 == "mapr.daemon.group" { print $2 }' $DAEMON_CONF)

        if [ ! -z "$MAPR_USER" ]; then
            chown -R ${MAPR_USER} ${KAFKA_HOME}
            chown -R ${MAPR_USER} ${KAFKA_CONNECT_HOME} 
            chown ${MAPR_USER} ${MAPR_CONF_DIR}
        fi

	if [ ! -z "$MAPR_GROUP" ]; then
            chgrp -R ${MAPR_GROUP} ${KAFKA_HOME}
            chgrp -R ${MAPR_GROUP} ${KAFKA_CONNECT_HOME}            
            chgrp ${MAPR_GROUP} ${MAPR_CONF_DIR}
        fi
        chmod -f u+x ${KAFKA_HOME}/bin/*
    fi
}

function setup_warden_config() {
    if [ -f $WARDEN_KAFKA_CONNECT_DEST_CONF ]; then
        return 0
    fi
    cp $WARDEN_KAFKA_CONNECT_FILE $WARDEN_KAFKA_CONNECT_DEST_CONF
    chown ${MAPR_USER} ${WARDEN_KAFKA_CONNECT_DEST_CONF}
    chgrp ${MAPR_GROUP} ${WARDEN_KAFKA_CONNECT_DEST_CONF}
}

function write_restart_kafka_connect() {

    if [ ! -d $MAPR_RESTART_SCRIPTS_DIR ]; then
        mkdir $MAPR_RESTART_SCRIPTS_DIR
        chown -R ${MAPR_USER} ${MAPR_RESTART_SCRIPTS_DIR}
        chgrp -R ${MAPR_GROUP} ${MAPR_RESTART_SCRIPTS_DIR}
    fi

    echo -e "#!/bin/bash\nsudo -u $MAPR_USER maprcli node services -action restart -name kafka-connect -nodes `hostname`" > ${KAFKA_CONNECT_RESTART_SRC}


    chown ${MAPR_USER} ${KAFKA_CONNECT_RESTART_SRC}
    chgrp ${MAPR_GROUP} ${KAFKA_CONNECT_RESTART_SRC}
    chmod u+x ${KAFKA_CONNECT_RESTART_SRC}
}

# Parse options

USAGE="usage: $0 [-h] [-R]"


{ OPTS=`getopt -n "$0" -a -o suhR --long secure,unsecure,help,EC -- "$@"`; } 2>/dev/null
eval set -- "$OPTS"

for i in "$@" ; do
  case "$i" in
    --secure)
      isSecure=1;
      shift 1;;
    --unsecure)
      isSecure=0;
      shift 1;;
    --R)
      isOnlyRoles=1;
      shift 1;;
    --EC)
      ecosystemParams="$2"
      shift 2;;
    --h)
      echo "${USAGE}"
      exit $RETURN_SUCCESS
      ;;
    --)
      shift; break;;
    *)
      # Invalid arguments passed
      break;; 

  esac
done


change_permissions
write_version_file
write_restart_kafka_connect
setup_warden_config

# remove state file
if  [ -f "$KAFKA_CONNECT_JDBC_HOME/conf/.not_configured_yet" ] ; then
    rm -f "$KAFKA_CONNECT_JDBC_HOME/conf/.not_configured_yet"
fi

if [ -f "$KAFKA_CONNECT_HDFS_HOME/conf/.not_configured_yet" ]  ; then
    rm -f "$KAFKA_CONNECT_HDFS_HOME/conf/.not_configured_yet"
fi

exit $RETURN_SUCCESS
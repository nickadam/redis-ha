#!/bin/bash

SENTINEL_CONFIG="/data/sentinel.conf"
REDIS_CONFIG="/data/redis.conf"

# Load password from secret file if not set
PASSWORD=${PASSWORD:-$(cat "${PASSWORD_FILE}")}

# takes primary IP as argument and connects to it
create_sentinel_config(){
cat <<EOF > "${SENTINEL_CONFIG}"
sentinel monitor ${INSTANCE_NAME} ${1} "${REDIS_PORT}" "${QUORUM}"
sentinel down-after-milliseconds ${INSTANCE_NAME} 5000
sentinel failover-timeout ${INSTANCE_NAME} 60000
sentinel parallel-syncs ${INSTANCE_NAME} 1
sentinel auth-pass ${INSTANCE_NAME} ${PASSWORD}
EOF
}

create_redis_config(){
cat <<EOF > "${REDIS_CONFIG}"
dir /data
appendonly yes
masterauth ${PASSWORD}
user default on +@all ~* >${PASSWORD}
EOF
}

get_primary(){
  # go through the list of all replicas
  for replica_ip in $(getent hosts "${REDIS_NAME}" | awk '{print $1}')
  do
    # skip this replica
    test "${replica_ip}" == "${CONTAINER_IP}" && continue

    # check if replica is a primary
    if timeout 2 redis-cli -h "${replica_ip}" -p "${REDIS_PORT}" -a "${PASSWORD}" info replication | grep role:master >/dev/null
    then
      echo "${replica_ip}"
    fi
  done
}

# Set this container's IP differentiate it from others
CONTAINER_IP=$(getent hosts ${HOSTNAME} | awk '{print $1}')

# we are starting a redis server
if [ "$1" == "redis-server" ]
then
  create_redis_config

  # wait a while for the other replicas to start
  sleep 10

  while true
  do

    # check if there is a primary running and connect to it
    primary=$(get_primary)
    test ! -z "${primary}" && \
    echo "Starting redis server ${CONTAINER_IP} as replica of ${primary}"  && \
    redis-server "${REDIS_CONFIG}" --replicaof "${primary}" "${REDIS_PORT}"

    # couldn't find primary start the lowest IP as the primary
    low_ip=$(getent hosts redis | awk '{print $1}' | sort -n | head -n 1)
    # this is the low ip, start as primary
    test "${low_ip}" == "${CONTAINER_IP}" && \
    echo "Starting redis server ${CONTAINER_IP}" && \
    redis-server "${REDIS_CONFIG}"

    # wait a little while and try again
    sleep 3
  done
fi

# we are starting a redis sentinel server
if [ "$1" == "redis-sentinel" ]
then
  # wait a while for the other replicas to start
  sleep 10

  while true
  do
    # find the primary and create config for it
    primary=$(get_primary)
    test ! -z "${primary}" && \
    echo "Starting redis sentinel ${CONTAINER_IP} monitoring ${primary}"  && \
    create_sentinel_config "${primary}" && \
    break

    # wait a little while and try again
    sleep 3
  done

  # clean up any dead sentinels by resetting others
  for replica_ip in $(getent hosts "${SENTINEL_NAME}" | awk '{print $1}')
  do
    # skip this replica
    test "${replica_ip}" == "${CONTAINER_IP}" && continue

    # reset other sentinel
    redis-cli -h "${replica_ip}" -p "${SENTINEL_PORT}" sentinel reset \*
  done

  # start redis-sentinel
  redis-sentinel "${SENTINEL_CONFIG}"
fi

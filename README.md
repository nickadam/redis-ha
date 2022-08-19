# redis-ha

## About the image

Like redis, the same image can assume different roles; a redis server or
a sentinel server. The redis server is a standalone instance with all additional
replicas being redis replicas of the primary.

All the complicated stuff happens in `docker-entrypoint.sh`. A redis-server
instance (the default) will wait 30 seconds before starting to look for any
additional instances. Using the service name and round robin dns each instance
will attempt to connect to the other instances and identify if they have the
role master. If no primary (master) can be found, the host with the lowest
sorted IP address assumes the role.

The redis-sentinel instaces just search for the primary redis server instance
and connect to it. Sentinels will learn of each other and all connected replicas
and handle failovers.

Your application must query the sentinel service to identify which redis server
is the primary server for writes. Any redis server can be used for reads.

```
redis-cli -h sentinel -p 26379 sentinel get-master-addr-by-name myinstance
```

## Docker swarm

This is a basic HA redis configuration using 2 redis instances; one primary
and one replica. The two node cluster is monitored by 3 redis sentinel
instances. Deploying this evenly across a 3 node cluster where
`max_replicas_per_node = 1` means any one node can fail and the cluster will
remain up.

Increasing the number of redis replicas can be done on the fly. Each new replica
will automatically connect to the primary. Increasing the number of sentinel
instances must be done in coordination with the QUORUM environment variable to
prevent split brain. You should have `floor(n/2) + 1` sentinel instances
available for quorum.

Both redis and sentinel instances rely on `endpoint_mode: dnsrr` to
identify other replicas and connect to the correct one.

The sentinel and redis services can be accessed by your application inside the
same stack. Accessing redis from outside your cluster will likely require an
ingress proxy or tcp binding `mode: host`.

## Kubernetes

Redis server and sentinel server are implemented as statefulsets to prevent
multiple instances from running on the same node. Another way this could be
implemented is a deployment with anti-affinity.

Both the redis-server and redis-sentinel services are implemented as headless,
`clusterIP: None`. This headless service is important to identify each pod
using dns round robin. If a cluster IP is desired deploy 2 services, one
headless for use inside the statefulsets, `SENTINEL_NAME`, and a different name
for the clusterIP.

# redis-swarm

This is a basic HA redis configuration using 2 redis instances; one primary
and one replica. The two node cluster is monitored by 3 redis sentinel
instances. Deploying this evenly across a 3 node cluster where
max_replicas_per_node = 1 means any one node can fail and the cluster will
remain up.

Your application must query the sentinel service to identify which instance is
the primary server for writes. Either redis server can be used for reads.

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

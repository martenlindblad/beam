# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Hashcode for 1000 records is 1a30ad400afe4ebf5fde75f5d2d95408, 
# For test with query to select one record from 1000 docs, 
# hashcode is 7bead6d6385c5f4dd0524720cd320b49

# Script to load data using YCSB on Cassandra one node cluster.

#!/bin/bash
set -e

# Record count set to 1000, change this value to load as per requirement.
recordcount=1000

# Identify the pod
cassandra_pods="kubectl get pods -l name=cassandra"
running_seed="$(kubectl get pods -o json -l name=cassandra -o jsonpath=\
'{.items[0].metadata.name}')"
echo "Detected Pod $running_seed"

echo "Waiting for Cassandra pod to be in ready state"
container_state="$(kubectl get pods -l name=cassandra -o jsonpath="{.items[0].status.containerStatuses[0].ready}")"
while ! $container_state; do
  sleep 10s
  container_state="$(kubectl get pods -l name=cassandra -o jsonpath="{.items[0].status.containerStatuses[0].ready}")"
  echo "."
done

# After starting the service, it takes couple of minutes to generate the external IP for the
# service. Hence, wait for sometime.
# Identify external IP of the pod
external_ip="$(kubectl get svc cassandra-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
echo "Waiting for the Cassandra service to come up ........"
while [ -z "$external_ip" ]
do
   sleep 10s
   external_ip="$(kubectl get svc cassandra-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
   echo "."
done
echo "External IP - $external_ip"

# Create keyspace
keyspace_creation_command="drop keyspace if exists ycsb;create keyspace ycsb WITH REPLICATION = {\
'class' : 'SimpleStrategy', 'replication_factor': 3 };"
kubectl exec -ti $running_seed -- cqlsh -e "$keyspace_creation_command"
echo "Keyspace creation............"
echo "-----------------------------"
echo "$keyspace_creation_command"
echo

# Create table
table_creation_command="use ycsb;drop table if exists usertable;create table usertable (\
y_id varchar primary key,field0 varchar,field1 varchar,field2 varchar,field3 varchar,\
field4 varchar,field5 varchar,field6 varchar,field7 varchar,field8 varchar,field9 varchar);"
kubectl exec -ti $running_seed -- cqlsh -e "$table_creation_command"
echo "Table creation .............."
echo "-----------------------------"
echo "$table_creation_command"

# Create index
index_creation_command="CREATE INDEX IF NOT EXISTS field0_index ON ycsb.usertable (field0);"
kubectl exec -ti $running_seed -- cqlsh -e "$index_creation_command"

cd ../ycsb-0.12.0

echo "Starting to load data on ${external_ip}"
echo "-----------------------------"
# Record count set to 1000, change this value to load as per requirement.
# dataintegrity flag is set to true to load deterministic data
./bin/ycsb load cassandra-cql -p hosts=${external_ip} -p dataintegrity=true -p recordcount=\
${recordcount} -p insertorder=ordered -p fieldlength=20 -P workloads/workloadd \
-s > workloada_load_res.txt

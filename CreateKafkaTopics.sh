#!/bin/bash

# Bash script to write different markets to kafka topics ex. DE= Deutschland
markets=(AT BE BG CH CY CZ DE DK EE ES FI FR GB GR HR HU IE IT LI LT LU LV MT NL NO PL PT RO SE SI SK)

# shellcheck disable=SC2068
for market in ${markets[@]}
do
  /opt/confluent-5.3.1/bin/kafka-topics --create --topic onedoc.replication.$market.task --partitions 1 --replication-factor 1 --if-not-exists --zookeeper localhost:2181
  /opt/confluent-5.3.1/bin/kafka-topics --create --topic onedoc.replication.$market.log --partitions 1 --replication-factor 1 --if-not-exists --zookeeper localhost:2181
done
/opt/confluent-5.3.1/bin/kafka-topics --create --topic onedoc.replication.demandtest --partitions 1 --replication-factor 1 --if-not-exists --zookeeper localhost:2181
/opt/confluent-5.3.1/bin/kafka-topics --create --topic onedoc.replication.request --partitions 1 --replication-factor 1 --if-not-exists --zookeeper localhost:2181
/opt/confluent-5.3.1/bin/kafka-topics --create --topic onedoc.replication.monitoring --partitions 1 --replication-factor 1 --if-not-exists --zookeeper localhost:2181
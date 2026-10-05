#!/bin/bash
# Creates every topic in the README contract (3 partitions, replication 1). Safe to re-run.
set -e

BOOTSTRAP="${KAFKA_BOOTSTRAP:-kafka:29092}"
KT=/opt/kafka/bin/kafka-topics.sh

TOPICS=(
  orders.created
  orders.status-changed
  restaurant.order-validated
  restaurant.order-updated
  payments.completed
  payments.failed
  delivery.assigned
  delivery.picked-up
  delivery.completed
)

for topic in "${TOPICS[@]}"; do
  $KT --bootstrap-server "$BOOTSTRAP" --create --if-not-exists \
    --topic "$topic" --partitions 3 --replication-factor 1
done

echo "Topics ready:"
$KT --bootstrap-server "$BOOTSTRAP" --list

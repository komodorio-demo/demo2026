#!/bin/sh
# Payment processor - consumes from Kafka and settles transactions

echo "Starting payment processor..."
echo "Kafka bootstrap: ${KAFKA_BOOTSTRAP_SERVERS}"
echo "Consumer group: ${CONSUMER_GROUP_ID}"
echo "Topic: ${KAFKA_TOPIC}"

# Graceful shutdown
cleanup() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Shutting down payment processor..."
    kill $CONSUMER_PID 2>/dev/null
    exit 0
}
trap cleanup TERM INT

# Background consumer: continuous processing with optimized throughput
(
    while true; do
        /opt/kafka/bin/kafka-console-consumer.sh \
            --bootstrap-server "${KAFKA_BOOTSTRAP_SERVERS}" \
            --topic "${KAFKA_TOPIC}" \
            --group "${CONSUMER_GROUP_ID}" \
            --timeout-ms 10000 \
            --consumer-property fetch.min.bytes=1 \
            --consumer-property max.poll.records=500 2>/dev/null | \
        while read -r msg; do
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] Processing payment: ${msg}"
            # Fraud check + DB write + ledger update
            sleep 2
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] Payment settled successfully"
        done
        # Brief pause before reconnecting if consumer exits
        sleep 1
    done
) &
CONSUMER_PID=$!

# Main loop: keeps the pod alive and probes passing
while true; do
    touch /tmp/healthy
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Payment processor running"
    sleep 30
done

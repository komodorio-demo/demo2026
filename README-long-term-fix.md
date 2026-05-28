# Long-Term Fix for Payment Processor Scaling and Kafka Data Loss

## Problem
1. **Manual scaling required**: The `payment-processor` Deployment requires manual intervention during traffic spikes when Kafka consumer group lag exceeds threshold
2. **Data loss risk**: Kafka uses ephemeral storage with a single broker — any broker restart loses all unconsumed messages
3. **Readiness probe sensitivity**: 1000-message lag threshold may cause false-positive failures during normal burst traffic

## Solution

### 1. KEDA Auto-Scaling (`keda-scaledobject-payment-processor.yaml`)

Adds automatic horizontal pod autoscaling based on Kafka consumer group lag:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: payment-processor-scaler
  namespace: bank-of-singapore-demo27-1779962111
spec:
  scaleTargetRef:
    kind: Deployment
    name: payment-processor
  minReplicaCount: 1
  maxReplicaCount: 3
  triggers:
    - type: kafka
      metadata:
        consumerGroup: payment-processor-group
        topic: payment-events
        lagThreshold: '1000'
        activationLagThreshold: '500'
```

**Benefits:**
- Auto-scales from 1 to 3 replicas based on real-time lag
- Eliminates manual scaling interventions
- Responds to traffic spikes within seconds
- Scales down automatically when lag is cleared

**Prerequisites:**
- KEDA operator must be installed in cluster: `kubectl apply -f https://github.com/kedacore/keda/releases/download/v2.14.0/keda-2.14.0.yaml`
- Kafka bootstrap server must be accessible from payment-processor namespace

### 2. Persistent Kafka Storage (`kafka-persistent-storage-patch.yaml`)

Upgrades Kafka from ephemeral to persistent storage:

```yaml
spec:
  kafka:
    replicas: 3  # Increased from 1 for high availability
    storage:
      type: persistent-claim
      size: 10Gi
      deleteClaim: false
  zookeeper:
    replicas: 3
    storage:
      type: persistent-claim
      size: 5Gi
```

**Benefits:**
- **Prevents data loss**: Messages survive broker restarts/crashes
- **High availability**: 3 Kafka replicas with replication
- **Disaster recovery**: PVCs can be backed up and restored
- **Production-grade**: Meets standard for production Kafka clusters

**Migration Steps:**
1. Backup current Kafka topics: `kubectl exec my-cluster-kafka-0 -n <namespace> -- bin/kafka-topics.sh --list --bootstrap-server localhost:9092`
2. Apply new Kafka spec (causes rolling restart with PVC creation)
3. Verify all brokers running and topics exist
4. Test message production/consumption

### 3. Optional: Adjust Lag Threshold

If 1000-message lag is too sensitive for normal traffic patterns, update the `processor-scripts` Secret:

```bash
kubectl edit secret processor-scripts -n bank-of-singapore-demo27-1779962111
# Change LAG_THRESHOLD from 1000 to a higher value (e.g., 2000)
# Then restart deployment to apply
```

## Deployment Order

1. **Install KEDA** (if not already installed):
   ```bash
   kubectl apply -f https://github.com/kedacore/keda/releases/download/v2.14.0/keda-2.14.0.yaml
   ```

2. **Apply Kafka persistence** (causes rolling restart):
   ```bash
   kubectl apply -f kafka-persistent-storage-patch.yaml
   ```
   Wait for all Kafka brokers to be running with PVCs attached.

3. **Deploy KEDA ScaledObject**:
   ```bash
   kubectl apply -f keda-scaledobject-payment-processor.yaml
   ```

4. **Verify auto-scaling**:
   ```bash
   # Watch HPA created by KEDA
   kubectl get hpa -n bank-of-singapore-demo27-1779962111 -w
   
   # Check ScaledObject status
   kubectl get scaledobject payment-processor-scaler -n bank-of-singapore-demo27-1779962111
   
   # Monitor Kafka lag
   kubectl exec my-cluster-kafka-0 -n bank-of-singapore-demo27-1779962111 -- bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group payment-processor-group
   ```

## Testing

### Simulate Traffic Spike
```bash
# Produce 5000 messages to payment-events topic
kubectl run kafka-producer --restart=Never --rm -i --image=quay.io/strimzi/kafka:latest-kafka-3.6.0 -n bank-of-singapore-demo27-1779962111 -- bin/kafka-console-producer.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic payment-events << EOF
$(for i in {1..5000}; do echo "test-message-$i"; done)
EOF

# Watch auto-scaling happen
kubectl get pods -n bank-of-singapore-demo27-1779962111 -l app=payment-processor -w
```

Expected: Deployment scales from 1 to 3 replicas as lag increases, then scales back down as lag is cleared.

## Monitoring

- **KEDA metrics**: `kubectl logs -n keda -l app=keda-operator`
- **Kafka lag**: Use Kafka monitoring tools or Komodor's Kafka integration
- **Pod scaling events**: `kubectl get events -n bank-of-singapore-demo27-1779962111 --field-selector involvedObject.name=payment-processor`

## Rollback

If issues occur:

1. **Remove KEDA ScaledObject**: `kubectl delete scaledobject payment-processor-scaler -n bank-of-singapore-demo27-1779962111`
2. **Manual scale**: `kubectl scale deployment payment-processor --replicas=1 -n bank-of-singapore-demo27-1779962111`
3. **Revert Kafka storage**: Requires backup/restore from ephemeral state (not recommended once persistent)
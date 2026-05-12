# Long-Term Kafka and Strimzi Operator Fixes

## Changes

### 1. KEDA ScaledObject for Auto-Scaling
**File:** `keda-scaledobject.yaml`

- Auto-scales `strimzi-cluster-operator` from 1 to 3 replicas based on Kafka consumer group lag
- Monitors `strimzi-cluster-operator-group` consumer group on `payment-events` topic
- Scales up when lag exceeds 100 messages
- Activates scaling when lag exceeds 50 messages
- **Benefit:** Eliminates manual intervention during traffic spikes

### 2. Persistent Storage for Kafka
**File:** `kafka-persistent.yaml`

- Replaces ephemeral storage with persistent volume claims (10Gi)
- Uses standard storage class
- Retains data across pod restarts and rolling updates
- **Benefit:** Prevents message loss during broker restarts

### 3. Current Warnings Addressed

The current Kafka cluster shows these warnings:
```
A Kafka cluster with a single broker node and ephemeral storage will lose topic messages after any restart or rolling update.
A Kafka cluster with a single controller node and ephemeral storage will lose data after any restart or rolling update.
```

These warnings will be resolved by applying the persistent storage configuration.

## Deployment Instructions

### Prerequisites
- KEDA operator must be installed in the cluster
- Ensure sufficient PV capacity for 10Gi persistent volume

### Apply Changes

```bash
# Apply KEDA ScaledObject
kubectl apply -f keda-scaledobject.yaml

# Apply Kafka with persistent storage (will trigger rolling update)
kubectl apply -f kafka-persistent.yaml
```

### Verification

```bash
# Check KEDA ScaledObject status
kubectl get scaledobject -n bank-of-singapore-demo23-1778572633

# Check Kafka status (should show no warnings)
kubectl get kafka my-cluster -n bank-of-singapore-demo23-1778572633 -o yaml

# Verify persistent volumes are bound
kubectl get pvc -n bank-of-singapore-demo23-1778572633

# Monitor operator scaling
kubectl get hpa -n bank-of-singapore-demo23-1778572633
```

## Optional: Lag Threshold Tuning

If the current lag threshold (1000 messages in `processor-scripts` Secret) causes false-positive readiness failures during normal traffic bursts, consider adjusting it:

```bash
kubectl edit secret processor-scripts -n bank-of-singapore-demo23-1778572633
```

Adjust the threshold based on your normal traffic patterns and acceptable latency.
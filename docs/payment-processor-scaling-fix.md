# Payment Processor Scaling Fix

## Problem
The `payment-processor` deployment in the `bank-of-singapore-demo14-1776869018` namespace experiences consumer group lag during traffic spikes because it runs with only 1 replica.

## Immediate Fix Applied
Manually scaled the deployment from 1 to 3 replicas on 2026-04-22:
```bash
kubectl scale deployment payment-processor -n bank-of-singapore-demo14-1776869018 --replicas=3
```

## Permanent Solution Required
The deployment manifest for `payment-processor` needs to be updated to prevent this issue from recurring on the next deployment.

### Action Items

1. **Locate the deployment configuration** for `payment-processor`:
   - Check if it's deployed via Helm chart
   - Check if it's managed by ArgoCD from another repository
   - Check if it uses Kustomize overlays
   - Check if it's in a different branch of this repository

2. **Update the replica count** to 3 (or higher based on production requirements):
   ```yaml
   spec:
     replicas: 3  # Changed from 1
   ```

3. **Consider implementing auto-scaling**:
   Add a KEDA ScaledObject to automatically scale based on Kafka consumer group lag:
   ```yaml
   apiVersion: keda.sh/v1alpha1
   kind: ScaledObject
   metadata:
     name: payment-processor-scaler
     namespace: bank-of-singapore-demo14-1776869018
   spec:
     scaleTargetRef:
       name: payment-processor
     minReplicaCount: 1
     maxReplicaCount: 5
     triggers:
       - type: kafka
         metadata:
           bootstrapServers: my-cluster-kafka-bootstrap.bank-of-singapore-demo14-1776869018.svc:9092
           consumerGroup: payment-processor-group
           topic: payment-events
           lagThreshold: "1000"
   ```

4. **Review Kafka infrastructure**:
   - The `my-cluster` Kafka broker uses ephemeral storage
   - Consider adding persistent PVCs to prevent data loss on broker restarts

## Related Context
- Namespace: `bank-of-singapore-demo14-1776869018`
- Cluster: `production`
- Deployment: `payment-processor`
- Kafka Topic: `payment-events`
- Consumer Group: `payment-processor-group`
- Issue Date: 2026-04-22

## Next Steps
1. Find the actual deployment manifest source
2. Update replica count to 3
3. Implement KEDA auto-scaling (recommended)
4. Add persistent storage to Kafka (recommended)
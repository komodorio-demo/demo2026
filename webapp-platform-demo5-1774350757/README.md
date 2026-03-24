# Log Aggregator Fixes

## Issues Fixed

This PR addresses the following recurring errors in the log-aggregator pod:

### 1. RBAC Permission Denied ✅
**Error:** `ERROR RBAC: cannot list resource "events" in API group ""`

**Fix:** Created dedicated ServiceAccount `log-aggregator-sa` with proper RBAC permissions:
- `rbac.yaml`: ServiceAccount, Role, and RoleBinding
- `log-aggregator-deployment.yaml`: Updated to use `log-aggregator-sa` instead of `default`

### 2. Memory Pressure ✅
**Warning:** `WARN High memory usage detected: 89% of limit (178Mi/200Mi)`

**Fix:** Increased memory limits in `log-aggregator-deployment.yaml`:
- Memory limit: 32Mi → 64Mi
- Memory request: 16Mi → 32Mi

### 3. Dependency Checker OOMKills ✅
**Warning:** `WARN Detected OOMKilled container in pod dependency-checker`

**Fix:** Created `dependency-checker-deployment.yaml` with increased memory:
- Memory limit: 128Mi
- Memory request: 64Mi

### 4. Configuration Drift Prevention 📝
**Warning:** `WARN ConfigMap 'app-settings' was modified externally, hash mismatch detected`

**Recommendation:** Ensure ConfigMap `app-settings` is only modified through GitOps/IaC:
- Use ArgoCD/Flux for automated sync
- Avoid manual `kubectl edit` operations
- Enable ConfigMap immutability if possible

### 5. External Service Dependencies ⚠️

**Elasticsearch Connection:**
- Error: `ERROR TLS handshake timeout connecting to elasticsearch-master:9200`
- Action Required: Verify elasticsearch-master service health and TLS configuration

**Prometheus Pushgateway:**
- Error: `ERROR Failed to push metrics to prometheus-pushgateway:9091 - connection refused`
- Action Required: Ensure prometheus-pushgateway is deployed and accessible

## Deployment Instructions

1. Apply RBAC configuration first:
   ```bash
   kubectl apply -f webapp-platform-demo5-1774350757/rbac.yaml
   ```

2. Update log-aggregator deployment:
   ```bash
   kubectl apply -f webapp-platform-demo5-1774350757/log-aggregator-deployment.yaml
   ```

3. Deploy dependency-checker fix:
   ```bash
   kubectl apply -f webapp-platform-demo5-1774350757/dependency-checker-deployment.yaml
   ```

4. Verify the fixes:
   ```bash
   # Check pod is using new ServiceAccount
   kubectl get pod -n webapp-platform-demo5-1774350757 -l app=log-aggregator -o jsonpath='{.items[0].spec.serviceAccountName}'
   
   # Check memory limits
   kubectl get pod -n webapp-platform-demo5-1774350757 -l app=log-aggregator -o jsonpath='{.items[0].spec.containers[0].resources}'
   
   # Monitor logs for RBAC errors (should be gone)
   kubectl logs -n webapp-platform-demo5-1774350757 -l app=log-aggregator --tail=50
   ```

## Outstanding Issues

The following require infrastructure-level investigation:

1. **Elasticsearch connectivity** - Check elasticsearch-master deployment and TLS certificates
2. **Prometheus Pushgateway** - Ensure service is deployed and network policies allow access
3. **ConfigMap drift** - Implement GitOps workflow to prevent manual modifications
4. **Log buffer capacity** - Will be resolved once error rate decreases from fixes above

## Rollback

If issues occur, rollback with:
```bash
kubectl rollout undo deployment/log-aggregator -n webapp-platform-demo5-1774350757
kubectl delete -f webapp-platform-demo5-1774350757/rbac.yaml
```

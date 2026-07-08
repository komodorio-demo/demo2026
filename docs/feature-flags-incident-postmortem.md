# Feature Flags ConfigMap Typo - Incident Postmortem

## Incident Summary

**Date**: 2026-07-08  
**Affected Service**: checkout-service (premium-tier requests)  
**Impact**: Premium-tier checkout latency increased from 30ms to 220ms, causing SLO violations  
**Root Cause**: Typo in feature-flags ConfigMap (`enable_premium_routng` instead of `enable_premium_routing`)  

## Timeline

- **2026-07-08 17:54:38Z**: feature-flags ConfigMap created with typo `enable_premium_routng`
- **2026-07-08 17:54:40Z**: checkout-service pods started, mounted the misconfigured ConfigMap
- **2026-07-08 17:55:14Z**: premium-canary deployment started testing
- **2026-07-08 17:55:39Z**: premium-canary detected 2 consecutive requests exceeding 150ms SLO (actual: ~220ms)
- **2026-07-08 18:54:38Z**: Issue identified via RCA
- **2026-07-08 18:55:59Z**: ConfigMap corrected and checkout-service restarted

## Root Cause Analysis

The checkout-service uses a feature flag SDK that looks up flags by key name. When the key `enable_premium_routing` is requested but not found (due to typo `enable_premium_routng`), the SDK:

1. Logs a WARNING: "unknown key, using default" with `default=false`
2. Returns `false`, causing premium requests to execute the slow fallback path
3. Slow path executes `time.sleep(0.220)` (220ms) instead of fast path `time.sleep(0.030)` (30ms)

The premium-canary deployment monitors checkout-service latency against a 150ms SLO and fails after 2 consecutive slow responses, making the deployment unhealthy.

## Why This Happened Multiple Times

This exact typo has occurred on:
- 2026-07-06
- 2026-07-08 (multiple times)

Each time it was manually corrected, but the fix didn't persist because:

1. **No source control**: The ConfigMap is applied directly via `kubectl apply` without a canonical source in git
2. **No validation**: No pre-deployment checks to catch typos in flag names
3. **No integration tests**: No automated tests verifying premium-tier latency before promotion
4. **Silent degradation**: Standard-tier requests (37ms) continued working, and health checks passed

## Prevention Measures

### Immediate (Implemented)

1. ✅ Added canonical manifest: `anthos/manifests/feature-flags.yaml` with correct spelling
2. ✅ Created validation script: `anthos/extras/validate-feature-flags.sh` to check for typos
3. ✅ Added documentation with common typos to avoid

### Recommended (To Implement)

1. **Pre-deployment validation**: Add CI/CD pipeline step:
   ```bash
   ./anthos/extras/validate-feature-flags.sh anthos/manifests/feature-flags.yaml
   ```

2. **Integration tests**: Create test that verifies premium-tier checkout latency < 50ms in staging

3. **Admission control**: Implement admission webhook or OPA policy to:
   - Enforce whitelist of allowed flag names
   - Reject ConfigMaps with known typos
   - Validate against schema before apply

4. **GitOps workflow**: Transition from manual `kubectl apply` to ArgoCD/Flux:
   - Single source of truth in git
   - Automatic sync from repository
   - Audit trail for all changes

5. **Enhanced monitoring**: Add alerts for:
   - Feature flag SDK warnings in logs
   - P99 latency exceeding baselines by tier
   - ConfigMap changes in production namespaces

## How to Use the Validation Script

```bash
# Validate before applying
./anthos/extras/validate-feature-flags.sh anthos/manifests/feature-flags.yaml

# Apply if validation passes
kubectl apply -f anthos/manifests/feature-flags.yaml -n <namespace>
```

## Lessons Learned

1. **Configuration is code**: Treat ConfigMaps with same rigor as application code
2. **Fail fast**: Silent degradation is worse than failing health checks
3. **Test in production-like conditions**: Premium-tier testing caught what health checks missed
4. **Automation over documentation**: Typos will recur unless prevented by automation
5. **Observable defaults**: Feature flag SDK should emit metrics, not just logs

## References

- Canonical manifest: `anthos/manifests/feature-flags.yaml`
- Validation script: `anthos/extras/validate-feature-flags.sh`
- Related code: `checkout-service-code` ConfigMap (application logic)

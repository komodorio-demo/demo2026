# Incident: Ledger-DB ConfigMap Key Typo

**Date:** 2026-04-23  
**Status:** Resolved  
**Severity:** High  
**Affected Service:** ledger-db (StatefulSet)  
**Namespace:** bank-of-hill-valley-demo28-1776959465  
**Cluster:** production

## Summary
The ledger-db StatefulSet was failing due to a ConfigMap key typo (`SPRING_DATASOURCE_URL_oops` instead of `SPRING_DATASOURCE_URL`), causing pods to crash on startup with missing environment variable errors.

## Timeline (UTC)
- **~2026-03-19 20:04:48** - Breaking commit [682c905](https://github.com/komodorio-demo/demo2026/commit/682c905aa18959df0573e12542877e81a409e2fd) introduced typo
- **2026-04-23 15:57:50** - Issue investigation began
- **2026-04-23 16:34:47** - ConfigMap patched with correct key name
- **2026-04-23 16:35:19** - StatefulSet restarted to pick up fix

## Root Cause
Commit 682c905 reverted a previous fix and accidentally introduced `SPRING_DATASOURCE_URL_oops` in the ConfigMap `ledger-db-config`. The application expected `SPRING_DATASOURCE_URL`, causing startup failures.

## Actions Taken

### Immediate Fix
```bash
kubectl patch configmap ledger-db-config -n bank-of-hill-valley-demo28-1776959465 \
  --type=json \
  -p='[{"op":"move","from":"/data/SPRING_DATASOURCE_URL_oops","path":"/data/SPRING_DATASOURCE_URL"}]'

kubectl rollout restart statefulset/ledger-db -n bank-of-hill-valley-demo28-1776959465
```

### Long-Term Fix
- **PR #262**: https://github.com/komodorio-demo/demo2026/pull/262
- Corrects the typo in `anthos/manifests/ledger-db.yaml`
- Ensures fix survives future CI/CD deployments

## Prevention Measures
1. **Implement GitOps workflow** (ArgoCD/Flux) to manage ConfigMaps alongside Deployment specs
2. **Add admission webhook** or CI validation to verify required environment variables exist in referenced ConfigMaps
3. **Pre-deployment validation** to catch missing environment variables before production

## Related Resources
- Breaking commit: https://github.com/komodorio-demo/demo2026/commit/682c905aa18959df0573e12542877e81a409e2fd
- Fix PR: https://github.com/komodorio-demo/demo2026/pull/262
- ConfigMap manifest: `anthos/manifests/ledger-db.yaml`

## Lessons Learned
- Manual `kubectl edit` and patches that bypass version control are prone to typos
- ConfigMap changes should go through the same review process as code changes
- Environment variable validation in CI/CD would catch this class of errors early
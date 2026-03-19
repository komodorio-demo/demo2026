# GitOps Policy: Preventing Configuration Drift

## Incident Summary
**Date:** 2026-03-19  
**Namespace:** bank-of-hill-valley-demo19-1773948697  
**Issue:** ConfigMap `ledger-db-config` was manually edited in the cluster with typo `SPRING_DATASOURCE_URL_oops`, causing `ledgerwriter` deployment failure.

## Root Cause: Configuration Drift
- **Git repo** (`anthos/manifests/ledger-db.yaml`): Contains correct configuration with `SPRING_DATASOURCE_URL`
- **Cluster state**: Someone manually edited the ConfigMap with `kubectl edit/patch`, introducing typo `SPRING_DATASOURCE_URL_oops`
- **Result**: Cluster diverged from Git source of truth, breaking the deployment

## The Real Problem
Without GitOps enforcement (ArgoCD/Flux), manual cluster changes override Git configuration:
1. Manifests in Git are correct ✅
2. Someone runs `kubectl edit` directly on cluster ❌
3. Cluster state diverges from Git
4. No automated sync to restore Git state
5. Typo persists until manually discovered

## Required Solution: GitOps Enforcement

### Immediate Actions
1. ✅ **Short-term fix applied**: Manually corrected ConfigMap and restarted deployment
2. **Sync cluster from Git**: Re-apply `anthos/manifests/ledger-db.yaml` to restore source of truth
3. **Verify no other drift**: Check if other resources diverged from Git

### Long-Term: Implement ArgoCD/Flux
Deploy GitOps operator to:
- **Auto-sync** cluster state from Git every N minutes
- **Detect drift** when cluster differs from Git
- **Prevent/revert** manual changes that bypass version control
- **Alert** on configuration drift

### Policy Until GitOps is Enforced
Since GitOps isn't active yet:
1. **Never use `kubectl edit/patch` directly** - Always modify `anthos/manifests/*.yaml` and reapply
2. **All changes via PR** - Update Git first, then apply to cluster
3. **Regular drift checks** - Periodically compare Git vs cluster state
4. **Documentation**: This file serves as the policy until automation is in place

## Validation Before Applying Changes
1. Verify manifest exists in `anthos/manifests/`
2. Review changes in PR
3. Test in non-production namespace
4. Apply via `kubectl apply -f anthos/manifests/<file>.yaml`
5. Never use `kubectl edit` directly on ConfigMaps

## Next Steps
- [ ] Deploy ArgoCD Application for bank-of-anthos workloads
- [ ] Configure auto-sync with self-heal enabled
- [ ] Set up drift detection alerts
- [ ] Restrict cluster RBAC to prevent direct edits
- [ ] Add admission webhook to validate changes match Git
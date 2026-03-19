# GitOps Policy for ConfigMap Management

## Incident Summary
**Date:** 2026-03-19  
**Namespace:** bank-of-hill-valley-demo19-1773948697  
**Issue:** ConfigMap `ledger-db-config` was manually edited with typo `SPRING_DATASOURCE_URL_oops`, causing `ledgerwriter` deployment failure.

## Root Cause
Direct cluster modification via `kubectl edit` or manual patch bypassed version control, introducing a typo that wasn't caught by code review or CI validation.

## Policy

### ALL ConfigMaps MUST be managed through GitOps:
1. **No direct kubectl edits** - All changes must go through this repository
2. **Pull Request required** - Every ConfigMap change needs review
3. **CI validation** - Pre-merge validation of required keys (future enhancement)
4. **ArgoCD/Flux enforcement** - ConfigMaps should be synced from Git (future enhancement)

### Required Keys for ledger-db-config:
- `SPRING_DATASOURCE_URL` (NOT `SPRING_DATASOURCE_URL_oops`)
- `SPRING_DATASOURCE_USERNAME`
- `SPRING_DATASOURCE_PASSWORD`
- `POSTGRES_DB`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`

## Validation
Before merging ConfigMap changes:
1. Check for typos in environment variable names
2. Verify deployments reference correct keys
3. Test in non-production namespace first

## Future Enhancements
- [ ] Implement ArgoCD Application for bank-of-hill-valley namespace
- [ ] Add admission webhook to validate ConfigMap keys
- [ ] Add CI step to check referenced env vars exist in ConfigMaps
- [ ] Block direct cluster modifications via RBAC policies
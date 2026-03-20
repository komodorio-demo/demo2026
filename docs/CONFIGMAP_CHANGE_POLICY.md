# ConfigMap Change Policy

## Incident: 2026-03-19 - Ledger DB ConfigMap Typo

### What Happened
A manual `kubectl edit` or patch introduced a typo in the `ledger-db-config` ConfigMap:
- **Incorrect key**: `SPRING_DATASOURCE_URL_oops` 
- **Correct key**: `SPRING_DATASOURCE_URL`

This typo was NOT present in Git repository — it was introduced directly in the cluster, bypassing version control.

### Impact
- `ledgerwriter` deployment failed to start (0/1 ready)
- Application couldn't connect to database due to missing environment variable

### Resolution
1. **Immediate**: `kubectl patch` to rename the key back to `SPRING_DATASOURCE_URL`
2. **Long-term**: Implement GitOps workflow to prevent manual changes

## Prevention Measures

### 1. GitOps Workflow (Required)
Implement ArgoCD or Flux to manage ConfigMaps:
- All changes must go through Git
- Prevent manual `kubectl edit` or patches
- Auto-sync from repository

### 2. Admission Webhook (Recommended)
Add validation webhook to verify:
- Required environment variable keys exist in referenced ConfigMaps
- Changes to ConfigMaps trigger validation before apply
- Block changes that don't match expected schema

### 3. CI Validation (Recommended)
Add pre-commit hooks and CI checks:
- Validate ConfigMap key names against required schema
- Run integration tests that verify all required env vars are present
- Fail PR if validation fails

## Best Practices
1. Never use `kubectl edit` or manual patches for ConfigMaps in production
2. All changes must be committed to Git first
3. Use declarative configuration (YAML files) only
4. Implement automated validation at multiple stages
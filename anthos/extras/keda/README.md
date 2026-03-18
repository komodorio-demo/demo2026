# KEDA Installation for Payment Processor Auto-Scaling

## Installation Methods

Choose one method based on your deployment strategy:

### Method 1: ArgoCD (Recommended if ArgoCD is installed)

Install KEDA via ArgoCD:
```bash
kubectl apply -f argocd-application.yaml
```

This creates an ArgoCD Application that installs KEDA operator from the official Helm chart.

Verify ArgoCD Application:
```bash
kubectl get application keda -n argocd
argocd app get keda
```

After KEDA is installed by ArgoCD, apply the ScaledObject directly:
```bash
kubectl apply -f ../../manifests/payment-processor-scaledobject.yaml
```

### Method 2: Direct kubectl apply

**Step 1:** Install KEDA namespace:
```bash
kubectl apply -f namespace.yaml
```

**Step 2:** Install KEDA operator:
```bash
kubectl apply --server-side -f https://github.com/kedacore/keda/releases/download/v2.15.1/keda-2.15.1.yaml
```

**Step 3:** Apply payment-processor ScaledObject:
```bash
kubectl apply -f ../../manifests/payment-processor-scaledobject.yaml
```

### Method 3: Using Helm directly

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --namespace keda --create-namespace --version 2.15.1

# Then apply ScaledObject
kubectl apply -f ../../manifests/payment-processor-scaledobject.yaml
```

## Verify Installation

Check KEDA pods are running:
```bash
kubectl get pods -n keda
```

Expected output:
```
NAME                                      READY   STATUS    RESTARTS   AGE
keda-operator-xxxxx                       1/1     Running   0          1m
keda-metrics-apiserver-xxxxx              1/1     Running   0          1m
```

Verify ScaledObject:
```bash
kubectl get scaledobject -n bank-of-singapore-demo10-1773848223
kubectl describe scaledobject payment-processor-scaler -n bank-of-singapore-demo10-1773848223
```

KEDA creates an HPA automatically:
```bash
kubectl get hpa -n bank-of-singapore-demo10-1773848223
```

## Monitor Auto-Scaling

Watch scaling activity:
```bash
kubectl get hpa -n bank-of-singapore-demo10-1773848223 -w
```

Check KEDA metrics:
```bash
kubectl get scaledobject payment-processor-scaler -n bank-of-singapore-demo10-1773848223 -o jsonpath='{.status}' | jq
```

View ScaledObject events:
```bash
kubectl describe scaledobject payment-processor-scaler -n bank-of-singapore-demo10-1773848223
```
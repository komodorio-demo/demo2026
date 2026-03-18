# KEDA Installation for Payment Processor Auto-Scaling

## Quick Install

Install KEDA namespace:
```bash
kubectl apply -f namespace.yaml
```

Install KEDA operator (choose one method):

### Method 1: Direct kubectl apply (Recommended)
```bash
kubectl apply --server-side -f https://github.com/kedacore/keda/releases/download/v2.15.1/keda-2.15.1.yaml
```

### Method 2: Using Helm
```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --namespace keda --version 2.15.1
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

## Apply Payment Processor ScaledObject

After KEDA is installed, apply the ScaledObject:
```bash
kubectl apply -f ../../manifests/payment-processor-scaledobject.yaml
```

Verify ScaledObject:
```bash
kubectl get scaledobject -n bank-of-singapore-demo10-1773848223
kubectl describe scaledobject payment-processor-scaler -n bank-of-singapore-demo10-1773848223
```

KEDA will create an HPA automatically:
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
kubectl get scaledobject payment-processor-scaler -n bank-of-singapore-demo10-1773848223 -o jsonpath='{.status.conditions}' | jq
```
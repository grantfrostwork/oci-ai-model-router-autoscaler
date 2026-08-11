# OCI AI Model Router and Autoscaler

This repository contains the recovered infrastructure and Kubernetes source for the `inference-poc` OKE deployment in OCI `us-ashburn-1`.

## Repository layout

- `10-network/` manages the VCN, subnets, routing, security list, and NSGs.
- `20-cluster/` manages the enhanced OKE cluster, system node pool, and Karpenter workload-identity policy.
- `Kubernetes/` contains the Karpenter, vLLM, semantic-router, Gateway API, and monitoring manifests and values.

Terraform must be run from one of the numbered stack directories. The repository root intentionally has no Terraform backend, which prevents an empty root configuration from targeting the live cluster state.

## Prerequisites

- Terraform 1.12 or newer (`.terraform-version` selects 1.15.8 for version managers).
- OCI CLI authenticated with the `DEFAULT` profile.
- Access to Object Storage bucket `tfstate-inference-poc` in `us-ashburn-1`.
- `kubectl` and Helm for the Kubernetes resources.

## Terraform workflow

Create the local network inputs before initializing the stack:

```bash
cp 10-network/terraform.tfvars.example 10-network/terraform.tfvars
```

Set `my_ip_cidr` in the local file to the exact public CIDR allowed to reach the OKE API endpoint. Then validate and review both live-state plans:

```bash
terraform -chdir=10-network init
terraform -chdir=10-network validate
terraform -chdir=10-network plan

terraform -chdir=20-cluster init
terraform -chdir=20-cluster validate
terraform -chdir=20-cluster plan
```

Do not apply a plan until its resource changes have been reviewed. The network stack must be applied before the cluster stack when both require changes.

## Kubernetes access

After the workstation CIDR is allowed by `api-nsg`, generate a separate kubeconfig without changing another current context:

```bash
oci ce cluster create-kubeconfig \
  --profile DEFAULT \
  --region us-ashburn-1 \
  --cluster-id ocid1.cluster.oc1.iad.aaaaaaaa2dfqxema5mgzbityvjgw4vmgldh4w4fxyrots7xfmc4oufqzxwpa \
  --file /tmp/inference-poc-kubeconfig \
  --token-version 2.0.0 \
  --kube-endpoint PUBLIC_ENDPOINT

kubectl --kubeconfig /tmp/inference-poc-kubeconfig get nodes
```

The Kubernetes manifests must be checked against the CRDs installed in the cluster before changes are applied. In particular, use `kubectl explain` and server-side dry runs for `OCINodeClass`, `NodePool`, and Envoy AI Gateway resources.

## Inference autoscaling

The model tiers use StatefulSets so every replica receives its own dynamically
provisioned OCI Block Volume. PVCs are retained on scale-down so a returning
ordinal can reuse its downloaded model weights. The original singleton
`hf-cache-cpu` and `hf-cache-gpu` claims are migration artifacts and can be
deleted only after the StatefulSet replicas are healthy and their new claims
are verified.

KEDA 2.20.2 reads the existing vLLM Prometheus metrics and scales on total
in-flight work (`running + waiting`):

- CPU: 1-7 serving replicas, target 4 in-flight requests per replica.
- GPU: 1-3 serving replicas, target 2 in-flight requests per replica.
- Scale-down is deliberately slow because model and node cold starts take
  minutes.

Each tier also has one low-priority pause pod. It requests the same schedulable
resources as a serving replica, causing Karpenter to maintain one N+1 node.
Serving pods preempt the placeholder during a burst; Karpenter then provisions
a replacement node for the newly pending placeholder.

The CPU NodePool permits 128 Kubernetes CPU units, which fits eight current
16-vCPU nodes: seven model replicas plus one warm spare. The GPU NodePool is
capped at four A10 GPUs: three model replicas plus one warm spare.

Install KEDA before applying its ScaledObjects:

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update kedacore
helm upgrade --install keda kedacore/keda \
  --version 2.20.2 \
  --namespace keda \
  --create-namespace \
  --values Kubernetes/keda-values.yaml
```

Apply the resources in this order:

```bash
kubectl apply -f Kubernetes/cpu-nodepool.yaml
kubectl apply -f Kubernetes/gpu-nodepool.yaml
kubectl apply -f Kubernetes/overprovisioning.yaml
kubectl apply -f Kubernetes/cpu-tier.yaml
kubectl apply -f Kubernetes/gpu-tier.yaml
kubectl apply -f Kubernetes/vllm-servicemonitor.yaml
kubectl apply -f Kubernetes/keda-vllm-scalers.yaml
kubectl apply -f Kubernetes/gwapi-resources.yaml
```

When migrating from the original Deployments, allow each new StatefulSet pod
to become Ready before deleting the same-named Deployment. Both controllers
can temporarily coexist because they are different resource kinds, and the
stable Service selects both during the transition.

Verify the scaling chain independently at each layer:

```bash
kubectl get scaledobject,hpa -n inference
kubectl get statefulset,pod,pvc -n inference -w
kubectl get nodepool,nodeclaim -w
kubectl get nodes -L inference-tier,karpenter.sh/nodepool
```

For a bounded, request-driven smoke test, send enough concurrent work to cross
one KEDA target. Explicit model names make the tier selection deterministic:

```bash
# CPU target is 4; ten requests should produce a desired replica count of 3.
seq 1 10 | xargs -P 10 -I{} curl -sS --max-time 120 -o /dev/null \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen-small","messages":[{"role":"user","content":"Write a detailed production Kubernetes platform guide. Continue until the response limit."}],"max_tokens":512}' \
  http://GATEWAY_ADDRESS/v1/chat/completions

# GPU target is 2; four requests should produce a desired replica count of 2.
seq 1 4 | xargs -P 4 -I{} curl -sS --max-time 120 -o /dev/null \
  -H 'Content-Type: application/json' \
  -d '{"model":"gpt-oss-20b","messages":[{"role":"user","content":"Analyze production inference scaling tradeoffs. Continue until the response limit."}],"max_tokens":512}' \
  http://GATEWAY_ADDRESS/v1/chat/completions
```

Watch `running + waiting`, the KEDA HPA, PVC creation, placeholder preemption,
and NodeClaims during the test. To end a test without waiting for the production
scale-down stabilization windows, temporarily pin the tier to one replica and
then immediately restore KEDA control after the metric reaches zero:

```bash
kubectl annotate scaledobject vllm-cpu vllm-gpu -n inference \
  autoscaling.keda.sh/paused-replicas='1' --overwrite
kubectl annotate scaledobject vllm-cpu vllm-gpu -n inference \
  autoscaling.keda.sh/paused-replicas-
```

For a deterministic scheduling test, temporarily scale a tier to two replicas.
The second serving pod should preempt the warm placeholder, and the replacement
placeholder should become Pending until Karpenter registers a new node:

```bash
kubectl scale statefulset/vllm-cpu -n inference --replicas=2
kubectl scale statefulset/vllm-gpu -n inference --replicas=2
```

KEDA owns the replica field after its ScaledObject is installed, so use this
manual test only while the corresponding ScaledObject is paused or absent.

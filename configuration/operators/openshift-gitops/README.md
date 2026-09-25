#  OpenShift GitOps Operator

Installs the Red Hat OpenShift GitOps Operator and configures the ArgoCD
instance it manages.

## Dependencies
- None

## Details
Minimum OpenShift Version: 4.12

Documentation: [latest](https://docs.redhat.com/en/documentation/red_hat_openshift_gitops/latest)

---
**Notes:**
  - Subscription installs into a dedicated `openshift-gitops-operator`
    namespace (paired with an `OperatorGroup`), not the shared
    `openshift-operators` namespace
  - `subscription.channel` is parameterized via `values.yaml` — override per
    cluster with a `helm-values/openshift-gitops.yml` file (see
    `clusters/prod-cluster-01/helm-values/openshift-gitops.yml` for an
    example pinning `gitops-1.21`)
  - Configures ArgoCD to use annotation-based resource tracking, HA, and
    dex SSO with OpenShift OAuth
  - Enables notifications but does not configure notification destinations
  - `templates/consolelink.yml` requires `argocd.routeHost` to be set
    per-cluster — it can't be derived automatically like it can in an
    ACM-hub-templated policy, because `kustomize build --enable-helm` shells
    out to `helm template`, which has no live-cluster connection for a
    `lookup`
  - `templates/argo-admin-clusterroles.yml` adds generic admin-aggregated
    `ClusterRole`s (namespaces/OperatorGroups/ClusterRoles) for future use;
    not required for a single-cluster install

## Implementation Details

Spec content in `templates/argocd-instance.yml` (resource sizing, HA,
monitoring/notifications, dex SSO, the Tekton `resourceExclusions`) was
evaluated from `kustomize build` output on
`acm-policy-samples/policies/operators/gitops/argocd-instances/default` and
carried over as-is, generalized to drop that repo's personal/team-specific
RBAC groups in favor of a single `rbac.adminGroup` value.

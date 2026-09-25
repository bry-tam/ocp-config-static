---
# Bootstrap Runbook

Concrete, copy/pasteable steps for taking a fresh OpenShift cluster from "just
installed" to "fully managed by this repo's Argo CD `Application`". This fills
in the manual steps that `bootstrap/root-application.yml` and the top-level
`README.md` describe at a high level but don't spell out with commands.

This assumes you're bootstrapping `clusters/prod-cluster-01` (the only example
in this repo today) against a cluster you already have `oc` admin access to.
If you add a new cluster directory, substitute its name and its own
`root-application.yml` copy throughout.

## Prerequisites

- `oc` logged in (or `KUBECONFIG` pointed at) the target cluster as a user
  with cluster-admin.
- `helm` available locally (used once, in Phase 1, to install the GitOps
  operator itself — every other component is applied by Argo CD afterward).
- This repo's `main` branch pushed to a location reachable from inside the
  cluster (`bootstrap/root-application.yml`'s `spec.source.repoURL` uses the
  plain HTTPS GitHub URL, so if the repo is private you'll need to either make
  it public or add an Argo CD `Repository` credential Secret — neither is set
  up by default here).

### Per-cluster values to set before bootstrapping

`clusters/<cluster_name>/helm-values/openshift-gitops.yml` should set
`argocd.routeHost` to that cluster's real Argo CD route host, e.g.:

```yaml
argocd:
  routeHost: openshift-gitops-server-openshift-gitops.apps.<cluster-apps-domain>
```

The chart's own `values.yaml` default is `""`. If left unset, the
`ConsoleLink` this chart creates renders with an empty host
(`href: https://`), which is broken. You can find the cluster's apps domain
with:

```sh
oc get ingress.config.openshift.io cluster -o jsonpath='{.spec.domain}'
```

The route host itself follows OpenShift's standard `<service>-<namespace>.apps.<domain>`
convention for the `openshift-gitops-server` Route in the `openshift-gitops`
namespace.

## Phase 1 — Install the OpenShift GitOps Operator (manual, out-of-band)

This is the one component Argo CD can't install for itself — it doesn't exist
yet. Render this repo's `openshift-gitops` chart directly with Helm and apply
it once:

```sh
helm template openshift-gitops configuration/operators/openshift-gitops \
  -f clusters/prod-cluster-01/helm-values/openshift-gitops.yml \
  | oc apply -f -
```

This creates the `openshift-gitops-operator` and `openshift-gitops`
namespaces, the `OperatorGroup`/`Subscription` for the operator, the `ArgoCD`
custom resource, the `cluster-admins` RBAC `Group` (empty — add users to it
afterward), the aggregated `ClusterRole`s, and the `ConsoleLink`.

Wait for the operator's CSV to succeed:

```sh
oc get csv -n openshift-gitops-operator -w
```

Then wait for the Argo CD instance and its pods to come up healthy:

```sh
oc get argocd openshift-gitops -n openshift-gitops
oc get pods -n openshift-gitops
```

## Phase 2 — Hand off to Argo CD

Apply the root `Application` once, manually:

```sh
oc apply -f bootstrap/root-application.yml
```

From this point on, Argo CD owns everything under `clusters/prod-cluster-01`
— including reconciling the `openshift-gitops` chart itself (Phase 1's manual
apply becomes a normal Argo CD-managed resource going forward).

Watch it sync:

```sh
oc get application prod-cluster-01 -n openshift-gitops -w
```

Wait for `SYNC STATUS` = `Synced` and `HEALTH STATUS` = `Healthy`.

## Phase 3 — Verify

Once synced, Argo CD will have applied every component declared in
`clusters/prod-cluster-01/kustomization.yaml`. For each operator, confirm its
CSV succeeded and its custom resource reached a ready state:

```sh
oc get csv -A | grep -Ev '^NAMESPACE|Succeeded'   # should be empty
oc get hyperconverged -n openshift-cnv
oc get nmstate -n openshift-nmstate
oc get kubedeschedulers -n openshift-kube-descheduler-operator
oc get forkliftcontroller -n openshift-mtv
oc get nodehealthcheck
```

Two side effects are expected and not failures:

- **descheduler's `MachineConfig`** (`workerKernelArgs.enabled: true` by
  default) adds a `psi=1` kernel argument to worker nodes, which triggers a
  rolling reboot of every worker via the Machine Config Pool. Expect
  `oc get mcp worker` to show `UPDATING=True` for several minutes per node.
- **workload-availability's console plugin manifest**
  (`consolePlugin.enabled: true` by default) replaces `Console.spec.plugins`
  entirely rather than appending to it. On a cluster with no other console
  plugins already enabled this is harmless; on one that already has plugins
  enabled, this will silently disable them. Confirm the result matches
  expectations:

  ```sh
  oc get console.config cluster -o jsonpath='{.spec.plugins}'
  ```

Finally, confirm the `ConsoleLink` added in Phase 1 now points at a working
route instead of `https://`:

```sh
oc get consolelink openshift-gitops -o jsonpath='{.spec.href}'
```

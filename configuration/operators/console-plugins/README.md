#  Console Plugins

Centrally manages the cluster-scoped `operator.openshift.io/v1 Console`
singleton's `spec.plugins` list, so that components registering a console
plugin (e.g. the Node Remediation plugin from Workload Availability) don't
each need to do their own full-object apply against the same singleton —
which would overwrite `spec.plugins` and drop plugins enabled by other
components.

## Dependencies
- None

## Details
Minimum OpenShift Version: 4.12

Documentation: [Console plugins](https://docs.redhat.com/en/documentation/openshift_container_platform/latest/html/web_console/custom-admin-console-plugins)

---
**Notes:**
  - All plugins default to `enabled: false` in `values.yaml` — a per-cluster
    `helm-values/console-plugins.yml` override must explicitly enable each
    one it wants
  - **`spec.plugins` is an atomic list (no merge semantics):** the
    `operator.openshift.io/v1 Console` CRD doesn't mark `spec.plugins` as a
    `x-kubernetes-list-type: set`, so a full-object apply — which is what
    this chart does — REPLACES the entire list rather than merging into it.
    Any plugin not enabled in a given cluster's values will be dropped on
    the next Argo CD sync/self-heal, even if another operator registered it
    moments earlier. This means per-cluster values must enumerate every
    plugin that should be active, including ones auto-registered by other
    operators/the platform (e.g. `networking-console-plugin` and
    `monitoring-plugin` ship enabled by default on every OpenShift cluster;
    `nmstate-console-plugin`, `kubevirt-plugin`, and
    `forklift-console-plugin` are auto-registered once their respective
    operators are installed) — not just plugins that previously needed
    manual help
  - Renders no resource at all if every plugin is disabled (rather than an
    empty `spec.plugins: []`), since either would still be a full-object
    apply against a cluster-wide singleton
  - To register a new plugin, add a new key under `plugins` in
    `values.yaml` (`enabled`/`name`) — `templates/console.yml` picks it up
    automatically, no template changes needed
  - Doesn't create or manage any namespaced resources; the `namespace:` set
    on this chart's `helmCharts:` entry has no effect on what it renders
  - Lives under `configuration/operators/` (not a more accurate category
    like `configuration/console/`) because `kustomize build --enable-helm`
    requires every `helmCharts:` entry in a kustomization to share one
    `helmGlobals.chartHome`, and a chart `name:` containing a path
    separator breaks kustomize's scratch-values-file generation — see
    `clusters/prod-cluster-01/kustomization.yaml`

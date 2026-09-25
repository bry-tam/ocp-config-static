#  OpenShift Virtualization Operator

Installs the OpenShift Virtualization Operator (CNV) and configures a
`HyperConverged` instance with live migration limits.

## Dependencies
- None

## Details
Minimum OpenShift Version: 4.14

Documentation: [latest](https://docs.redhat.com/en/documentation/openshift_container_platform/latest/html/virtualization/index)

---
**Notes:**
  - Namespace `openshift-cnv` is labeled `openshift.io/cluster-monitoring: "true"` so virtualization metrics are scraped by Prometheus
  - `OperatorGroup` is namespace-scoped (`targetNamespaces: [openshift-cnv]`) — OpenShift Virtualization is not an AllNamespaces operator
  - Live migration limits (`hyperConverged.liveMigration`) default to KubeVirt's own defaults: 5 parallel migrations per cluster, 2 outbound per node, 150s progress timeout, 800s completion timeout per GiB
  - `hyperConverged.liveMigration.network` is unset by default (uses the pod network); set it to a dedicated interface (e.g. `bond3.999`) if the cluster has one for migration traffic — hardware-specific, must be set per-cluster
  - `hyperConverged.liveMigration.parallelMigrationsPerCluster`/`parallelOutboundMigrationsPerNode` are also referenced by [`descheduler`](../descheduler/)'s `evictionLimits` — keep both charts' values in sync if you change these; a live ACM hub could derive that relationship dynamically via `lookup`, but plain `helm template` cannot

## Implementation Details

Evaluated from `acm-policy-samples/policies/operators/virtualization/`. The
`OperatorPolicy`'s `subscription`/`operatorGroup` blocks became
`templates/subscription.yml`/`templates/operatorgroup.yml`; the
`HyperConverged` CR became `templates/hyperconverged.yml`, parameterized via
`values.yaml` instead of hardcoded.

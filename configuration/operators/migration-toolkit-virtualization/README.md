#  Migration Toolkit for Virtualization Operator

Installs the Migration Toolkit for Virtualization (MTV) Operator and creates
a `ForkliftController` instance to enable VM migration from external
hypervisors (VMware, oVirt, OpenStack) to OpenShift Virtualization.

## Dependencies
- [`virtualization`](../virtualization/) — MTV migrates VMs *to* OpenShift
  Virtualization; it installs fine without it but is not useful without a
  target virtualization platform running on the same cluster

## Details
Minimum OpenShift Version: 4.14

Documentation: [latest](https://docs.redhat.com/en/documentation/migration_toolkit_for_virtualization/latest)

---
**Notes:**
  - `OperatorGroup` is namespace-scoped (`targetNamespaces: [openshift-mtv]`)
  - Namespace is labeled `openshift.io/cluster-monitoring: "true"` to enable Prometheus scraping of MTV metrics
  - `subscription.channel` is pinned to a versioned channel (`release-v2.12`) rather than `stable`, matching the reference config's guidance to avoid unexpected major-version jumps

## Implementation Details

Evaluated from `acm-policy-samples/policies/operators/migration-toolkit/`.
The `OperatorPolicy`'s `subscription`/`operatorGroup` blocks became
`templates/subscription.yml`/`templates/operatorgroup.yml`; the
`ForkliftController` CR became `templates/forkliftcontroller.yml`,
parameterized via `values.yaml`.

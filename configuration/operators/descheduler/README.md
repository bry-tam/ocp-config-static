#  Descheduler Operator

Installs the Kube Descheduler Operator and configures a `KubeDescheduler`
instance with the `KubeVirtRelieveAndMigrate` profile, which evicts VM pods
from overutilized nodes so KubeVirt can live-migrate them elsewhere.

## Dependencies
- [`virtualization`](../virtualization/) — not a hard install-time
  dependency (the descheduler installs fine on its own), but
  `descheduler.evictionLimits` should be kept in sync with that chart's
  `hyperConverged.liveMigration.parallelMigrationsPerCluster`/
  `parallelOutboundMigrationsPerNode`, see Notes below

## Details
Minimum OpenShift Version: 4.10

Documentation: [latest](https://docs.redhat.com/en/documentation/openshift_container_platform/latest/html/nodes/evicting-pods-using-the-descheduler)

---
**Notes:**
  - `OperatorGroup` is namespace-scoped (`targetNamespaces: [openshift-kube-descheduler-operator]`)
  - `descheduler.evictionLimits` (`total`/`node`) are static values here —
    the ACM reference this was evaluated from derives them dynamically via a
    hub `lookup` against the `virtualization` chart's `HyperConverged` CR,
    which isn't possible in plain `helm template` (no live-cluster
    connection). Defaults match KubeVirt's own built-in defaults (5/2)
  - `KubeVirtRelieveAndMigrate` and the `LongLifecycle`/
    `LifecycleAndUtilization` profiles are mutually exclusive — do not
    combine them in `descheduler.profiles`
  - `workerKernelArgs.enabled` (default `true`) adds the `psi=1` kernel
    argument to worker nodes via a `MachineConfig` — required for the
    CPU/PSI-utilization-aware `DevKubeVirtRelieveAndMigrate` profile, not
    the `KubeVirtRelieveAndMigrate` profile configured by default here, but
    kept enabled to allow switching profiles without a node reboot cycle
    later; a `MachineConfig` change does trigger a worker reboot the first
    time it's applied

## Implementation Details

Evaluated from `acm-policy-samples/policies/operators/descheduler/`. The
`OperatorPolicy`'s `subscription`/`operatorGroup` blocks became
`templates/subscription.yml`/`templates/operatorgroup.yml`; the
`KubeDescheduler` CR (originally using `object-templates-raw` with a hub
`lookup`/`dig` against `HyperConverged`) became `templates/kubedescheduler.yml`
with static `values.yaml`-driven eviction limits; the `MachineConfig` was
carried over as-is into `templates/worker-kernelargs.yml`, gated by
`workerKernelArgs.enabled`.

#  Workload Availability Operator

Installs the Workload Availability for Red Hat OpenShift operator bundle —
Node Health Check (NHC), Self Node Remediation (SNR), Fence Agents
Remediation (FAR), Node Maintenance, and Machine Deletion Remediation (MDR)
— into a single shared namespace, and configures an example
`NodeHealthCheck` with escalating remediation templates to automatically
recover workloads from unhealthy nodes.

## Dependencies
- None

## Details
Minimum OpenShift Version: 4.14

Documentation: [latest](https://docs.redhat.com/en/documentation/workload_availability_for_red_hat_openshift/latest)

---
**Notes:**
  - All 5 operators install into a single namespace
    (`openshift-workload-availability`, labeled
    `openshift.io/cluster-monitoring: "true"`) sharing a single AllNamespaces
    `OperatorGroup` — the ACM reference's `OperatorPolicy` for each operator
    omits an explicit `operatorGroup` block, meaning ACM auto-creates one on
    first install; since only one `OperatorGroup` may exist per namespace,
    this chart defines it once explicitly instead of once per operator
  - `remediation.strategy` selects `snr` (default) or `far` as the first
    escalation step for unhealthy nodes — mutually exclusive, templated via
    `values.yaml` instead of the reference's comment/uncomment blocks in its
    generator, so switching strategies doesn't require editing YAML
  - Machine Deletion Remediation always runs as the final escalation step
    (order 1) regardless of `remediation.strategy`, recreating the
    underlying `Machine` if the first remediation step doesn't recover the
    node within `remediation.nodeHealthCheck.escalationTimeout`
  - The `far` strategy's `FenceAgentsRemediationTemplate` needs a fencing
    agent configured — this is environment-specific (depends on the
    out-of-band management hardware available) and is left unset; see the
    doc link in `templates/remediation-templates.yml`
  - The Node Remediation console plugin (`node-remediation-console-plugin`)
    is registered via the `configuration/operators/console-plugins` chart,
    not here — see that chart for why `Console`/`cluster` plugin
    registration is centralized instead of each component doing its own
    full-object apply

## Implementation Details

Evaluated from `acm-policy-samples/policies/operators/workload-availability/`.
The 5 operators' `OperatorPolicy` `subscription` blocks became
`templates/subscriptions.yml` (one multi-document file); the shared
`OperatorGroup` became `templates/operatorgroup.yml`. The reference's
mutually-exclusive SNR/FAR remediation manifests (switched by
commenting/uncommenting `generator.yml` entries) were consolidated into
`templates/nodehealthcheck.yml` and `templates/remediation-templates.yml`,
each with an `{{- if eq .Values.remediation.strategy ... }}` branch per
variant, so the choice is a single `values.yaml` field
(`remediation.strategy`) instead of a generator edit. The reference's
`node-remediation-console.yml` `Console` patch — originally gated via
`extraDependencies` on the NHC `OperatorPolicy` being `Compliant` (no
equivalent ordering mechanism exists in plain Helm/kustomize) — was moved
out of this chart entirely into `configuration/operators/console-plugins`,
which centralizes `Console`/`cluster` plugin registration across all
components instead of each one doing its own full-object apply.

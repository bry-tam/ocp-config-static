#  NMState Operator

Installs the Kubernetes NMState Operator into the `openshift-nmstate`
namespace, enabling declarative node network configuration management via
`NodeNetworkConfigurationPolicy` resources.

## Dependencies
- None

## Details
Minimum OpenShift Version: 4.9

Documentation: [latest](https://docs.redhat.com/en/documentation/openshift_container_platform/latest/html/networking/kubernetes-nmstate)

---
**Notes:**
  - `OperatorGroup` has no `targetNamespaces` (AllNamespaces install mode), matching the reference config
  - `nmstate.probeConfiguration.dns.host` defaults to `root-servers.net`, used by the operator to verify network reachability after applying a policy before rolling it out cluster-wide

## Implementation Details

Evaluated from `acm-policy-samples/policies/operators/nmstate/`. The
`OperatorPolicy`'s `subscription`/`operatorGroup` blocks became
`templates/subscription.yml`/`templates/operatorgroup.yml`; the `NMState` CR
became `templates/nmstate.yml`, parameterized via `values.yaml`.

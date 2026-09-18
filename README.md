# ocp-config-static

Example repo for managing OpenShift day-2 configuration with **just the
OpenShift GitOps Operator** (Argo CD) and **kustomize** — no ApplicationSet
controller, no app-of-apps layer. One Argo CD `Application` points at one
kustomize entrypoint per cluster, and `kustomize build` on that entrypoint
emits the final resources directly. Kustomize is the primary templating
mechanism, but individual `configuration/` components may be implemented as
local Helm charts (inflated via kustomize's `helmCharts:` generator) when
that's a better fit — see `configuration/operators/openshift-gitops/` below.

All YAML files use the `.yml` extension, except `kustomization.yaml` (kept
`.yaml` to match kustomize's own default/canonical filename) and Helm's
`Chart.yaml`/`values.yaml` (filenames Helm requires verbatim).

## Concepts

- **`bootstrap/`** — the single manifest that is *not* managed by Argo CD
  (it can't sync the `Application` object that creates it). Applied once,
  manually, after the OpenShift GitOps Operator is installed:

  ```sh
  oc apply -f bootstrap/root-application.yml
  ```

  From then on, Argo CD watches `clusters/prod-cluster-01` and manages
  everything else in this repo, including its own configuration.

- **`clusters/<cluster_name>/`** — the GitOps entrypoint. Each cluster gets
  one directory here with a `kustomization.yaml` that is the literal
  `spec.source.path` of that cluster's `Application`. This repo has one
  example cluster, `prod-cluster-01`. Running:

  ```sh
  kustomize build --enable-helm --load-restrictor LoadRestrictionsNone clusters/prod-cluster-01
  ```

  must produce the final resources to apply to the cluster — no nested
  `Application`/`ApplicationSet` objects, no app-of-apps. `--enable-helm` is
  needed because this cluster's `kustomization.yaml` declares `helmCharts:`
  to inflate local Helm-chart components (see below); `--load-restrictor
  LoadRestrictionsNone` is needed because those charts live under
  `configuration/`, outside the cluster kustomization's own directory tree.
  Both are no-ops if a given cluster doesn't use any Helm-chart components.

- **`configuration/<category>/<component>/`** — the actual configuration,
  organized by logical category (e.g. `operators/`, and in the future
  `monitoring/`, `ingress/`, etc. as they're added). Each `<component>/` is
  either a plain kustomize `Kustomization` holding base manifests, or a local
  Helm chart (the `<component>/` directory itself *is* the chart — `Chart.yaml`,
  `values.yaml`, `templates/` — no `charts/` wrapper subdirectory). Components
  here never derive from anything else — they're leaf bases. The one example
  today is `configuration/operators/openshift-gitops/`, a local Helm chart
  that installs the OpenShift GitOps Operator (its OLM `Subscription`, with
  `subscription.channel` parameterized via the chart's `values.yaml`), the
  operator's own Argo CD instance (the `ArgoCD` custom resource), and related
  RBAC.

  Helm-chart components are inflated from the *cluster* level, not the
  component level: a `clusters/<cluster_name>/kustomization.yaml` declares
  `helmGlobals.chartHome` (pointing at the chart's parent category dir) and a
  `helmCharts:` entry naming the chart. This is what lets a given cluster
  override chart values — e.g. pin a different `subscription.channel` — via
  `valuesFile:`/`valuesInline:` on that same `helmCharts:` entry, without
  touching the component itself. See
  `clusters/prod-cluster-01/kustomization.yaml` for the working example.

- **`kustomize-config/<name>/`** — cross-cutting kustomize configuration.
  **Every directory under here must be a kustomize `Component`**
  (`apiVersion: kustomize.config.k8s.io/v1alpha1`, `kind: Component`), never
  a plain `Kustomization`, and must never carry its own `resources:` — only
  transformers, patches, labels, etc. applied on top of resources supplied by
  `configuration/`. This lets a cluster's `kustomization.yaml` compose
  whichever components it needs via `components:`. The example here,
  `common-labels`, adds a couple of common labels to every resource built for
  a cluster.

- **`build/`** — scripts used by CI (`.github/workflows/validate.yml`):
  - `validate-end-of-file.sh` — every file must end with a newline.
  - `validate-trailing-whitespace.sh` — no trailing whitespace anywhere.
  - `validate-yaml-doc.sh` — every `.yml`/`.yaml` file must start with `---`.
  - `validate-kubeconform.sh` — renders every `clusters/<name>` entrypoint
    with `kustomize build` and validates the output with
    [kubeconform](https://github.com/yannh/kubeconform), using both
    kubeconform's built-in core-Kubernetes schemas and
    [Datree's CRDs-catalog](https://github.com/datreeio/CRDs-catalog) for
    CRDs (e.g. Argo CD's `Application`). Types present in neither catalog
    (for example the GitOps Operator's own `ArgoCD` CR, which isn't
    published to CRDs-catalog) are skipped rather than failed, via
    `-ignore-missing-schemas`.

## Local debugging

```sh
# Render everything that would be applied to prod-cluster-01
kustomize build --enable-helm --load-restrictor LoadRestrictionsNone clusters/prod-cluster-01

# Run the same checks CI runs
./build/validate-end-of-file.sh
./build/validate-trailing-whitespace.sh
./build/validate-yaml-doc.sh
./build/validate-kubeconform.sh
```

## Adding a new cluster

1. Create `clusters/<cluster_name>/kustomization.yaml` listing the
   `configuration/` resources/`helmCharts:` and `kustomize-config/` components
   it needs.
2. Copy `bootstrap/root-application.yml`, rename it, and update
   `metadata.name` and `spec.source.path`.
3. Apply the new `Application` manifest once, manually, on that cluster.

## Adding a new configuration component

Create `configuration/<category>/<component>/` as either:

- a plain `kustomization.yaml` + manifests, referenced from a cluster's
  `resources:`, or
- a local Helm chart — `Chart.yaml`/`values.yaml`/`templates/` directly in
  `<component>/`, no wrapping `kustomization.yaml` and no `charts/`
  subdirectory (see `configuration/operators/openshift-gitops/` for a full
  example, including a parameterized value). Reference it from a cluster's
  `helmGlobals.chartHome` + `helmCharts:` (see
  `clusters/prod-cluster-01/kustomization.yaml`) rather than `resources:`.

Reuse an existing category (e.g. `operators/`) or introduce a new one (e.g.
`monitoring/`, `ingress/`) if it doesn't fit an existing category.

## Adding a new kustomize-config component

Create `kustomize-config/<name>/kustomization.yaml` with
`apiVersion: kustomize.config.k8s.io/v1alpha1` and `kind: Component`. Add
transformers/patches/labels as needed, but no `resources:`. Reference it from
whichever `clusters/<cluster_name>/kustomization.yaml` should apply it.

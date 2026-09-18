# ocp-config-static

Example repo for managing OpenShift day-2 configuration with **just the
OpenShift GitOps Operator** (Argo CD) and **kustomize** — no Helm, no
ApplicationSet controller, no app-of-apps layer. One Argo CD `Application`
points at one kustomize entrypoint per cluster, and `kustomize build` on that
entrypoint emits the final resources directly.

## Concepts

- **`bootstrap/`** — the single manifest that is *not* managed by Argo CD
  (it can't sync the `Application` object that creates it). Applied once,
  manually, after the OpenShift GitOps Operator is installed:

  ```sh
  oc apply -f bootstrap/root-application.yaml
  ```

  From then on, Argo CD watches `clusters/prod-cluster-01` and manages
  everything else in this repo, including its own configuration.

- **`clusters/<cluster_name>/`** — the GitOps entrypoint. Each cluster gets
  one directory here with a `kustomization.yaml` that is the literal
  `spec.source.path` of that cluster's `Application`. This repo has one
  example cluster, `prod-cluster-01`. Running:

  ```sh
  kustomize build clusters/prod-cluster-01
  ```

  must produce the final resources to apply to the cluster — no nested
  `Application`/`ApplicationSet` objects, no Helm charts.

- **`configuration/<category>/<component>/`** — the actual configuration,
  organized by logical category (e.g. `operators/`, and in the future
  `monitoring/`, `ingress/`, etc. as they're added). Each `<component>/` is a
  plain kustomize `Kustomization` holding base manifests for one thing being
  configured. Components here never derive from anything else — they're leaf
  bases. The one example today is `configuration/operators/gitops-operator/`,
  which configures the OpenShift GitOps Operator's own Argo CD instance
  (the `ArgoCD` custom resource and related RBAC).

- **`kustomize-config/<name>/`** — cross-cutting kustomize configuration.
  **Every directory under here must be a kustomize `Component`**
  (`apiVersion: kustomize.config.k8s.io/v1alpha1`, `kind: Component`), never
  a plain `Kustomization`, and must never carry its own `resources:` — only
  transformers, patches, labels, etc. applied on top of resources supplied by
  `configuration/`. This lets a cluster's `kustomization.yaml` compose
  whichever components it needs via `components:`. The example here,
  `common-labels`, adds a couple of common labels to every resource built for
  a cluster.

- **`build/`** — scripts used by CI (`.github/workflows/validate.yaml`):
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
kustomize build clusters/prod-cluster-01

# Run the same checks CI runs
./build/validate-end-of-file.sh
./build/validate-trailing-whitespace.sh
./build/validate-yaml-doc.sh
./build/validate-kubeconform.sh
```

## Adding a new cluster

1. Create `clusters/<cluster_name>/kustomization.yaml` listing the
   `configuration/` resources and `kustomize-config/` components it needs.
2. Copy `bootstrap/root-application.yaml`, rename it, and update
   `metadata.name` and `spec.source.path`.
3. Apply the new `Application` manifest once, manually, on that cluster.

## Adding a new configuration component

Create `configuration/<category>/<component>/` with its own
`kustomization.yaml` and manifests. Reuse an existing category (e.g.
`operators/`) or introduce a new one (e.g. `monitoring/`, `ingress/`) if it
doesn't fit an existing category. Reference the new component from whichever
`clusters/<cluster_name>/kustomization.yaml` should include it.

## Adding a new kustomize-config component

Create `kustomize-config/<name>/kustomization.yaml` with
`apiVersion: kustomize.config.k8s.io/v1alpha1` and `kind: Component`. Add
transformers/patches/labels as needed, but no `resources:`. Reference it from
whichever `clusters/<cluster_name>/kustomization.yaml` should apply it.

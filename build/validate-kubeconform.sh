#!/bin/bash
#
# Renders every clusters/<name> entrypoint with kustomize and validates the
# resulting manifests with kubeconform. Schemas are looked up first from
# kubeconform's built-in core-Kubernetes catalog, then from Datree's
# CRDs-catalog (https://github.com/datreeio/CRDs-catalog) for CRDs such as
# ArgoCD's Application. Types present in neither (e.g. OpenShift/operator
# CRs not published to CRDs-catalog, like the GitOps Operator's own ArgoCD
# CR) are skipped rather than failed -- see -ignore-missing-schemas below.
#
# `--enable-helm` is required because clusters/<name>/kustomization.yaml
# declares `helmCharts:` to inflate local Helm-chart components directly
# (e.g. configuration/operators/openshift-gitops) -- this shells out to a
# real `helm` binary. `--load-restrictor LoadRestrictionsNone` is required
# alongside it because those charts live outside the cluster kustomization's
# own directory tree.

set -euo pipefail

KUSTOMIZE_VERSION="5.8.1"
KUBECONFORM_VERSION="v0.8.0"
HELM_VERSION="3.22.0"

BIN_DIR="$(mktemp -d)"
trap 'rm -rf "${BIN_DIR}"' EXIT
export PATH="${BIN_DIR}:${PATH}"

if ! command -v kustomize >/dev/null 2>&1; then
  echo "Installing kustomize ${KUSTOMIZE_VERSION}..."
  curl -sL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" \
    | tar -xz -C "${BIN_DIR}"
fi

if ! command -v kubeconform >/dev/null 2>&1; then
  echo "Installing kubeconform ${KUBECONFORM_VERSION}..."
  curl -sL "https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz" \
    | tar -xz -C "${BIN_DIR}"
fi

if ! command -v helm >/dev/null 2>&1; then
  echo "Installing helm ${HELM_VERSION}..."
  curl -sL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
    | tar -xz -C "${BIN_DIR}" --strip-components=1 linux-amd64/helm
fi

eCode=0

for cluster_dir in clusters/*/; do
  cluster_name="$(basename "${cluster_dir}")"
  echo "== Validating ${cluster_name} =="

  if ! kustomize build --enable-helm --load-restrictor LoadRestrictionsNone "${cluster_dir}" | kubeconform \
      -summary \
      -strict \
      -schema-location default \
      -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
      -ignore-missing-schemas; then
    echo "Error: kubeconform validation failed for ${cluster_name}"
    eCode=1
  fi
done

exit $eCode

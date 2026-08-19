transform_oci_image_url() {
  local type="${1}"
  local image="${2}"
  local IMG

  if [[ "$type" == "hi" ]]; then
    echo "${HI_REGISTRY}/base/${image}"

  elif [[ "$type" == "qcr" ]]; then
    local TRIM_NAME
    TRIM_NAME="$(echo "${image}" | sed -E 's;/;_;g')"
    if [[ "$image" =~ "ghcr.io/fluxcd/" ]]; then
      TRIM_NAME="$(echo "${image#ghcr.io/fluxcd/}" | sed -E 's;/;_;g')"
      IMG="${QCR_REGISTRY}/osc-org/${TRIM_NAME}"
    elif [[ "$image" =~ "factory.talos.dev/nocloud-installer/" ]]; then
      TRIM_NAME="$(echo "${image#factory.talos.dev/nocloud-installer/}" | sed -E 's;/;_;g')"
      IMG="${QCR_REGISTRY}/nocloud-installer/${TRIM_NAME}"
    elif [[ "$image" =~ "factory.talos.dev/metal-installer/" ]]; then
      TRIM_NAME="$(echo "${image#factory.talos.dev/metal-installer/}" | sed -E 's;/;_;g')"
      IMG="${QCR_REGISTRY}/metal-installer/${TRIM_NAME}"
    else
      IMG="${QCR_REGISTRY}/osc-org/${TRIM_NAME}"
    fi
    echo "${IMG}"

  elif [[ "$type" == "flat" ]]; then
    local TRIM_NAME
    if [[ "$image" =~ "ghcr.io/fluxcd/" ]]; then
      TRIM_NAME="$(echo "${image#ghcr.io/fluxcd/}" | sed -E 's;/;_;g')"
      IMG="${FLAT_REGISTRY}/fluxcd-org/${TRIM_NAME}"
    else
      TRIM_NAME="$(echo "${image}" | sed -E 's;/;_;g')"
      IMG="${FLAT_REGISTRY}/osc-org/${TRIM_NAME}"
    fi
    echo "${IMG}"

  elif [[ "$type" == "local" ]]; then
    IMG="registry.allok.top/${image}"

    if [[ "$image" == docker.io/* ]]; then
      IMG="docker-io.allok.top/${image#docker.io/}"
    elif [[ "$image" == ghcr.io/* ]]; then
      IMG="ghcr-io.allok.top/${image#ghcr.io/}"
    elif [[ "$image" == gcr.io/* ]]; then
      IMG="gcr-io.allok.top/${image#gcr.io/}"
    elif [[ "$image" == quay.io/* ]]; then
      IMG="quay-io.allok.top/${image#quay.io/}"
    elif [[ "$image" == factory.talos.dev/* ]]; then
      IMG="factory-talos-dev.allok.top/${image#factory.talos.dev/}"
    elif [[ "$image" == registry.k8s.io/* ]]; then
      IMG="registry-k8s-io.allok.top/${image#registry.k8s.io/}"
    elif [[ "$image" =~ ^acr.io ]]; then
      IMG="${FLAT_REGISTRY}/osc-org/${image#acr.io/}"
    elif [[ "$image" =~ ^qcr.io ]]; then
      IMG="${QCR_REGISTRY}/osc-org/${image#qcr.io/}"
    fi
    echo "${IMG}"
  fi
}

sync_flat_filtered() {
  local SRC="$1"
  local DEST="$2"
  local CREDS="$3"
  local TMPDIR
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' EXIT

  local OCI_DIR="${TMPDIR}/layout"

  local RAW
  RAW=$(skopeo inspect --raw "docker://$SRC" 2>/dev/null) || {
    echo "ERROR: Failed to inspect source: $SRC"
    return 1
  }

  local MEDIA_TYPE
  MEDIA_TYPE=$(echo "$RAW" | jq -r '.mediaType // empty')

  if [[ "$MEDIA_TYPE" != "application/vnd.docker.distribution.manifest.list.v2+json" && \
       "$MEDIA_TYPE" != "application/vnd.oci.image.index.v1+json" ]]; then
    echo "Not a manifest list, using normal copy"
    skopeo copy --all --src-tls-verify=true --dest-tls-verify=true \
      --dest-creds "$CREDS" "docker://$SRC" "docker://$DEST"
    return $?
  fi

  local STATS
  STATS=$(echo "$RAW" | jq '{
    total: .manifests | length,
    good: [.manifests[] | select(.platform.os != "unknown" and .platform.architecture != "unknown")] | length
  }')
  local TOTAL=$(echo "$STATS" | jq -r '.total')
  local GOOD=$(echo "$STATS" | jq -r '.good')
  local REMOVED=$((TOTAL - GOOD))

  if [[ "$REMOVED" -eq 0 ]]; then
    echo "No attestation manifests found, using normal copy"
    skopeo copy --all --src-tls-verify=true --dest-tls-verify=true \
      --dest-creds "$CREDS" "docker://$SRC" "docker://$DEST"
    return $?
  fi

  echo "Will remove $REMOVED attestation manifests ($TOTAL -> $GOOD)"

  echo "Step 1: Copying to local OCI layout..."
  skopeo copy --all --src-tls-verify=true "docker://$SRC" "oci:${OCI_DIR}:sync" || {
    echo "ERROR: Failed to copy to OCI layout"
    return 1
  }

  echo "Step 2: Filtering manifest list..."
  local INDEX_FILE="${OCI_DIR}/index.json"
  local MF_DIGEST MF_ALGO MF_HEX MF_FILE
  MF_DIGEST=$(jq -r '.manifests[0].digest' "$INDEX_FILE")
  MF_ALGO="${MF_DIGEST%%:*}"
  MF_HEX="${MF_DIGEST#*:}"
  MF_FILE="${OCI_DIR}/blobs/${MF_ALGO}/${MF_HEX}"

  if [[ ! -f "$MF_FILE" ]]; then
    echo "ERROR: Manifest list blob not found: $MF_FILE"
    return 1
  fi

  local BEFORE AFTER
  BEFORE=$(jq '.manifests | length' "$MF_FILE")
  jq 'del(.manifests[] | select(.platform.os == "unknown" and .platform.architecture == "unknown"))' \
    "$MF_FILE" > "${MF_FILE}.tmp" && mv "${MF_FILE}.tmp" "$MF_FILE"
  AFTER=$(jq '.manifests | length' "$MF_FILE")

  echo "  Filtered: $BEFORE -> $AFTER manifests"

  if [[ "$AFTER" -eq 0 ]]; then
    echo "ERROR: All manifests filtered out"
    return 1
  fi

  echo "Step 3: Pushing filtered image..."
  skopeo copy --all --dest-tls-verify=true --dest-creds "$CREDS" \
    "oci:${OCI_DIR}:sync" "docker://$DEST" || {
    echo "ERROR: Failed to push to destination"
    return 1
  }

  echo "Sync completed"
}

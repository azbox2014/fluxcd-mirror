transform_oci_image_url() {
  type=${1}
  image=${2}
  if [ "$type" = "hi" ]; then
    echo "${HI_REGISTRY}/base/${image}"

  elif [ "$type" = "qcr" ]; then

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
    echo ${IMG}

  elif [ "$type" = "flat" ]; then
    if [[ "$image" =~ "ghcr.io/fluxcd/" ]]; then
      TRIM_NAME="$(echo "${image#ghcr.io/fluxcd/}" | sed -E 's;/;_;g')"
  		IMG="${FLAT_REGISTRY}/fluxcd-org/${TRIM_NAME}"
	  else
      TRIM_NAME="$(echo "${image}" | sed -E 's;/;_;g')"
	    IMG="${FLAT_REGISTRY}/osc-org/${TRIM_NAME}"
    fi
    echo ${IMG}

  elif [ "$type" = "local" ]; then
    IMG="registry.allok.top/$image"

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
  	elif [[ ${image} =~ ^acr.io ]]; then
      IMG="${FLAT_REGISTRY}/osc-org/${image#acr.io/}"
	  elif [[ ${image} =~ ^qcr.io ]]; then
      IMG="${QCR_REGISTRY}/osc-org/${image#qcr.io/}"
    fi
    echo $IMG
  fi
}

sync_flat_filtered() {
  local SRC="$1"
  local DEST="$2"
  local CREDS="$3"
  local TMPDIR=$(mktemp -d)
  local OCI_DIR="${TMPDIR}/image"

  local RAW_MANIFEST=$(skopeo inspect --raw "docker://$SRC" 2>/dev/null)
  local MEDIA_TYPE=$(echo "$RAW_MANIFEST" | jq -r '.mediaType // empty')

  if [[ "$MEDIA_TYPE" != "application/vnd.docker.distribution.manifest.list.v2+json" && \
       "$MEDIA_TYPE" != "application/vnd.oci.image.index.v1+json" ]]; then
    local CONFIG_TYPE=$(echo "$RAW_MANIFEST" | jq -r '.config.mediaType // empty')
    if [[ "$CONFIG_TYPE" == "application/vnd.oci.empty.v1+json" ]]; then
      echo "ERROR: Source image has empty config, cannot sync to ACR"
      rm -rf "$TMPDIR"
      return 1
    fi
    rm -rf "$TMPDIR"
    skopeo copy --all --src-tls-verify=true --dest-tls-verify=true \
      --dest-creds "$CREDS" "docker://$SRC" "docker://$DEST"
    return $?
  fi

  local TOTAL=$(echo "$RAW_MANIFEST" | jq '.manifests | length')
  echo "Manifest list with $TOTAL entries, copying to OCI layout..."

  skopeo copy --all --src-tls-verify=true "docker://$SRC" "oci:${OCI_DIR}:filter" || {
    rm -rf "$TMPDIR"
    return 1
  }

  local INDEX_FILE="${OCI_DIR}/index.json"
  local NEW_MANIFESTS="[]"
  local FILTERED=0
  local REMOVED=0

  for i in $(seq 0 $((TOTAL-1))); do
    local DIGEST=$(jq -r ".manifests[$i].digest" "$INDEX_FILE")
    local PLATFORM=$(jq -r ".manifests[$i].platform | \"\(.os)/\(.architecture)\"" "$INDEX_FILE" 2>/dev/null)
    local MF_FILE="${OCI_DIR}/blobs/${DIGEST}"

    if [[ -f "$MF_FILE" ]]; then
      local CFG=$(jq -r '.config.mediaType // empty' "$MF_FILE")
      if [[ "$CFG" == "application/vnd.oci.empty.v1+json" ]]; then
        echo "  [$i] $DIGEST ($PLATFORM) - SKIP (empty config)"
        REMOVED=$((REMOVED + 1))
        continue
      fi
    fi

    echo "  [$i] $DIGEST ($PLATFORM) - KEEP"
    NEW_MANIFESTS=$(echo "$NEW_MANIFESTS" | jq \
      --argjson entry "$(jq -c ".manifests[$i]" "$INDEX_FILE")" '. + [$entry]')
    FILTERED=$((FILTERED + 1))
  done

  if [[ "$FILTERED" -eq "$TOTAL" ]]; then
    echo "All manifests valid, using normal copy"
    rm -rf "$TMPDIR"
    skopeo copy --all --src-tls-verify=true --dest-tls-verify=true \
      --dest-creds "$CREDS" "docker://$SRC" "docker://$DEST"
    return $?
  fi

  if [[ "$FILTERED" -eq 0 ]]; then
    echo "ERROR: All manifests were filtered out, nothing to sync"
    rm -rf "$TMPDIR"
    return 1
  fi

  echo "Kept $FILTERED, removed $REMOVED"
  jq --argjson manifests "$NEW_MANIFESTS" '.manifests = $manifests' "$INDEX_FILE" > "${INDEX_FILE}.tmp"
  mv "${INDEX_FILE}.tmp" "$INDEX_FILE"

  echo "Pushing filtered image to destination..."
  skopeo copy --all --dest-tls-verify=true --dest-creds "$CREDS" \
    "oci:${OCI_DIR}:filter" "docker://$DEST" || {
    rm -rf "$TMPDIR"
    return 1
  }

  rm -rf "$TMPDIR"
  echo "Sync completed"
}

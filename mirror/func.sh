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

  local RAW=$(skopeo inspect --raw "docker://$SRC" 2>/dev/null)
  local MEDIA_TYPE=$(echo "$RAW" | jq -r '.mediaType // empty')

  if [[ "$MEDIA_TYPE" != "application/vnd.docker.distribution.manifest.list.v2+json" && \
       "$MEDIA_TYPE" != "application/vnd.oci.image.index.v1+json" ]]; then
    echo "Not a manifest list, using normal copy"
    skopeo copy --all --src-tls-verify=true --dest-tls-verify=true \
      --dest-creds "$CREDS" "docker://$SRC" "docker://$DEST"
    return $?
  fi

  local TOTAL=$(echo "$RAW" | jq '.manifests | length')
  local PLATFORMS=$(echo "$RAW" | jq -r '
    .manifests[]
    | select(.platform.os != "unknown" and .platform.architecture != "unknown")
    | "\(.platform.os)/\(.platform.architecture)\(if .platform.variant then "/\(.platform.variant)" else "" end)"
  ' | tr '\n' ',' | sed 's/,$//')

  local KEEP_COUNT=$(echo "$PLATFORMS" | tr ',' '\n' | wc -l)
  local REMOVED_COUNT=$((TOTAL - KEEP_COUNT))

  if [[ "$REMOVED_COUNT" -eq 0 ]]; then
    echo "No attestation manifests found, using normal copy"
    skopeo copy --all --src-tls-verify=true --dest-tls-verify=true \
      --dest-creds "$CREDS" "docker://$SRC" "docker://$DEST"
    return $?
  fi

  echo "Removed $REMOVED_COUNT attestation manifests, keeping: $PLATFORMS"

  local REGISTRY="${DEST%%/*}"
  local USERNAME="${CREDS%%:*}"
  local PASSWORD="${CREDS#*:}"
  echo "$PASSWORD" | docker login -u "$USERNAME" --password-stdin "$REGISTRY"

  docker buildx imagetools create \
    --tag "$DEST" \
    --platform "$PLATFORMS" \
    "$SRC"
}

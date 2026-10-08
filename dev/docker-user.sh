#!/usr/bin/env bash
# Container UID 0 in a rootless daemon maps to its unprivileged host owner.
# A rootful daemon uses the host UID/GID for writable repository bind mounts.
docker_container_identity() {
  local security
  security="$(docker info --format '{{json .SecurityOptions}}')" || return
  case "$security" in
    *'"name=rootless"'*) printf '0:0\n' ;;
    *) printf '%s:%s\n' "$(id -u)" "$(id -g)" ;;
  esac
}

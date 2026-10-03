#!/bin/bash
# Db2 11.5.9 lab menu for AlmaLinux 9 on WSL2.
# Passwords are never stored here. The Db2 tar must already be on disk.
set -euo pipefail

INSTALL_ROOT=/opt/ibm/db2/V11.5
LAB=/ars/home/bin/db2-lab/v11.5.9
MEDIA_NAME=v11.5.9_linuxx64_server_dec.tar.gz
SHA256=cb106df7840362fb9a344520ca9fb5d62357e49d357b077101b1f7f44f51062a

heading() {
  cat << 'BANNER'

  * Automated

   GROK BOT
   DB2
   INSTALLATION

  Db2 11.5.9 on WSL2 and AlmaLinux 9
BANNER
}

need_root() {
  if [[ ${EUID} -ne 0 ]]; then
    echo "Run this menu with sudo."
    exit 1
  fi
}

pause() { read -r -p "Press Enter to return to the menu..."; }

check_only() {
  echo "== distro =="
  cat /etc/os-release | sed -n '1,5p'
  echo "== packages =="
  rpm -q libaio numactl-libs ksh binutils || true
  if [[ -x ${LAB}/server_dec/db2prereqcheck ]]; then
    (cd "${LAB}/server_dec" && ./db2prereqcheck -i -v 11.5.9.0) || true
  else
    echo "Installer not unpacked yet at ${LAB}/server_dec"
  fi
}

stage_media() {
  local src="${1:-}"
  if [[ -z "${src}" ]]; then
    read -r -p "Full path to ${MEDIA_NAME}: " src
  fi
  if [[ ! -f "${src}" ]]; then
    echo "File not found: ${src}"
    return 1
  fi
  echo "${SHA256}  ${src}" | sha256sum -c -
  mkdir -p "${LAB}"
  # keep /ars and /ars/home root-owned; lab dirs belong to the sudo user
  local owner="${SUDO_USER:-root}"
  chown "${owner}:${owner}" /ars/home/bin /ars/home/bin/db2-lab "${LAB}" 2>/dev/null || true
  cp -n "${src}" "${LAB}/" || cp "${src}" "${LAB}/"
  tar -xzf "${LAB}/${MEDIA_NAME}" -C "${LAB}"
  echo "Unpacked at ${LAB}/server_dec"
}

install_product() {
  dnf install -y --setopt=install_weak_deps=False libaio numactl-libs ksh binutils
  if [[ ! -x ${LAB}/server_dec/db2_install ]]; then
    stage_media
  fi
  (cd "${LAB}/server_dec" && ./db2prereqcheck -i -v 11.5.9.0) || true
  "${LAB}/server_dec/db2_install" \
    -b "${INSTALL_ROOT}" -p SERVER -n -y \
    -f NOTSAMP -f NOPCMK \
    -l "${LAB}/db2_install.log"
  "${INSTALL_ROOT}/bin/db2ls" || true
  if ! getent group db2iadm1 >/dev/null; then groupadd -g 1001 db2iadm1; fi
  if ! getent group db2fsdm1 >/dev/null; then groupadd -g 1002 db2fsdm1; fi
  if ! id db2inst1 >/dev/null 2>&1; then
    useradd -u 1001 -g db2iadm1 -m -d /home/db2inst1 db2inst1
  fi
  if ! id db2fenc1 >/dev/null 2>&1; then
    useradd -u 1002 -g db2fsdm1 -m -d /home/db2fenc1 db2fenc1
  fi
  echo "Set the two passwords now. They are not saved by this script."
  passwd db2inst1
  passwd db2fenc1
  "${INSTALL_ROOT}/instance/db2icrt" -u db2fenc1 db2inst1
  link_libs
}

link_libs() {
  local lib dir="${INSTALL_ROOT}/lib64"
  for lib in libaws-cpp-sdk-transfer.so libaws-cpp-sdk-s3.so \
             libaws-cpp-sdk-core.so libaws-cpp-sdk-kinesis.so; do
    ln -sfn "awssdk/RHEL/9.2/${lib}" "${dir}/${lib}"
  done
  echo "AWS SDK links are in ${dir}"
}

start_instance() {
  su - db2inst1 -c "db2start; db2 get instance"
}

smoke_test() {
  su - db2inst1 -c 'db2 "CREATE DATABASE LABDB" && db2 list database directory && db2 connect to LABDB && db2 "CREATE TABLE lab_smoke (id INT, note VARCHAR(40))" && db2 "INSERT INTO lab_smoke VALUES (1, '\''hello lab'\'')" && db2 "SELECT * FROM lab_smoke" && db2 connect reset'
}

need_root
while true; do
  heading
  cat << 'MENU'

  1  Check only
  2  Install
  3  Start
  4  Smoke test
  5  Quit

MENU
  read -r -p "Choice: " choice
  case "${choice}" in
    1) check_only || true ;;
    2) install_product ;;
    3) start_instance ;;
    4) smoke_test ;;
    5) exit 0 ;;
    *) echo "Pick 1 to 5." ;;
  esac
  pause || true
done

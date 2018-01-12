#!/bin/bash
# Generate an environment yaml from a template
set -euo pipefail
IFS=$'\n\t'

TEMP_FILE="${1:--}"
HOSTS_FILE="${2:-}"
HOST_NAMES_FILE="${3:-}"
PUBLIC_IP_RANGES_FILE="${4:-}"
PRIVATE_IP_RANGES_FILE="${5:-}"

declare -A TEMPLATE_VAR_MAP=(
  ["ETP_DNS_SERVER"]="${ETP_DNS_SERVER:-ETP_DNS_SERVER}"
  ["ETP_EUCA2OOLS_YUM_REPO"]="${ETP_EUCA2OOLS_YUM_REPO:-http://downloads.eucalyptus.com/software/euca2ools/3.4/rhel/7/x86_64/}"
  ["ETP_EUCALYPTUS_BRANCH"]="${ETP_EUCALYPTUS_BRANCH:-devel-4.4}"
  ["ETP_EUCALYPTUS_CLOUD_LIBS_BRANCH"]="${ETP_EUCALYPTUS_CLOUD_LIBS_BRANCH:-devel-4.4}"
  ["ETP_EUCALYPTUS_CLOUD_LIBS_GIT_REPO"]="${ETP_EUCALYPTUS_CLOUD_LIBS_GIT_REPO:-https://github.com/sjones4/eucalyptus-cloud-libs.git}"
  ["ETP_EUCALYPTUS_CLOUD_OPTS"]="${ETP_EUCALYPTUS_CLOUD_OPTS:-}"
  ["ETP_EUCALYPTUS_DNS_DOMAIN"]="${ETP_EUCALYPTUS_DNS_DOMAIN:-ETP_HOST0_IP.nip.io}"
  ["ETP_EUCALYPTUS_GIT_REPO"]="${ETP_EUCALYPTUS_GIT_REPO:-https://github.com/sjones4/eucalyptus.git}"
  ["ETP_EUCALYPTUS_YUM_REPO"]="${ETP_EUCALYPTUS_YUM_REPO:-http://downloads.eucalyptus.com/software/eucalyptus/4.4/rhel/7/x86_64/}"
  ["ETP_GATEWAY"]="${ETP_GATEWAY:-ETP_GATEWAY}"
  ["ETP_INSTALL_TYPE"]="${ETP_INSTALL_TYPE:-packages}"
  ["ETP_NETMASK"]="${ETP_NETMASK:-255.255.255.0}"
  ["ETP_NTP_SERVER"]="${ETP_NTP_SERVER:-ETP_NTP_SERVER}"
  ["ETP_PRIVATE_IP_RANGE"]="${ETP_PRIVATE_IP_RANGE:-ETP_PRIVATE_IP_RANGE}"
  ["ETP_PUBLIC_IP_RANGE"]="${ETP_PUBLIC_IP_RANGE:-ETP_PUBLIC_IP_RANGE}"
  ["ETP_SUBNET"]="${ETP_SUBNET:-ETP_SUBNET}"
)

# checks
if [ "${TEMP_FILE}" != "-" ] && [ ! -f "${TEMP_FILE}" ] ; then
  echo "Template not found: ${TEMP_FILE}" >&2
  exit 1
fi

for OPTIONAL_FILE_PARAM in HOSTS_FILE HOST_NAMES_FILE PUBLIC_IP_RANGES_FILE PRIVATE_IP_RANGES_FILE; do
  if [ ! -z "${!OPTIONAL_FILE_PARAM}" ] && [ ! -f "${!OPTIONAL_FILE_PARAM}" ] ; then
    echo "File not found: ${!OPTIONAL_FILE_PARAM}" >&2
    exit 1
  fi
done

# working template
TEMPLATE_TEMP=$(mktemp -t environment.yaml.XXXXXXXX)
function cleanup {
  [ ! -f "${TEMPLATE_TEMP}" ] || rm -f "${TEMPLATE_TEMP}"
}
trap cleanup EXIT
cat "${TEMP_FILE}" > "${TEMPLATE_TEMP}"

# add dynamic template variables
if [ ! -z "${HOSTS_FILE}" ] ; then
  HOST_NUM=0
  for HOST in $(<"${HOSTS_FILE}"); do
    TEMPLATE_VAR_MAP["ETP_HOST${HOST_NUM}_IP"]="${HOST}"
    HOST_NUM=$((HOST_NUM + 1))
  done
fi
if [ ! -z "${HOST_NAMES_FILE}" ] ; then
  HOST_NUM=0
  for HOST in $(<"${HOST_NAMES_FILE}"); do
    TEMPLATE_VAR_MAP["ETP_HOST${HOST_NUM}_NAME"]="${HOST}"
    HOST_NUM=$((HOST_NUM + 1))
  done
fi
if [ -z "${ETP_PUBLIC_IP_RANGE}" ] && [ ! -z "${PUBLIC_IP_RANGES_FILE}" ] ; then
  IP_RANGES=""
  for IP_RANGE in $(<"${PUBLIC_IP_RANGES_FILE}"); do
    if [ ! -z "${IP_RANGES}" ] ; then IP_RANGES="${IP_RANGES}, " ; fi
    IP_RANGES="${IP_RANGES}'${IP_RANGE}'"
  done
  TEMPLATE_VAR_MAP["ETP_PUBLIC_IP_RANGE"]="${IP_RANGES}"
fi
if [ -z "${ETP_PRIVATE_IP_RANGE}" ] && [ ! -z "${PRIVATE_IP_RANGES_FILE}" ] ; then
  IP_RANGES=""
  for IP_RANGE in $(<"${PRIVATE_IP_RANGES_FILE}"); do
    if [ ! -z "${IP_RANGES}" ] ; then IP_RANGES="${IP_RANGES}, " ; fi
    IP_RANGES="${IP_RANGES}'${IP_RANGE}'"
  done
  TEMPLATE_VAR_MAP["ETP_PRIVATE_IP_RANGE"]="${IP_RANGES}"
fi

#process
PROCESS_TEMPLATE=1
PROCESS_COUNT=0
while [ ${PROCESS_TEMPLATE} -gt 0 ] && [ ${PROCESS_COUNT} -lt 10 ]; do
  for TEMPLATE_VAR in "${!TEMPLATE_VAR_MAP[@]}"; do
    sed --in-place "s/${TEMPLATE_VAR}/${TEMPLATE_VAR_MAP[$TEMPLATE_VAR]//\//\\/}/g" "${TEMPLATE_TEMP}"
  done
  PROCESS_TEMPLATE=$(grep -c ETP_ "${TEMPLATE_TEMP}" || true)
  PROCESS_COUNT=$((PROCESS_COUNT + 1))
done

cat "${TEMPLATE_TEMP}"
exit ${PROCESS_TEMPLATE}

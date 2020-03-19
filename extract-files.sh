#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2019 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

EXTHM_ROOT="${MY_DIR}"/../../..

HELPER="${EXTHM_ROOT}/vendor/exthm/build/tools/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

ONLY_COMMON=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -o | --only-common )
                ONLY_COMMON=false
                ;;
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
	case "${1}" in

	# Correct android.hidl.manager@1.0-java jar name
	vendor/etc/permissions/qti_libpermissions.xml)
		sed -i -e 's|name=\"android.hidl.manager-V1.0-java|name=\"android.hidl.manager@1.0-java|g' "${2}"
		;;

	# kang vulkan from LA.UM.8.6.r1-01900-89xx.0
	vendor/lib/hw/vulkan.msm8996.so | vendor/lib64/hw/vulkan.msm8996.so)
		sed -i -e 's|vulkan.msm8953.so|vulkan.msm8996.so|g' "${2}"
		;;

	# make imsrcsd and lib-uceservice load haxxed libbase
	vendor/lib64/lib-uceservice.so | vendor/bin/imsrcsd)
		patchelf --replace-needed "libbase.so" "libbase-hax.so" "${2}"
		;;

	# use /sbin instead of /system/bin for TWRP
	recovery/root/sbin/qseecomd)
		sed -i -e 's|/system/bin/linker64|/sbin/linker64\x0\x0\x0\x0\x0\x0|g' "${2}"
		;;

	esac
}

# Initialize the helper for common device
setup_vendor "${DEVICE_COMMON}" "${VENDOR}" "${EXTHM_ROOT}" true "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" \
        "${KANG}" --section "${SECTION}"

if [ -s "${MY_DIR}/proprietary-files-twrp.txt" ]; then
	extract "${MY_DIR}/proprietary-files-twrp.txt" "${SRC}" \
		"${KANG}" --section "${SECTION}"
fi

if [ -z "${ONLY_COMMON}" ] && [ -s "${MY_DIR}/../${DEVICE}/proprietary-files.txt" ]; then
    # Reinitialize the helper for device
    source "${MY_DIR}/../${DEVICE}/extract-files.sh"
    setup_vendor "${DEVICE}" "${VENDOR}" "${EXTHM_ROOT}" false "${CLEAN_VENDOR}"

    extract "${MY_DIR}/../${DEVICE}/proprietary-files.txt" "${SRC}" \
            "${KANG}" --section "${SECTION}"
fi

"${MY_DIR}/setup-makefiles.sh"

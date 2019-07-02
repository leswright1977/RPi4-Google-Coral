#!/bin/bash
#
# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CLEAR="\033[0m"

CPU_ARCH=$(uname -m)
OS_VERSION=$(uname -v)

function info {
  echo -e "${GREEN}${1}${CLEAR}"
}

function warn {
  echo -e "${YELLOW}${1}${CLEAR}"
}

function error {
  echo -e "${RED}${1}${CLEAR}"
}

if [[ -f /etc/mendel_version ]]; then
  warn "Looks like you're using a Coral Dev Board. You should instead use Debian packages to manage Edge TPU software."
  exit 0
fi

if [[ "${CPU_ARCH}" == "x86_64" ]] && [[ "${OS_VERSION}" == *"Debian"* || "${OS_VERSION}" == *"Ubuntu"* ]]; then
  info "Recognized as Linux on x86_64."
  LIBEDGETPU_SUFFIX=x86_64
  HOST_GNU_TYPE=x86_64-linux-gnu
elif [[ "${CPU_ARCH}" == "armv7l" ]]; then
  MODEL=$(cat /proc/device-tree/model)
  if [[ "${MODEL}" == "Raspberry Pi 3 Model B Rev"* ]]; then
    info "Recognized as Raspberry Pi 3 B."
    LIBEDGETPU_SUFFIX=arm32
    HOST_GNU_TYPE=arm-linux-gnueabihf
  elif [[ "${MODEL}" == "Raspberry Pi 3 Model B Plus Rev"* ]]; then
    info "Recognized as Raspberry Pi 3 B+."
    LIBEDGETPU_SUFFIX=arm32
    HOST_GNU_TYPE=arm-linux-gnueabihf
  elif [[ "${MODEL}" == "Raspberry Pi 4 Model B Rev"* ]]; then #edit for rpi4
    info "Recognized as Raspberry Pi 4."
    LIBEDGETPU_SUFFIX=arm32
    HOST_GNU_TYPE=arm-linux-gnueabihf
  fi
elif [[ "${CPU_ARCH}" == "aarch64" ]]; then
  info "Recognized as generic ARM64 platform."
  LIBEDGETPU_SUFFIX=arm64
  HOST_GNU_TYPE=aarch64-linux-gnu
fi

if [[ -z "${HOST_GNU_TYPE}" ]]; then
  error "Your platform is not supported."
  exit 1
fi

cat << EOM
Warning: During normal operation, the Edge TPU Accelerator may heat up, depending
on the computation workloads and operating frequency. Touching the metal part of the
device after it has been operating for an extended period of time may lead to discomfort
and/or skin burns. As such, when running at the default operating frequency, the device is
intended to safely operate at an ambient temperature of 35C or less. Or when running at
the maximum operating frequency, it should be operated at an ambient temperature of
25C or less.

Google does not accept any responsibility for any loss or damage if the device is operated
outside of the recommended ambient temperature range.
.............................................................
Would you like to enable the maximum operating frequency? Y/N
EOM

read USE_MAX_FREQ
case "${USE_MAX_FREQ}" in
  [yY])
    info "Using maximum operating frequency."
    LIBEDGETPU_SRC="${SCRIPT_DIR}/libedgetpu/libedgetpu_${LIBEDGETPU_SUFFIX}.so"
    ;;
  *)
    info "Using default operating frequency."
    LIBEDGETPU_SRC="${SCRIPT_DIR}/libedgetpu/libedgetpu_${LIBEDGETPU_SUFFIX}_throttled.so"
    ;;
esac

LIBEDGETPU_DST="/usr/lib/${HOST_GNU_TYPE}/libedgetpu.so.1.0"

# Install dependent libraries.
info "Installing library dependencies..."
sudo apt-get install -y \
  libusb-1.0-0 \
  python3-pip \
  python3-pil \
  python3-numpy \
  libc++1 \
  libc++abi1 \
  libunwind8 \
  libgcc1
info "Done."

# Device rule file.
UDEV_RULE_PATH="/etc/udev/rules.d/99-edgetpu-accelerator.rules"
info "Installing device rule file [${UDEV_RULE_PATH}]..."

if [[ -f "${UDEV_RULE_PATH}" ]]; then
  warn "File already exists. Replacing it..."
  sudo rm -f "${UDEV_RULE_PATH}"
fi


sudo cp -p "${SCRIPT_DIR}/99-edgetpu-accelerator.rules" "${UDEV_RULE_PATH}"
sudo udevadm control --reload-rules && sudo udevadm trigger  #needed to put sudo in second half of command...
info "Done."

# Runtime library.
info "Installing Edge TPU runtime library [${LIBEDGETPU_DST}]..."
if [[ -f "${LIBEDGETPU_DST}" ]]; then
  warn "File already exists. Replacing it..."
  sudo rm -f "${LIBEDGETPU_DST}"
fi

sudo cp -p "${LIBEDGETPU_SRC}" "${LIBEDGETPU_DST}"
sudo ldconfig
info "Done."

# Python API.
WHEEL=$(ls ${SCRIPT_DIR}/edgetpu-*-py3-none-any.whl 2>/dev/null)
if [[ $? == 0 ]]; then
  info "Installing Edge TPU Python API..."
  sudo python3 -m pip install --no-deps "${WHEEL}"
  info "Done."
fi

if [[ "${MODEL}" == "Raspberry Pi 4 Model B Rev"* ]]; then #edit for rpi4
    info "Lib Fu."
    sudo cp /usr/local/lib/python3.7/dist-packages/edgetpu/swig/_edgetpu_cpp_wrapper.cpython-35m-arm-linux-gnueabihf.so /usr/local/lib/python3.7/dist-packages/edgetpu/swig/_edgetpu_cpp_wrapper.cpython-37m-arm-linux-gnueabihf.so
fi

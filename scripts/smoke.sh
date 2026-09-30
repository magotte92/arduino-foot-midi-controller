#!/usr/bin/env bash
# Compile the Mega sketch with the pinned profile and check the firmware image.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="${root}/build"
sketch="${root}/Mega_Pedal"
log="${out}/compile.log"

mkdir -p "${out}"

arduino-cli compile \
  --profile mega2560 \
  --warnings all \
  --clean \
  --output-dir "${out}" \
  "${sketch}" | tee "${log}"

if grep -E 'Mega_Pedal\.ino.*warning:' "${log}"; then
  echo "smoke failed: the sketch compiled with warnings" >&2
  exit 1
fi

hex="$(find "${out}" -maxdepth 1 -name '*.hex' ! -name '*.with_bootloader.hex' -print)"
elf="$(find "${out}" -maxdepth 1 -name '*.elf' -print)"

if [[ -z "${hex}" || -z "${elf}" ]]; then
  echo "smoke failed: compile did not produce a hex and elf" >&2
  exit 1
fi

hex_bytes="$(wc -c < "${hex}" | tr -d ' ')"
if [[ "${hex_bytes}" -lt 1000 ]]; then
  echo "smoke failed: ${hex} is unexpectedly small (${hex_bytes} bytes)" >&2
  exit 1
fi

gcc_nm="$(find "${HOME}/.arduino15" -type f -name avr-nm -print -quit)"
if [[ -z "${gcc_nm}" ]]; then
  echo "smoke failed: avr-nm not found under ~/.arduino15" >&2
  exit 1
fi
objdump="${gcc_nm%/avr-nm}/avr-objdump"

symbols="$("${gcc_nm}" -C "${elf}")"
if ! grep -q '[[:space:]]MIDI$' <<< "${symbols}"; then
  echo "smoke failed: firmware is missing the MIDI instance" >&2
  exit 1
fi
if ! grep -q 'Bounce::' <<< "${symbols}"; then
  echo "smoke failed: firmware is not linked against Bounce2" >&2
  exit 1
fi

disassembly="$("${objdump}" -d -C "${elf}")"
# Channel 1 control change is status 0xB0, value 127 (0x7F). Both are inlined
# into the sketch, so they show up as immediates rather than a separate symbol.
if ! grep -q '0xB0' <<< "${disassembly}"; then
  echo "smoke failed: firmware does not contain a channel-1 control-change status" >&2
  exit 1
fi
if ! grep -q '0x7F' <<< "${disassembly}"; then
  echo "smoke failed: firmware does not contain the control-change value 127" >&2
  exit 1
fi

grep -E 'Sketch uses|Global variables' "${log}"
echo "smoke ok: ${hex} (${hex_bytes} bytes), MIDI control change and Bounce2 linked"

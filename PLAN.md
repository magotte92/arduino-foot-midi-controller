# Plan: make the Mega foot controller a reliable MIDI pedal

Research date: 30 September 2026. This file is a plan only. It does not change firmware, libraries, or CI.

## 1. Idea

This repository is a **foot-operated MIDI control-change pedal** for the **Arduino Mega 2560**.

What the code actually does today:

- Ten footswitches, each with a matching LED.
- Switches use the internal pull-ups. A press is a falling edge after a 25 ms debounce.
- Each press toggles that switch's LED.
- Each press also sends one MIDI Control Change on **channel 1**, controller numbers **80 through 89**, value **127**.
- MIDI leaves on the Mega's hardware UART (pins 0 and 1) at the MIDI Library's default **31250 baud**.

The on-board ATmega16U2 is the USB front end. Two different firmwares are checked in, and they do not do the same job:

- `hex/Arduino-usbserial-atmega16u2-Mega2560-Rev3.hex` is Arduino's stock USB-serial bridge. A computer sees a serial port. A DAW does not see a MIDI port unless a separate serial-to-MIDI program is running on the host.
- `hex/arduino_midi.hex` is a class-compliant USB MIDI device. Its USB string descriptors are `arduino_midi` and `hiduino project`, which identifies it as [HIDUINO](https://github.com/ddiakopoulos/hiduino) firmware. With that image on the 16U2, the UART bytes become USB MIDI and a DAW can open the pedal directly.

`hex/Arduino-usbserial-uno.hex` is the stock Uno bridge (USB strings include `Arduino Uno`). The Mega sketch does not use it.

**Uncertainty.** There is no schematic, wiring photo, or note of which DAW mapping the author used. Two readings of the sketch both fit the source:

1. The LED is a local latch, and the MIDI message was meant to follow it (127 when the LED turns on, 0 when it turns off). The current code does not do that: the LED toggles, the CC value stays 127.
2. The pedal is a trigger (always CC 127) and the LED is only a local "I have pressed this" lamp.

This plan treats (1) as the product, because the LED already stores latch state and a foot controller whose lamp and the DAW disagree is the failure people hit on stage. That is a behavior change for anyone who mapped the pedal as a one-shot trigger. Phase 1 calls that out in the README before the code changes.

The GitHub repo is a foot controller. It is not a sequencer, a synth, or a wireless pedal.

## 2. Current stack

| Piece | What is pinned | Role |
| --- | --- | --- |
| Language | C++ Arduino sketch, one file | `Mega_Pedal/Mega_Pedal.ino` |
| Board | `arduino:avr:mega` | Arduino Mega 2560 (ATmega2560) |
| Core | Arduino AVR Boards **1.8.8** | `Mega_Pedal/sketch.yaml` profile `mega2560` |
| Debounce | Bounce2 **2.71.0** | `fell()` on `INPUT_PULLUP`, 25 ms |
| MIDI | FortySevenEffects MIDI Library **5.0.2** | `MIDI_CREATE_DEFAULT_INSTANCE()`, `sendControlChange` |
| Build | Arduino CLI **1.5.1** | `.github/workflows/build.yml` |
| Check | `scripts/smoke.sh` | Compile, reject sketch warnings, require a `.hex` and `.elf`, require `MIDI` and `Bounce::` symbols, require immediates `0xB0` (channel 1 CC) and `0x7F` (value 127) |
| Updates | Dependabot, GitHub Actions only | `.github/dependabot.yml` |
| License | MIT, copyright 2019 humble-goat | `LICENSE` |

How it runs:

```sh
./scripts/smoke.sh
```

Arduino IDE 2 reads the same `sketch.yaml` profile. The first compile downloads the pinned core and libraries. CI does not flash a board. Nothing in CI talks MIDI.

Sketch facts a later change has to preserve or deliberately replace:

- Switch pins 22–31, LED pins 13 then 33–41, CC numbers 80–89. Pin 13 is the Mega's onboard LED and the SPI clock pin. The other LEDs are ordinary GPIO.
- Pins 0 and 1 are the MIDI UART. `Serial.print` debugging and MIDI cannot share that port.
- `MIDI.begin(MIDI_CHANNEL_OFF)` listens on no channel. The pedal only transmits.
- `btn_count` is `#define`d as 10 and the array length is a second literal 10.
- `delay(5)` runs inside `Button()`, which runs once per switch per scan. Ten switches add about 50 ms on top of the 25 ms debounce.
- The smoke test's `0x7F` grep will fight a correct latch implementation if 127 stops being a lone immediate. Update the test in the same change as the behavior.

AVR Boards 1.8.8 (released 21 May 2026) is the current stable core. 1.8.7 fixed CVE-2025-69209 (`String` float conversion). 1.8.8 fixed CVE-2026-48490. This sketch does not call those `String` helpers. Stay on 1.8.8 so the build stays on the patched core.

## 3. Modern fit

Versions below are the stable releases current on 30 September 2026. Prefer those over nightlies and over unreleased git tips.

### Keep

- **Arduino CLI 1.5.1** (5 June 2026), the latest stable. `1.5.2-rc.1` exists and is a release candidate. Do not pin it. `sketch.yaml` profiles are the format Arduino IDE 2 and the CLI already share. PlatformIO would replace a working build for no product gain.
- **Arduino AVR Boards 1.8.8.** It is the security-patched stable core for this board. Do not move the default target to a different MCU.
- **MIDI Library 5.0.2** (28 April 2020), still the Library Manager latest, MIT. The repo has had commits since the tag, including an open parser pull request in 2025, and none of that is a release. Serial MIDI at 31250 baud is a frozen protocol, and 5.0.2 already sends Control Change correctly. Stay on the tag. Do not compile library `master`.
- **Bounce2 2.71.0** (21 March 2022), Library Manager latest. GitHub `library.properties` says `2.72`, and that version is not a Library Manager release. Do not pin 2.72.

### Adopt only if the pedal grows past ten latches

- **[Control Surface](https://github.com/tttapa/Control-Surface) 2.1.2** (Pieter P). Library Manager name `Control Surface`. GPL-3.0. It is the maintained library aimed at this kind of product: buttons, LEDs, banks, serial MIDI, USB MIDI, and BLE MIDI. CI there already compiles examples for the Mega. `HardwareSerialMIDI_Interface` is the Mega UART path and matches this pedal. It is the wrong default for the current sketch: the pedal is ten switches, and linking GPL-3.0 into the sketch replaces this repo's MIT terms for the firmware. Use 2.1.2 only in Phase 3, and only after an explicit license decision, if the pedal gains banks or MIDI-driven LEDs.
- **[AceButton](https://github.com/bxparks/AceButton) 1.10.1** (25 May 2023, MIT). Events for press, release, click, double-click, and long-press. Useful if one switch later means "hold to change bank." Bounce2 already covers the current falling-edge latch. Do not swap debounce libraries for the ten-switch pedal.

### 16U2 USB MIDI firmware

The Mega's main MCU has no USB device controller. Class-compliant MIDI on this board means a 16U2 image, not an Arduino library.

- **HIDUINO** (`ddiakopoulos/hiduino`, MIT, upstream of the checked-in `arduino_midi.hex`). It is the firmware this repo already ships. It is old, and while it is loaded the Mega cannot accept a sketch upload over USB. Restoring `Arduino-usbserial-atmega16u2-Mega2560-Rev3.hex` brings USB upload back. Flashing needs the 16U2 DFU bootloader (RESET and HWB) or an ISP programmer. Do not invent a new 16U2 stack.
- **dualMocoLUFA** (`kuwatay/mocolufa`, about 2013–2015, built on LUFA 100807). A jumper selects USB MIDI or USB serial, which avoids reflashing to upload a sketch. It targets the Uno, and Mega clones have been reported to enumerate as the wrong board. Treat it as a hardware experiment, not the default image.

### Boards that make the 16U2 unnecessary

These are alternatives if the Mega hardware is retired. They are a different instrument, a different enclosure, and a different pin map. They are not the target of this plan.

- Arduino Micro / Leonardo (ATmega32U4) or a modern core with native USB, using the board's USB MIDI stack.
- A board Control Surface already tests (UNO R4, Pico, Teensy, ESP32-S3) if the license decision above is accepted.

Host-side tools for a bench test, not dependencies of the sketch: `amidi` and `aseqdump` (ALSA), or a DAW MIDI monitor. Hairless MIDI is a host workaround for the stock USB-serial firmware. It is not the target path.

## 4. Proposed direction

**Default architecture:** stay on the Mega 2560, Arduino CLI 1.5.1, AVR Boards 1.8.8, MIDI Library 5.0.2, and Bounce2 2.71.0. Keep the MIT license.

Split the sketch into two layers:

1. A tiny pure header, no `Arduino.h`, that owns the switch table and the message rule. Given a switch index and an event (`press` or `release`), it returns the Control Change to send, or nothing. Default rule: **latch**. A press that turns the function on sends value 127. The next press sends value 0. Channel stays 1. Controllers stay 80–89. Pins stay 22–31 and 13, 33–41.
2. The `.ino` file, which is only the adapter: attach Bounce2, read `fell()` / `rose()`, write the LED, call `MIDI.sendControlChange`.

Host tests compile the header with `g++` and assert the MIDI bytes. `smoke.sh` keeps proving the firmware still links MIDI Library and Bounce2 and still contains a channel-1 Control Change status (`0xB0`).

**Alternatives, not defaults:**

- Control Surface 2.1.2 if the surface grows and the firmware may be GPL-3.0.
- AceButton 1.10.1 if a long-press appears.
- dualMocoLUFA only as a bench experiment for upload-without-reflash.
- A native-USB board only if the Mega is retired.

**Behavior the first code change should lock in:**

- Delete `delay(5)`. Bounce2's 25 ms interval is the debounce. The scan loop should spin.
- Send 0 when a latch turns off, so the LED and the DAW match.
- On startup, drive every LED off and send value 0 for controllers 80–89 so a DAW session starts from a known state.
- Reject switch or LED pins 0 and 1 at compile time. Those pins are the UART.
- Derive the switch count from the table so the `#define` and the array length cannot drift.

Leave the pin map and the CC numbers alone. There is no schematic to justify moving pin 13.

## 5. Phased implementation

Each step lists the check that should pass before the next step starts. Run `./scripts/smoke.sh` after every firmware edit. A Mega on the bench is required only where a step says so.

### Phase 1 — quick wins

1. **Correct the USB story in the README.** State that the stock Mega 16U2 hex is a serial port, and that `arduino_midi.hex` (HIDUINO, strings `arduino_midi` / `hiduino project`) is the image that shows up as a MIDI device. State that flashing it disables USB sketch upload until the stock Mega usbserial hex is restored. Mention the Uno hex as unused by this sketch.
   - Check: README review. `./scripts/smoke.sh` still passes. No sketch diff.

2. **Add a host test for the message rule before changing runtime behavior.** New header plus a `g++` test: ten switches, unique CC numbers 80–89, channel 1, pins never 0 or 1, pin 13 used once. First latch press of switch 0 yields status `0xB0`, controller 80, value 127. Second press yields value 0. A falling edge is the only event that emits. Startup list is ten messages of value 0.
   - Check: the new test binary exits 0. Sketch still compiles via `smoke.sh`.

3. **Remove `delay(5)` from the scan.** Keep the 25 ms Bounce2 interval as a named constant in the header or in one place in the sketch.
   - Check: `grep` finds no `delay(` in `Mega_Pedal.ino`. `smoke.sh` passes.

4. **Wire the sketch to the latch rule.** Toggle the LED and send 127 or 0 together. Boot with LEDs off and a value-0 burst.
   - Check: host test from step 2 still passes. `smoke.sh` still requires the `MIDI` and `Bounce::` symbols and `0xB0`. Relax the hard requirement that `0x7F` appear as an immediate, because the value is now chosen at runtime; the host test covers 127 and 0.

5. **Document the compatibility break.** One README sentence: a second press now sends value 0. Rigs that learned "every press is 127" need to relearn the control.
   - Check: README contains that sentence. `smoke.sh` and the host test pass.

Do not bump `sketch.yaml` versions in Phase 1.

### Phase 2 — core pedal behavior

1. **Add an explicit mode on each row, default `latch`.** `momentary` sends 127 on press and 0 on release and lights the LED only while held.
   - Check: host tests cover both modes for one row, and the other nine rows stay latches. `smoke.sh` passes.

2. **Keep one table as the only map.** Channel, CC, switch pin, LED pin, mode. `static_assert` the length, the CC range 0–127, and the banned UART pins.
   - Check: a deliberately bad fixture (duplicate CC, or pin 0) fails the host test. The real table passes.

3. **Boot sync stays value 0 for every controller in the table, including momentary rows.**
   - Check: host test asserts the boot list length equals the table length and every value is 0.

4. **CI runs both checks.** Add a workflow job that compiles the host test with `g++`. Leave the Arduino CLI job on 1.5.1.
   - Check: both jobs green on a pull request. No board required.

5. **Expression input stays gated.** Add an analog treadle only after a wiring note in the README names the analog pin and the CC number (outside 80–89). The scaler (raw ADC to 0–127, with a small deadband) lives in the pure header.
   - Check: host test of the scaler. Until the pin is written down, do not read `analogRead` in the sketch.

### Phase 3 — polish

1. **Attribute the binaries.** Add a short notice next to `hex/` with upstream project, license, and the USB strings used to identify each file. Record that Arduino's 16U2 usbserial sources use a non-standard copyleft inside [ArduinoCore-avr](https://github.com/arduino/ArduinoCore-avr) (see issue 376), which is separate from this repo's MIT license. HIDUINO is MIT.
   - Check: a small script decodes the USB strings and fails if `arduino_midi.hex` no longer contains `hiduino project`, or the Mega usbserial hex no longer contains `Arduino (www.arduino.cc)`.

2. **Decide what to do with the Uno hex.** Nothing in the sketch or smoke test references it. Remove it in this phase, or move it behind a one-line "unused spare" note. Do not flash it onto a Mega 16U2.
   - Check: after removal, `smoke.sh` and the string check still pass.

3. **Bench checklist, run on a real Mega 2560 Rev3 with a 16U2.** This cannot run in CI.
   - Upload the sketch while the stock usbserial firmware is installed.
   - Flash `arduino_midi.hex` with DFU or ISP. Do not write fuse bytes copied from a random guide unless they match the board already in use.
   - `amidi -l` lists a MIDI input. `aseqdump` (or a DAW monitor) shows, for the first switch, `B0 50 7F` on the first press and `B0 50 00` on the second (`0x50` is controller 80).
   - Confirm USB sketch upload is gone while HIDUINO is installed, then restore `Arduino-usbserial-atmega16u2-Mega2560-Rev3.hex` and upload again.
   - Check: the checklist is in the README, and a person with the board has ticked it once.

4. **Revisit Control Surface only here.** If the pedal needs banks or LEDs driven by incoming MIDI, prototype against Control Surface 2.1.2 on a branch, and relicense the sketch to GPL-3.0 in that same change. If the ten latches are enough, leave MIDI Library and Bounce2 in place.
   - Check: either the dependency diff is empty, or the LICENSE change and a compiling `mega2560` profile land together.

## 6. Out of scope / risks

- **No secrets.** The repo has none. Do not add Wi-Fi credentials, API tokens, or a network service.
- **Dead or stale upstreams.** MIDI Library 5.0.2 and Bounce2 2.71.0 are old tags and still the Library Manager releases that match this job. HIDUINO and dualMocoLUFA are unmaintained 16U2 projects. Do not "upgrade" them by tracking git `master`, and do not rewrite LUFA firmware in this repo.
- **Wrong hex bricks USB, not the Mega.** An Uno image on a Mega 16U2, or a bad fuse write, drops the USB port until someone restores the Mega usbserial image with DFU or ISP. CI must not flash hardware. This plan does not include fuse commands.
- **License mix.** The sketch is MIT. Control Surface is GPL-3.0. Arduino 16U2 usbserial firmware is a non-standard copyleft, and these hex files ship without the matching source revision. Phase 3 documents that. Phase 1 does not delete the hex files.
- **Hardware this plan assumes.** One Arduino Mega 2560 whose 16U2 still has the DFU bootloader or is reachable by ISP. Ten switches to ground, ten LEDs. No display, no encoder, no analog jack, no 5-pin DIN transceiver. Pins 0 and 1 stay wired to the 16U2.
- **Host MIDI bridges.** Hairless, loopMIDI, and IAC are operator tools for the serial-port firmware. The product path is the HIDUINO image.
- **Other products.** BLE MIDI, Wi-Fi, OSC, DIN-only output, motorized faders, and a move to Pico, Teensy, or ESP32-S3 are out of scope. So are banks, long-press, and expression until Phase 2 or 3 explicitly opens them.
- **CVE status.** 1.8.8 already covers CVE-2025-69209 and CVE-2026-48490. The sketch does not convert floats to `String`. A later core bump waits for a newer stable release than 1.8.8.
- **Smoke-test false confidence.** `smoke.sh` proves the image links and contains a CC status byte. It does not prove debounce timing or that a DAW received the byte. The host test covers the message rule. Only the Phase 3 bench covers the cable.

## 7. Success criteria

The improvement worked when all of the following are true:

1. `./scripts/smoke.sh` passes on GitHub Actions with Arduino CLI 1.5.1, AVR Boards 1.8.8, Bounce2 2.71.0, and MIDI Library 5.0.2.
2. A host `g++` test, also run in CI, proves channel 1, controllers 80–89, value 127 then 0 on successive presses, value 0 at boot, and no use of pins 0 or 1.
3. `Mega_Pedal.ino` contains no `delay(` call. Responsiveness is the 25 ms debounce, not an extra ~50 ms scan stall.
4. The README states the trigger-to-latch change, which hex file is USB MIDI, and that HIDUINO disables USB upload until the Mega usbserial image is restored.
5. On a Mega 2560 Rev3 with `arduino_midi.hex` installed, a MIDI monitor shows `B0 50 7F` and then `B0 50 00` for the first switch, and the matching LED tracks those two states.
6. The firmware license stays MIT, unless a later change adopts Control Surface and updates `LICENSE` in the same commit.
7. Flash use stays small relative to the Mega's 256 KB, and the ten `Bounce` objects still fit in the 8 KB SRAM. `smoke.sh` already prints the sketch size line; keep an eye on that line when the table grows.

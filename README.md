# arduino-foot-midi-controller

A foot MIDI controller pedal for the Arduino Mega 2560. Ten footswitches send MIDI control changes on channel 1, and each switch toggles a matching LED. Debouncing uses Bounce2. MIDI goes out the Mega's hardware UART (pins 0/1), which the on-board 16U2 bridges to USB.

The improvement plan for this firmware is in [PLAN.md](PLAN.md).

## Build

Requires [Arduino CLI](https://arduino.github.io/arduino-cli/) 1.5.x (or Arduino IDE 2, which reads the same sketch profile).

```sh
./scripts/smoke.sh
```

`Mega_Pedal/sketch.yaml` pins the toolchain and libraries:

| Component | Version |
| --- | --- |
| Board | Arduino Mega 2560 (`arduino:avr:mega`) |
| Arduino AVR Boards | 1.8.8 |
| Bounce2 | 2.71.0 |
| MIDI Library | 5.0.2 |

Arduino AVR Boards 1.8.8 includes the fix for CVE-2025-69209 (`String` float conversion). This sketch does not call those helpers; the pin keeps the build on the patched core.

The profile downloads those exact versions on the first compile. In the Arduino IDE, open `Mega_Pedal/Mega_Pedal.ino` and select the `mega2560` profile.

## `hex/`

Those files are prebuilt firmware for the ATmega16U2 USB interface, not the Mega sketch:

- `Arduino-usbserial-atmega16u2-Mega2560-Rev3.hex` and `Arduino-usbserial-uno.hex` are the stock Arduino USB-serial bridges.
- `arduino_midi.hex` is a USB-MIDI bridge (the device name in the descriptor is `arduino_midi`).

Flash one of them onto the 16U2 only if you intend to change how the pedal shows up on USB. The Mega sketch itself is built from `Mega_Pedal/`.

# mFanCtl

mFanCtl is a macOS menu bar fan control utility for Apple Silicon Macs.

## Requirements

- Apple Silicon Mac
- macOS 14 or later
- Administrator permission is required to install the helper tool

Intel Macs are not supported.

## Features

- Show fan RPM and GPU temperature in the menu bar
- Read Apple Silicon fan speed and temperature sensors
- Switch fan mode between Automatic and Maximum Speed
- Create custom fan presets
- Customize the menu bar display format
- Optional launch at login

## Installation

Download the latest DMG from the Releases page, open it, and drag `mFanCtl.app`
to Applications.

On first fan-control use, macOS will ask for administrator permission to install
the helper tool.

## Notes

mFanCtl uses undocumented Apple SMC interfaces. Sensor availability and fan
behavior may vary by Mac model and macOS version.

Use fan control carefully. If something behaves unexpectedly, switch back to
Automatic mode or restart your Mac.

## License

MIT

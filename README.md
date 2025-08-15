# mac-volume

Control the volume of an output audio device on macOS via the command line.

This is particularly useful for controlling the volume of a device that's not
the default, but is, for example, currently in active use for a video call.


## Installation

### Download binary (recommended)

Download the latest binary from the [releases page](https://github.com/akrabat/quickss/releases).

### Compile from source

```bash
swiftc mac-volume.swift -o mac-volume
```

## Usage

```bash
# List available output devices
mac-volume list-devices

# Get the volume (between 0 and 100)
mac-volume "MacBook Pro Speakers" get

# Set the volume between 0 and 100
mac-volume "MacBook Pro Speakers" set <number>

# Increase the volume
mac-volume "MacBook Pro Speakers" inc [<number=2>]

# Decrease the volume
mac-volume "MacBook Pro Speakers" dec [<number=2>]


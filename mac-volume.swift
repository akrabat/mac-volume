import CoreAudio
import AudioToolbox

let version = "1.0.0"

func getDeviceID(named name: String) -> AudioDeviceID? {
    var size = UInt32(0)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    // Get device list size
    guard AudioObjectGetPropertyDataSize(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        0,
        nil,
        &size
    ) == noErr else { return nil }

    let deviceCount = Int(size) / MemoryLayout<AudioDeviceID>.size
    var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

    guard AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        0,
        nil,
        &size,
        &deviceIDs
    ) == noErr else { return nil }

    // Find device by name
    for deviceID in deviceIDs {
        var nameSize = UInt32(0)
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Get the size of the name property
        guard AudioObjectGetPropertyDataSize(deviceID, &nameAddress, 0, nil, &nameSize) == noErr else { continue }
        
        // Get the name using proper memory management
        var deviceName: Unmanaged<CFString>?
        let status = withUnsafeMutablePointer(to: &deviceName) { pointer in
            AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, pointer)
        }
        
        if status == noErr, let unmanagedName = deviceName {
            let cfString = unmanagedName.takeUnretainedValue()
            if (cfString as String) == name {
                return deviceID
            }
        }
    }
    return nil
}

func getDeviceVolume(deviceID: AudioDeviceID) -> Float32? {
    var volume: Float32 = 0.0
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    var size = UInt32(MemoryLayout<Float32>.size)
    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
    return status == noErr ? volume : nil
}

func setDeviceVolume(deviceID: AudioDeviceID, volume: Float32) -> Bool {
    var vol = volume
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &vol)
    return status == noErr
}

func hasOutputStreams(deviceID: AudioDeviceID) -> Bool {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreams,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    
    var size = UInt32(0)
    let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
    return status == noErr && size > 0
}

func listOutputDevices() {
    var size = UInt32(0)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    guard AudioObjectGetPropertyDataSize(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        0,
        nil,
        &size
    ) == noErr else {
        print("Failed to get device list")
        return
    }

    let deviceCount = Int(size) / MemoryLayout<AudioDeviceID>.size
    var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

    guard AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        0,
        nil,
        &size,
        &deviceIDs
    ) == noErr else {
        print("Failed to get device data")
        return
    }

    print("Available output devices:")
    
    for deviceID in deviceIDs {
        if hasOutputStreams(deviceID: deviceID) {
            var nameSize = UInt32(0)
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            guard AudioObjectGetPropertyDataSize(deviceID, &nameAddress, 0, nil, &nameSize) == noErr else { continue }
            
            var deviceName: Unmanaged<CFString>?
            let status = withUnsafeMutablePointer(to: &deviceName) { pointer in
                AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, pointer)
            }
            
            if status == noErr, let unmanagedName = deviceName {
                let cfString = unmanagedName.takeUnretainedValue()
                print("  \(cfString as String)")
            }
        }
    }
}

// ---- Main ----
let args = CommandLine.arguments

// Check for list-devices command
if args.count == 2 && args[1] == "list-devices" {
    listOutputDevices()
} else if args.count == 3 && args[2] == "get" {
    let deviceName = args[1]
    if let deviceID = getDeviceID(named: deviceName) {
        if let currentVolume = getDeviceVolume(deviceID: deviceID) {
            let volumePercent = Int(currentVolume * 100)
            print("\(volumePercent)")
        } else {
            print("Failed to get volume for \(deviceName)")
            exit(1)
        }
    } else {
        print("Device not found: \(deviceName)")
        exit(1)
    }
} else if args.count == 4 && args[2] == "set" {
    // Set volume mode
    let deviceName = args[1]
    let volumeInput = Float32(args[3]) ?? 50.0
    let volume = volumeInput / 100.0
    
    if let deviceID = getDeviceID(named: deviceName) {
        if setDeviceVolume(deviceID: deviceID, volume: volume) {
            print("Set \(deviceName) volume to \(volumeInput)%")
        } else {
            print("Failed to set volume for \(deviceName)")
        }
    } else {
        print("Device not found: \(deviceName)")
    }
} else if (args.count == 3 || args.count == 4) && (args[2] == "inc" || args[2] == "dec") {
    // Increment or decrement volume
    let deviceName = args[1]
    let command = args[2]
    let amount = args.count == 4 ? (Float32(args[3]) ?? 2.0) : 2.0
    
    if let deviceID = getDeviceID(named: deviceName) {
        if let currentVolume = getDeviceVolume(deviceID: deviceID) {
            let currentPercent = currentVolume * 100
            let newPercent: Float32
            
            if command == "inc" {
                newPercent = min(100.0, currentPercent + amount)
            } else {
                newPercent = max(0.0, currentPercent - amount)
            }
            
            let newVolume = newPercent / 100.0
            
            if setDeviceVolume(deviceID: deviceID, volume: newVolume) {
                print("Set \(deviceName) volume to \(Int(newPercent))%")
            } else {
                print("Failed to set volume for \(deviceName)")
            }
        } else {
            print("Failed to get current volume for \(deviceName)")
            exit(1)
        }
    } else {
        print("Device not found: \(deviceName)")
        exit(1)
    }
} else {
    print("""
mac-volume v\(version) - Control the volume of a device on your mac

Usage:
  mac-volume list-devices
  mac-volume <Device Name> set <0 - 100>
  mac-volume <Device Name> get
  mac-volume <Device Name> inc [amount]
  mac-volume <Device Name> dec [amount]
""")
    exit(0)
}

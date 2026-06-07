import CoreAudio

/// Typed wrappers around the verbose AudioObjectGetPropertyData API.
enum CoreAudioProperty {

    static func address(for selector: AudioObjectPropertySelector,
                        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    static func value<T: FixedWidthInteger>(of objectID: AudioObjectID, selector: AudioObjectPropertySelector, default defaultValue: T) -> T {
        var address = address(for: selector)
        var size = UInt32(MemoryLayout<T>.size)
        var value = defaultValue
        guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value) == noErr else { return defaultValue }
        return value
    }

    static func bool(of objectID: AudioObjectID, selector: AudioObjectPropertySelector) -> Bool {
        value(of: objectID, selector: selector, default: UInt32(0)) != 0
    }

    static func objectIDs(of objectID: AudioObjectID, selector: AudioObjectPropertySelector,
                          scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> [AudioObjectID] {
        var address = address(for: selector, scope: scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var list = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.stride)
        guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &list) == noErr else { return [] }
        return list
    }

    static func string(of objectID: AudioObjectID, selector: AudioObjectPropertySelector) -> String? {
        var address = address(for: selector)
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var value: Unmanaged<CFString>?
        guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }
}

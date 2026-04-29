import AppKit
import Carbon.HIToolbox

final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?
    private let id: UInt32

    private static var instances: [UInt32: HotKey] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    init() {
        self.id = HotKey.nextID
        HotKey.nextID += 1
    }

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        self.handler = handler
        HotKey.instances[id] = self
        HotKey.installHandlerIfNeeded()

        let hkID = EventHotKeyID(signature: OSType(0x434C4950), id: id) // 'CLIP'
        RegisterEventHotKey(keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        HotKey.instances.removeValue(forKey: id)
    }

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, eventRef, _ -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(eventRef, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            DispatchQueue.main.async {
                HotKey.instances[hkID.id]?.handler?()
            }
            return noErr
        }, 1, &spec, nil, nil)
    }
}

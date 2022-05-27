//
// Created by Gyuhwan Park on 2022/05/08.
//

import Foundation

import Carbon
import CoreGraphics


enum EventInjectorError: LocalizedError {
    case initializationError

    var errorDescription: String? {
        switch (self) {
        case .initializationError:
            return "could not initialize EventInjector instance. (insufficient permission?)"
        }
    }
}

class EventInjector {
    public static let MOUSE_DOWN_STATE_LEFT: UInt16 = 0b1
    public static let MOUSE_DOWN_STATE_RIGHT: UInt16 = 0b10

    public let serialQueue = DispatchQueue(label: "EventInjector", qos: .userInteractive)

    private var eventSource: CGEventSource!
    private var eventTap: CFMachPort!

    private(set) public var keyDownState = Set<Int>()

    private(set) public var mouseClickedButton: Int64 = 0
    private(set) public var mouseClickedAt: Double = 0

    private(set) public var mouseDownState: UInt16 = 0
    private(set) public var lastMousePosition: CGPoint? = nil

    init() {
    }

    func prepare() throws {
        guard let eventTap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: UInt64(CGEventType.keyDown.rawValue),
                callback: { (proxy, type, event, refcon) in
                    return Unmanaged.passUnretained(event)
                },
                userInfo: nil
        ), let eventSource = CGEventSource(
                stateID: .combinedSessionState
        )
        else {
            throw EventInjectorError.initializationError
        }

        self.eventTap = eventTap
        self.eventSource = eventSource
    }

    func post(keyEvent event: ULIPCKeyboardEvent) {
        let isNOOP = event.type == 0
        let isKeyDown = event.type == 2

        if (isNOOP) {
            return
        }

        if (isKeyDown) {
            keyDownState.insert(Int(event.keyCode))
        } else {
            keyDownState.remove(Int(event.keyCode))
        }

        guard let cgEvent = CGEvent(
                keyboardEventSource: eventSource,
                virtualKey: CGKeyCode(event.keyCode),
                keyDown: isKeyDown
        )
        else {
            return
        }

        cgEvent.sanitizeModifierFlags(with: keyDownState)
        cgEvent.post(tap: .cgSessionEventTap)
    }

    func post(mouseMoveEvent event: ULIPCMouseMoveEvent) {
        var mouseType: CGEventType = .mouseMoved
        var mouseButton: CGMouseButton = .left
        let position = CGPoint(x: Int(event.x), y: Int(event.y))

        if (mouseDownState & EventInjector.MOUSE_DOWN_STATE_LEFT > 0) {
            mouseType = .leftMouseDragged
        } else if (mouseDownState & EventInjector.MOUSE_DOWN_STATE_RIGHT > 0) {
            mouseType = .rightMouseDragged
        }

        guard let cgEvent = CGEvent(
                mouseEventSource: eventSource,
                mouseType: mouseType,
                mouseCursorPosition: position,
                mouseButton: mouseButton
        )
        else {
            return
        }

        cgEvent.sanitizeModifierFlags(with: keyDownState)
        cgEvent.post(tap: .cgSessionEventTap)

        lastMousePosition = position
    }

    func post(mouseButtonEvent event: ULIPCMouseButtonEvent) {
        var mouseType: CGEventType = .null

        switch (event.button) {
        case 0:
            let mask = EventInjector.MOUSE_DOWN_STATE_LEFT

            mouseType = (event.type == 1 ? .leftMouseUp : .leftMouseDown)
            mouseDownState |= (event.type == 1 ? ~mask : mask)
            break
        case 1:
            let mask = EventInjector.MOUSE_DOWN_STATE_RIGHT

            mouseType = (event.type == 1 ? .rightMouseUp : .rightMouseDown)
            mouseDownState |= (event.type == 1 ? ~mask : mask)
            break

        default:
            break
        }

        guard let cgEvent = CGEvent(
                mouseEventSource: eventSource,
                mouseType: mouseType,
                mouseCursorPosition: lastMousePosition ?? CGEvent(source: nil)!.location,
                mouseButton: .center
        )
        else {
            return
        }

        let now = Date().timeIntervalSince1970
        if (event.type == 1) {
            if ((now - mouseClickedAt) < 0.5) {
                cgEvent.setIntegerValueField(.mouseEventClickState, value: 2)
            }

            mouseClickedButton = Int64(event.button)
            mouseClickedAt = now
        }

        cgEvent.sanitizeModifierFlags(with: keyDownState)
        cgEvent.post(tap: .cgSessionEventTap)
    }

    func post(mouseWheelEvent event: ULIPCMouseWheelEvent) {
        var mouseType: CGEventType = .null

        guard let cgEvent = CGEvent(
                scrollWheelEvent2Source: eventSource,
                units: .pixel,
                wheelCount: 1,
                wheel1: -event.deltaY,
                wheel2: event.deltaX,
                wheel3: 0
        )
        else {
            return
        }

        cgEvent.sanitizeModifierFlags(with: keyDownState)
        cgEvent.post(tap: .cgSessionEventTap)
    }
}

fileprivate extension CGEvent {
    func sanitizeModifierFlags(with keyDownState: Set<Int>) {
        // HACK: 이유는 모르겠으나 fn 키가 계속 눌림
        flags.remove(.maskSecondaryFn)

        if (!(keyDownState.contains(kVK_Shift) ||
              keyDownState.contains(kVK_RightShift))) {
            flags.remove(.maskShift)
        }

        if (!(keyDownState.contains(kVK_Option) ||
              keyDownState.contains(kVK_RightOption))) {
            flags.remove(.maskAlternate)
        }

        if (!(keyDownState.contains(kVK_Control) ||
              keyDownState.contains(kVK_RightControl))) {
            flags.remove(.maskControl)
        }

        if (!(keyDownState.contains(kVK_Command) ||
              keyDownState.contains(kVK_RightCommand))) {
            flags.remove(.maskCommand)
        }
    }
}
import Foundation

enum ControlKind {
    case slider(unit: String?)
    case toggle
    case options([(value: Int, label: String)])
}

/// One UVC control (or one field of a multi-field control such as pan/tilt).
struct ControlSpec: Identifiable {
    let id: String
    let name: String
    let entity: UInt8
    let selector: UInt8
    let totalLength: UInt16     // wLength of the request
    let offset: Int             // byte offset of this field inside the payload
    let fieldLength: Int
    let signed: Bool
    let kind: ControlKind
    /// This control is disabled while the referenced control satisfies the predicate.
    let disabledWhen: (id: String, predicate: (Int) -> Bool)?

    init(_ id: String, _ name: String, entity: UInt8, selector: UInt8, length: UInt16,
         offset: Int = 0, fieldLength: Int? = nil, signed: Bool = false, kind: ControlKind = .slider(unit: nil),
         disabledWhen: (id: String, predicate: (Int) -> Bool)? = nil) {
        self.id = id; self.name = name; self.entity = entity; self.selector = selector
        self.totalLength = length; self.offset = offset; self.fieldLength = fieldLength ?? Int(length)
        self.signed = signed; self.kind = kind; self.disabledWhen = disabledWhen
    }
}

struct ControlGroup: Identifiable {
    let id: String
    let controls: [ControlSpec]
}

enum UVC {
    static let cameraTerminal: UInt8 = 1
    static let processingUnit: UInt8 = 3

    static let aeManual = 1

    static let groups: [ControlGroup] = [
        ControlGroup(id: "Focus & Zoom", controls: [
            ControlSpec("focusAuto", "Autofocus", entity: cameraTerminal, selector: 0x08, length: 1, kind: .toggle),
            ControlSpec("focus", "Focus", entity: cameraTerminal, selector: 0x06, length: 2,
                        disabledWhen: (id: "focusAuto", predicate: { $0 == 1 })),
            ControlSpec("zoom", "Zoom", entity: cameraTerminal, selector: 0x0B, length: 2),
            ControlSpec("pan", "Pan", entity: cameraTerminal, selector: 0x0D, length: 8, offset: 0, fieldLength: 4, signed: true),
            ControlSpec("tilt", "Tilt", entity: cameraTerminal, selector: 0x0D, length: 8, offset: 4, fieldLength: 4, signed: true),
        ]),
        ControlGroup(id: "Exposure", controls: [
            ControlSpec("aeMode", "Exposure Mode", entity: cameraTerminal, selector: 0x02, length: 1,
                        kind: .options([(1, "Manual"), (2, "Auto"), (4, "Shutter Priority"), (8, "Aperture Priority")])),
            ControlSpec("aePriority", "Allow Frame-Rate Drop", entity: cameraTerminal, selector: 0x03, length: 1, kind: .toggle),
            ControlSpec("exposure", "Exposure Time", entity: cameraTerminal, selector: 0x04, length: 4, kind: .slider(unit: "×0.1 ms"),
                        disabledWhen: (id: "aeMode", predicate: { $0 != aeManual })),
            ControlSpec("gain", "Gain", entity: processingUnit, selector: 0x04, length: 2,
                        disabledWhen: (id: "aeMode", predicate: { $0 != aeManual })),
            ControlSpec("backlight", "Backlight Compensation", entity: processingUnit, selector: 0x01, length: 2),
        ]),
        ControlGroup(id: "Image", controls: [
            ControlSpec("brightness", "Brightness", entity: processingUnit, selector: 0x02, length: 2, signed: true),
            ControlSpec("contrast", "Contrast", entity: processingUnit, selector: 0x03, length: 2),
            ControlSpec("saturation", "Saturation", entity: processingUnit, selector: 0x07, length: 2),
            ControlSpec("sharpness", "Sharpness", entity: processingUnit, selector: 0x08, length: 2),
        ]),
        ControlGroup(id: "White Balance", controls: [
            ControlSpec("wbAuto", "Auto White Balance", entity: processingUnit, selector: 0x0B, length: 1, kind: .toggle),
            ControlSpec("wb", "Color Temperature", entity: processingUnit, selector: 0x0A, length: 2, kind: .slider(unit: "K"),
                        disabledWhen: (id: "wbAuto", predicate: { $0 == 1 })),
            ControlSpec("powerLine", "Power Line Frequency", entity: processingUnit, selector: 0x05, length: 1,
                        kind: .options([(0, "Disabled"), (1, "50 Hz"), (2, "60 Hz")])),
        ]),
    ]

    static let allControls: [ControlSpec] = groups.flatMap(\.controls)
}

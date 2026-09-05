import Foundation
import Combine

struct ControlRange {
    var min: Int
    var max: Int
    var res: Int
    var def: Int
    var supportedMask: Int   // GET_RES for bitmap controls (exposure mode)
    var settable: Bool
}

@MainActor
final class CameraModel: ObservableObject {
    static let vendorID: UInt16 = 0x046d
    static let productID: UInt16 = 0x08e5

    @Published private(set) var connected = false
    @Published private(set) var values: [String: Int] = [:]
    @Published private(set) var ranges: [String: ControlRange] = [:]
    @Published var statusMessage = ""

    private var device: UVCDevice?
    private let profileKey = "savedProfile"

    var hasProfile: Bool { UserDefaults.standard.dictionary(forKey: profileKey) != nil }

    func connect() {
        do {
            device = try UVCDevice(vendorID: Self.vendorID, productID: Self.productID)
            connected = true
            statusMessage = ""
            refresh()
        } catch {
            device = nil
            connected = false
            statusMessage = error.localizedDescription
        }
    }

    func refresh() {
        guard device != nil else { return }
        for spec in UVC.allControls {
            if ranges[spec.id] == nil { ranges[spec.id] = readRange(spec) }
            if let cur = read(0x81, spec) { values[spec.id] = cur }
        }
    }

    func isDisabled(_ spec: ControlSpec) -> Bool {
        guard let dep = spec.disabledWhen, let v = values[dep.id] else { return false }
        return dep.predicate(v)
    }

    func set(_ spec: ControlSpec, to value: Int) {
        guard let device else { return }
        // Read the whole payload first so multi-field controls (pan/tilt) keep their other field.
        var payload = (try? device.getRequest(0x81, entity: spec.entity, selector: spec.selector, length: spec.totalLength))
            ?? Data(count: Int(spec.totalLength))
        var raw = Int64(value)
        withUnsafeBytes(of: &raw) { src in
            payload.replaceSubrange(spec.offset..<spec.offset + spec.fieldLength, with: src.prefix(spec.fieldLength))
        }
        do {
            try device.setEntity(spec.entity, selector: spec.selector, data: payload)
            values[spec.id] = value
            statusMessage = ""
        } catch {
            statusMessage = "\(spec.name): \(error.localizedDescription)"
            handleTransportError(error)
        }
    }

    func resetToDefaults() {
        // Autos first so the dependent manual controls are not rejected.
        let ordered = UVC.allControls.sorted { ($0.disabledWhen == nil ? 0 : 1) < ($1.disabledWhen == nil ? 0 : 1) }
        for spec in ordered {
            if let r = ranges[spec.id] { set(spec, to: r.def) }
        }
        refresh()
    }

    func saveProfile() {
        UserDefaults.standard.set(values, forKey: profileKey)
        objectWillChange.send()
    }

    func applyProfile() {
        guard let saved = UserDefaults.standard.dictionary(forKey: profileKey) as? [String: Int] else { return }
        let ordered = UVC.allControls.sorted { ($0.disabledWhen == nil ? 0 : 1) < ($1.disabledWhen == nil ? 0 : 1) }
        for spec in ordered {
            if let v = saved[spec.id] { set(spec, to: v) }
        }
        refresh()
    }

    // MARK: - Transport

    private func read(_ request: UInt8, _ spec: ControlSpec) -> Int? {
        guard let device else { return nil }
        do {
            let data = try device.getRequest(request, entity: spec.entity, selector: spec.selector, length: spec.totalLength)
            return decode(data, spec)
        } catch {
            handleTransportError(error)
            return nil
        }
    }

    private func readRange(_ spec: ControlSpec) -> ControlRange {
        let info = read(0x86, spec) ?? 0
        let res = read(0x84, spec) ?? 1
        return ControlRange(min: read(0x82, spec) ?? 0, max: read(0x83, spec) ?? 0,
                            res: Swift.max(res, 1), def: read(0x87, spec) ?? 0,
                            supportedMask: res, settable: info & 0x02 != 0)
    }

    private func decode(_ data: Data, _ spec: ControlSpec) -> Int {
        var raw: UInt64 = 0
        let field = data.subdata(in: spec.offset..<spec.offset + spec.fieldLength)
        withUnsafeMutableBytes(of: &raw) { $0.copyBytes(from: field) }
        if spec.signed {
            let bits = spec.fieldLength * 8
            let signBit: UInt64 = 1 << (bits - 1)
            if raw & signBit != 0 { return Int(Int64(bitPattern: raw | ~((1 << bits) - 1))) }
        }
        return Int(raw)
    }

    private func handleTransportError(_ error: Error) {
        // Pipe stalls are normal for requests a control does not implement (e.g. GET_MIN on a boolean).
        // Only treat "device gone" IOKit codes as a disconnect.
        let goneCodes: Set<Int> = [
            Int(Int32(bitPattern: 0xE00002C0)),  // kIOReturnNoDevice
            Int(Int32(bitPattern: 0xE00002D9)),  // kIOReturnNotAttached
            Int(Int32(bitPattern: 0xE00002ED)),  // kIOReturnNotResponding
        ]
        let nsError = error as NSError
        if nsError.domain == "UVCDevice" || goneCodes.contains(nsError.code) {
            device = nil
            connected = false
            statusMessage = "Camera disconnected"
        }
    }
}

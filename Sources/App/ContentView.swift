import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: CameraModel
    @AppStorage("showPreview") private var showPreview = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if model.connected {
                if showPreview {
                    PreviewView()
                        .frame(height: 202)   // 360 x 202 keeps 16:9
                        .id("preview")
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(UVC.groups) { group in
                            groupView(group)
                        }
                    }
                    .padding(12)
                }
                .frame(height: 440)
                Divider()
                footer
            } else {
                VStack(spacing: 8) {
                    Text(model.statusMessage.isEmpty ? "Camera not connected" : model.statusMessage)
                        .foregroundStyle(.secondary)
                    Button("Retry") { model.connect() }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            }
        }
        .frame(width: 360)
        .onAppear {
            model.connect()
            // UVCAssistant may rewrite controls when the stream starts; re-read once it settles.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { model.refresh() }
        }
    }

    private var header: some View {
        HStack {
            Text("C920 Control").font(.headline)
            Spacer()
            Toggle("Preview", isOn: $showPreview).toggleStyle(.switch).controlSize(.mini)
            Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless).help("Re-read all values from the camera")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button("Save Profile") { model.saveProfile() }
                Button("Apply Profile") { model.applyProfile() }.disabled(!model.hasProfile)
                Spacer()
                Button("Defaults") { model.resetToDefaults() }
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .controlSize(.small)
            if !model.statusMessage.isEmpty {
                Text(model.statusMessage).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private func groupView(_ group: ControlGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.id).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(group.controls) { spec in
                controlRow(spec)
            }
        }
    }

    @ViewBuilder
    private func controlRow(_ spec: ControlSpec) -> some View {
        let range = model.ranges[spec.id] ?? ControlRange(min: 0, max: 1, res: 1, def: 0, supportedMask: 0, settable: false)
        let value = model.values[spec.id] ?? range.def
        let disabled = model.isDisabled(spec) || !range.settable
        switch spec.kind {
        case .toggle:
            toggleRow(spec, value: value, disabled: disabled)
        case .slider(let unit):
            if range.min == 0 && range.max == 1 {
                toggleRow(spec, value: value, disabled: disabled)
            } else {
                sliderRow(spec, value: value, range: range, unit: unit, disabled: disabled)
            }
        case .options(let options):
            let available = options.filter { range.supportedMask == 0 || range.supportedMask & $0.value != 0 || $0.value == value }
            Picker(spec.name, selection: Binding(get: { value }, set: { model.set(spec, to: $0) })) {
                ForEach(available, id: \.value) { Text($0.label).tag($0.value) }
            }
            .disabled(disabled)
        }
    }

    private func toggleRow(_ spec: ControlSpec, value: Int, disabled: Bool) -> some View {
        Toggle(spec.name, isOn: Binding(get: { value != 0 }, set: { model.set(spec, to: $0 ? 1 : 0) }))
            .toggleStyle(.switch).controlSize(.small)
            .disabled(disabled)
    }

    private func sliderRow(_ spec: ControlSpec, value: Int, range: ControlRange, unit: String?, disabled: Bool) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(spec.name)
                Spacer()
                Text(verbatim: unit.map { "\(value) \($0)" } ?? "\(value)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .onTapGesture(count: 2) { model.set(spec, to: range.def) }
                    .help("Double-click to reset to default (\(range.def))")
            }
            Slider(value: Binding(get: { Double(value) }, set: { model.set(spec, to: snap(Int($0.rounded()), range)) }),
                   in: Double(range.min)...Double(max(range.max, range.min + 1)))
                .controlSize(.small)
        }
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }

    private func snap(_ v: Int, _ r: ControlRange) -> Int {
        let stepped = r.min + ((v - r.min) / r.res) * r.res
        return min(max(stepped, r.min), r.max)
    }
}

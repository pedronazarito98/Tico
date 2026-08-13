import SwiftUI

struct TrackpadCalibrationView: View {
    @ObservedObject var store: TrackpadCalibrationStore
    @Binding var highlightedRegion: TrackpadRegion
    @State private var selectedGesture = TrackpadGesture.swipeRight

    var body: some View {
        ScrollView {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    calibrationForm
                        .frame(minWidth: 340, maxWidth: .infinity)
                    previewPane
                        .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
                }
                .frame(minWidth: 680)

                VStack(alignment: .leading, spacing: 16) {
                    calibrationForm
                    previewPane
                        .frame(maxWidth: 420)
                }
            }
            .padding(8)
        }
    }

    private var calibrationForm: some View {
        Form {
            Section("Gesto") {
                Picker("Calibrar", selection: $selectedGesture) {
                    ForEach(TrackpadGesture.allCases, id: \.self) { gesture in
                        Text(gesture.displayName).tag(gesture)
                    }
                }
                Picker("Preset", selection: presetBinding) {
                    ForEach(GestureCalibrationPreset.allCases, id: \.self) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
            }

            Section("Limiar") {
                sliderRow(
                    "Sensibilidade",
                    value: calibrationBinding(\.sensitivity),
                    range: 0.25...2,
                    format: { $0.formatted(.number.precision(.fractionLength(2))) }
                )
                sliderRow(
                    "Confiança mínima",
                    value: calibrationBinding(\.confidenceThreshold),
                    range: 0.1...0.95,
                    format: { $0.formatted(.percent.precision(.fractionLength(0))) }
                )
            }

            Section("Velocidade") {
                optionalVelocityRow(
                    "Mínima",
                    value: calibration.minimumVelocity,
                    onChange: updateMinimumVelocity
                )
                optionalVelocityRow(
                    "Máxima",
                    value: calibration.maximumVelocity,
                    onChange: updateMaximumVelocity
                )
            }

            Section {
                Button("Restaurar padrão equilibrado") {
                    store.applyPreset(.balanced, to: selectedGesture)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Visualizar região", selection: $highlightedRegion) {
                ForEach(TrackpadRegion.allCases, id: \.self) { region in
                    Text(region.displayName).tag(region)
                }
            }
            TrackpadCanvasView(snapshot: nil, highlightedRegion: highlightedRegion)
                .aspectRatio(19.0 / 14.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
            Text("As regiões de borda, canto e grade podem ser usadas tanto no início quanto no final de uma regra.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 18)
    }

    private var calibration: GestureCalibration {
        store.calibration(for: selectedGesture)
    }

    private var presetBinding: Binding<GestureCalibrationPreset> {
        Binding(
            get: { calibration.preset },
            set: { preset in
                if preset != .custom {
                    store.applyPreset(preset, to: selectedGesture)
                }
            }
        )
    }

    private func calibrationBinding(
        _ keyPath: WritableKeyPath<GestureCalibration, Double>
    ) -> Binding<Double> {
        Binding(
            get: { calibration[keyPath: keyPath] },
            set: { value in
                var updated = calibration
                updated[keyPath: keyPath] = value
                store.update(updated, for: selectedGesture)
            }
        )
    }

    private func sliderRow(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: @escaping (Double) -> String
    ) -> some View {
        LabeledContent(title) {
            HStack {
                Slider(value: value, in: range)
                    .frame(minWidth: 100, idealWidth: 190)
                Text(format(value.wrappedValue))
                    .monospacedDigit()
                    .frame(width: 54, alignment: .trailing)
            }
        }
    }

    private func optionalVelocityRow(
        _ title: String,
        value: Double?,
        onChange: @escaping (Double?) -> Void
    ) -> some View {
        HStack {
            Toggle(
                title,
                isOn: Binding(
                    get: { value != nil },
                    set: { onChange($0 ? (value ?? 0.05) : nil) }
                )
            )
            if let value {
                Slider(
                    value: Binding(get: { value }, set: { onChange($0) }),
                    in: 0...3
                )
                Text(value.formatted(.number.precision(.fractionLength(2))))
                    .monospacedDigit()
                    .frame(width: 42, alignment: .trailing)
            }
        }
    }

    private func updateMinimumVelocity(_ value: Double?) {
        var updated = calibration
        updated.minimumVelocity = value
        store.update(updated, for: selectedGesture)
    }

    private func updateMaximumVelocity(_ value: Double?) {
        var updated = calibration
        updated.maximumVelocity = value
        store.update(updated, for: selectedGesture)
    }
}

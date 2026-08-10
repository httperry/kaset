import SwiftUI

/// Settings section for configuring audio fading preferences and volume curves.
struct AudioFadingSettingsSection: View {
    @Bindable var settings: SettingsManager

    @State private var selectedCurve: AudioFaderService.FadeCurve = .logarithmic

    var body: some View {
        Form {
            Section {
                Toggle(isOn: self.$settings.audioFadingEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Smooth Audio Volume Fading")
                            .font(.body)
                        Text("Gradually ramps audio volume up and down on play, pause, and track transitions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if self.settings.audioFadingEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Fade Duration")
                            Spacer()
                            Text(String(format: "%.1f seconds", self.settings.audioFadeDuration))
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        Slider(
                            value: self.$settings.audioFadeDuration,
                            in: 0.5 ... 3.0,
                            step: 0.1
                        ) {
                            Text("Fade Duration")
                        } minimumValueLabel: {
                            Text("0.5s").font(.caption).foregroundStyle(.secondary)
                        } maximumValueLabel: {
                            Text("3.0s").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)

                    Picker("Attenuation Curve", selection: self.$selectedCurve) {
                        ForEach(AudioFaderService.FadeCurve.allCases) { curve in
                            Text(curve.displayName).tag(curve)
                        }
                    }
                    .pickerStyle(.menu)
                }
            } header: {
                Label("Audio Fading Controls", systemImage: "waveform.path.badge.plus")
                    .font(.headline)
            } footer: {
                Text("Logarithmic attenuation mimics human ear loudness perception for a natural fade effect.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
    }
}

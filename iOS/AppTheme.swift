import SwiftUI
import UIKit

enum AppTheme {
    private static func adaptive(_ light: UIColor, _ dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    static let background = adaptive(
        UIColor(red: 0.97, green: 0.97, blue: 0.95, alpha: 1),
        UIColor(red: 0.055, green: 0.075, blue: 0.065, alpha: 1))
    static let surface = adaptive(
        UIColor(red: 0.91, green: 0.93, blue: 0.90, alpha: 1),
        UIColor(red: 0.11, green: 0.15, blue: 0.125, alpha: 1))
    static let accent = adaptive(
        UIColor(red: 0.15, green: 0.34, blue: 0.26, alpha: 1),
        UIColor(red: 0.55, green: 0.76, blue: 0.63, alpha: 1))
    static let beat = Color(red: 0.68, green: 0.23, blue: 0.17)
    static let onAccent = adaptive(.white, UIColor(red: 0.04, green: 0.10, blue: 0.07, alpha: 1))
    static let selection = adaptive(
        UIColor(red: 0.53, green: 0.30, blue: 0.05, alpha: 1),
        UIColor(red: 0.94, green: 0.70, blue: 0.30, alpha: 1))
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// One preference source for Settings and in-context sheets. No attempt data is stored.
@MainActor
final class AppPreferences: ObservableObject {
    @Published var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: "appearance") }
    }
    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: "padHaptics") }
    }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = AppAppearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
        hapticsEnabled = defaults.bool(forKey: "padHaptics")
    }
}

struct EditorSheet<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack {
            ScrollView { content().padding(24) }
                .background(AppTheme.background)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

@MainActor
struct AudioControls: View {
    @ObservedObject var model: PracticeModel
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            volume("Metronome", value: $model.metronomeVolume)
            volume("Rhythm", value: $model.rhythmVolume)
        }
    }
    private func volume(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Slider(value: value, in: 0...1)
                .accessibilityLabel("\(title) volume")
                .accessibilityValue("\(Int(value.wrappedValue * 100)) percent")
        }
    }
}

@MainActor
struct SettingsView: View {
    @ObservedObject var model: PracticeModel
    @ObservedObject var preferences: AppPreferences
    var body: some View {
        Form {
            Section("Audio") { AudioControls(model: model).padding(.vertical, 8) }
                .listRowBackground(AppTheme.surface)
            Section("Appearance") {
                Picker("Appearance", selection: $preferences.appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                }
            }.listRowBackground(AppTheme.surface)
            Section {
                Toggle("Pad haptics", isOn: $preferences.hapticsEnabled)
            } header: { Text("Touch feedback") } footer: {
                Text("A light vibration confirms pad contact, not timing accuracy.")
            }.listRowBackground(AppTheme.surface)
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

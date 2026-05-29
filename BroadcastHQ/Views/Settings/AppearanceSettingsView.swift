import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    
    private let accentOptions: [(String, String, Color)] = [
        ("red", "Valor Red", Color.bhqTint),
        ("blue", "Ocean Blue", Color.bhqBlue),
        ("green", "Emerald", Color.bhqGreen),
        ("purple", "Royal Purple", Color.bhqPurple),
        ("orange", "Amber", Color.bhqOrange),
    ]
    
    var body: some View {
        List {
            // Text Size
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Text Size")
                        Spacer()
                        Text(fontSizeLabel)
                            .foregroundStyle(Color.secondary)
                    }
                    
                    Slider(value: $settings.textSize, in: 0.8...1.3, step: 0.1)
                        .tint(settings.accentColor)
                    
                    HStack {
                        Text("Aa").font(.system(size: 12)).foregroundStyle(Color.secondary)
                        Spacer()
                        Text("Aa").font(.system(size: 20)).foregroundStyle(Color.secondary)
                    }
                    
                    // Live preview
                    Text("This is how your text will look across the app.")
                        .font(.system(size: 15 * settings.textSize))
                        .foregroundStyle(Color.secondary)
                        .padding(.top, 4)
                }
                .padding(.vertical, 4)
            } header: { Text("Text") } footer: { Text("Changes text size across the entire app") }
            
            // Accent Color
            Section {
                HStack(spacing: 12) {
                    ForEach(accentOptions, id: \.0) { option in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                settings.accentColorKey = option.0
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(option.2)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle().stroke(Color.white, lineWidth: settings.accentColorKey == option.0 ? 2 : 0)
                                    )
                                    .shadow(color: settings.accentColorKey == option.0 ? option.2.opacity(0.5) : Color.clear, radius: 6)
                                    .scaleEffect(settings.accentColorKey == option.0 ? 1.1 : 1.0)
                                
                                Text(option.1)
                                    .font(.system(size: 9))
                                    .foregroundStyle(settings.accentColorKey == option.0 ? Color.primary : Color.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
                
                // Preview bar
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(settings.accentColor)
                        .frame(height: 36)
                        .overlay {
                            Text("Accent Preview")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.white)
                        }
                }
                .padding(.vertical, 4)
            } header: { Text("Accent Color") } footer: { Text("Changes tab bar, buttons, and highlights throughout the app") }
            
            // Display Toggles
            Section {
                settingToggle("Live Broadcast Border", icon: "rectangle.dashed", color: Color.bhqTint, isOn: $settings.showLiveBorder)
                settingToggle("Animations", icon: "sparkles", color: Color.bhqPurple, isOn: $settings.animationsEnabled)
                settingToggle("Show Avatars", icon: "person.circle", color: Color.bhqBlue, isOn: $settings.showAvatars)
                settingToggle("Compact Mode", icon: "rectangle.compress.vertical", color: Color.bhqGreen, isOn: $settings.compactMode)
            } header: { Text("Display") } footer: { Text("Compact mode reduces spacing for smaller screens. Disabling animations improves performance on older devices.") }
            
            // Theme
            Section {
                HStack {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 14)).foregroundStyle(Color.white)
                        .frame(width: 28, height: 28).background(Color.bhqPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Text("Theme")
                    Spacer()
                    Text("Dark").foregroundStyle(Color.secondary)
                }
            } header: { Text("Theme") } footer: { Text("Valor.Live is optimized for dark broadcast environments.") }
            
            // Reset
            Section {
                Button {
                    resetToDefaults()
                } label: {
                    HStack {
                        Spacer()
                        Text("Reset to Defaults")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.bhqTint)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .tint(settings.accentColor)
    }
    
    private var fontSizeLabel: String {
        switch settings.textSize {
        case 0.8: return "Small"
        case 0.9: return "Medium"
        case 1.0: return "Default"
        case 1.1: return "Large"
        case 1.2: return "X-Large"
        case 1.3: return "XX-Large"
        default: return "Default"
        }
    }
    
    private func settingToggle(_ label: String, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 14)).foregroundStyle(Color.white)
                    .frame(width: 28, height: 28).background(color).clipShape(RoundedRectangle(cornerRadius: 6))
                Text(label)
            }
        }
        .tint(settings.accentColor)
    }
    
    private func resetToDefaults() {
        withAnimation {
            settings.textSize = 1.0
            settings.accentColorKey = "red"
            settings.showLiveBorder = true
            settings.animationsEnabled = true
            settings.showAvatars = true
            settings.compactMode = false
        }
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
            .environmentObject(AppSettings())
    }
    .preferredColorScheme(.dark)
}


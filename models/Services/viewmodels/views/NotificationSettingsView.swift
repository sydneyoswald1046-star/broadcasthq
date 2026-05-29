import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        List {
            Section {
                toggle("Broadcast Alerts", icon: "antenna.radiowaves.left.and.right", color: Color.bhqTint, isOn: $settings.broadcastAlerts)
                toggle("Segment Changes", icon: "play.rectangle.fill", color: Color.bhqBlue, isOn: $settings.segmentChanges)
                toggle("Equipment Issues", icon: "wrench.and.screwdriver", color: Color.bhqYellow, isOn: $settings.equipmentAlerts)
            } header: { Text("Broadcast") } footer: { Text("Alerts during live broadcasts and equipment status changes") }
            
            Section {
                toggle("Team Messages", icon: "person.3.fill", color: Color.bhqGreen, isOn: $settings.teamMessages)
                toggle("Direct Messages", icon: "message.fill", color: Color.bhqPurple, isOn: $settings.directMessages)
                toggle("Push-to-Talk", icon: "mic.fill", color: Color.bhqOrange, isOn: $settings.pttAlerts)
            } header: { Text("Communication") } footer: { Text("Notifications for team and private messages") }
            
            Section {
                toggle("Member Status Changes", icon: "person.badge.clock", color: Color.secondary, isOn: $settings.memberUpdates)
            } header: { Text("Team") } footer: { Text("When team members come online, go busy, or go offline") }
            
            Section {
                toggle("Sound", icon: "speaker.wave.2.fill", color: Color.bhqBlue, isOn: $settings.soundEnabled)
                toggle("Vibration", icon: "iphone.radiowaves.left.and.right", color: Color.bhqGreen, isOn: $settings.vibrationEnabled)
            } header: { Text("Alerts") }
            
            Section {
                let enabledCount = [
                    settings.broadcastAlerts, settings.segmentChanges, settings.equipmentAlerts,
                    settings.teamMessages, settings.directMessages, settings.pttAlerts,
                    settings.memberUpdates
                ].filter { $0 }.count
                
                HStack {
                    Text("Active Notifications").foregroundStyle(Color.secondary)
                    Spacer()
                    Text("\(enabledCount) of 7")
                        .foregroundStyle(enabledCount > 0 ? settings.accentColor : Color.secondary)
                        .fontWeight(.medium)
                }
            }
            
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
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .tint(settings.accentColor)
    }
    
    private func toggle(_ label: String, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
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
            settings.broadcastAlerts = true
            settings.segmentChanges = true
            settings.teamMessages = true
            settings.directMessages = true
            settings.equipmentAlerts = true
            settings.memberUpdates = false
            settings.pttAlerts = true
            settings.soundEnabled = true
            settings.vibrationEnabled = true
        }
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
            .environmentObject(AppSettings())
    }
    .preferredColorScheme(.dark)
}


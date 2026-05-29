import SwiftUI

struct EventSchedulerView: View {
    @EnvironmentObject var authState: AuthState
    @State private var showAddEvent: Bool = false
    @State private var newTitle: String = ""
    @State private var newDate: Date = Date().addingTimeInterval(3600)
    @State private var showRemoveConfirm: Bool = false
    @State private var eventToRemove: BroadcastEvent?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Next up card
                if let next = authState.nextEvent {
                    nextEventCard(event: next)
                }
                
                // Add event button
                Button { showAddEvent = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 16))
                        Text("Schedule New Event").font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.bhqBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                
                // Upcoming events
                if !authState.scheduledEvents.isEmpty {
                    eventsList
                } else {
                    emptyState
                }
            }
            .padding(.vertical)
        }
        .background(Color.bhqBackground)
        .navigationTitle("Event Schedule")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showAddEvent) {
            addEventSheet
        }
        .alert("Remove Event", isPresented: $showRemoveConfirm) {
            Button("Remove", role: .destructive) {
                if let event = eventToRemove {
                    withAnimation { authState.removeEvent(event.id) }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let event = eventToRemove {
                Text("Remove \"\(event.title)\" from the schedule?")
            }
        }
    }
    
    // MARK: - Next Event Card
    private func nextEventCard(event: BroadcastEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.bhqYellow)
                Text("NEXT BROADCAST")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.bhqYellow)
                    .tracking(0.5)
            }
            
            Text(event.title)
                .font(.system(size: 20, weight: .bold))
            
            Text(event.timeString)
                .font(.system(size: 15))
                .foregroundStyle(Color.secondary)
            
            // Countdown
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let remaining = event.date.timeIntervalSinceNow
                if remaining > 0 {
                    HStack(spacing: 4) {
                        countdownUnit(value: Int(remaining) / 3600, label: "hr")
                        Text(":").foregroundStyle(Color.secondary)
                        countdownUnit(value: (Int(remaining) % 3600) / 60, label: "min")
                        Text(":").foregroundStyle(Color.secondary)
                        countdownUnit(value: Int(remaining) % 60, label: "sec")
                    }
                    .padding(.top, 4)
                } else {
                    Text("Event time reached!")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.bhqGreen)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bhqYellow.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.bhqYellow.opacity(0.2), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
    
    private func countdownUnit(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(String(format: "%02d", value))")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.primary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.secondary)
        }
    }
    
    // MARK: - Events List
    private var eventsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Scheduled Events")
            
            VStack(spacing: 0) {
                ForEach(Array(authState.scheduledEvents.enumerated()), id: \.element.id) { index, event in
                    HStack(spacing: 12) {
                        // Date circle
                        VStack(spacing: 1) {
                            Text(dayString(event.date))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.bhqTint)
                                .textCase(.uppercase)
                            Text(dateNumString(event.date))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.primary)
                        }
                        .frame(width: 44, height: 44)
                        .background(Color(.systemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.system(size: 15, weight: .semibold))
                            Text(event.timeString)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            eventToRemove = event
                            showRemoveConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.bhqTint)
                                .padding(8)
                                .background(Color.bhqTint.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    
                    if index < authState.scheduledEvents.count - 1 {
                        Divider().padding(.leading, 72)
                    }
                }
            }
            .background(Color.bhqCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
    
    private func dayString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: date)
    }
    
    private func dateNumString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: date)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 36))
                .foregroundStyle(Color.secondary.opacity(0.4))
            Text("No Events Scheduled")
                .font(.system(size: 18, weight: .semibold))
            Text("Schedule your next broadcast to send automatic reminders to the team.")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Add Event Sheet
    private var addEventSheet: some View {
        NavigationStack {
            List {
                Section {
                    TextField("e.g. Sunday Service, Game Day", text: $newTitle)
                } header: { Text("Event Title") }
                
                Section {
                    DatePicker("Date & Time", selection: $newDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                        .tint(Color.bhqBlue)
                } header: { Text("When") }
                
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.fill").foregroundStyle(Color.bhqYellow)
                        Text("A reminder will be sent to all team members 5 minutes before the event.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            .navigationTitle("Schedule Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showAddEvent = false }.foregroundStyle(Color.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schedule") {
                        authState.scheduleEvent(title: newTitle, date: newDate)
                        newTitle = ""
                        newDate = Date().addingTimeInterval(3600)
                        showAddEvent = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(!newTitle.isEmpty ? Color.bhqBlue : Color.secondary)
                    .disabled(newTitle.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        EventSchedulerView()
            .environmentObject(AuthState())
    }
    .preferredColorScheme(.dark)
}


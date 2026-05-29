import SwiftUI

struct RundownView: View {
    @Binding var segments: [Segment]
    let currentUser: AppUser
    @EnvironmentObject var authState: AuthState
    @State private var expandedId: String?
    @State private var editingSegment: Segment?
    @State private var showEditSheet: Bool = false
    @State private var showSaveSheet: Bool = false
    @State private var showLoadSheet: Bool = false
    @State private var showAddSegment: Bool = false
    @State private var showClearConfirm: Bool = false
    @State private var savedRundowns: [FirestoreService.SavedRundown] = []
    @State private var isLoadingRundowns: Bool = false
    
    private var canEdit: Bool { currentUser.role == .admin || currentUser.role == .teamLead }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if canEdit { rundownToolbar; advanceButton }
                HStack {
                    SectionHeader(title: "\(segments.count) segment\(segments.count == 1 ? "" : "s")")
                    Spacer()
                    Text("Total: \(Segment.formatTime(segments.reduce(0) { $0 + $1.duration }))")
                        .font(.system(size: 13)).foregroundStyle(Color.secondary.opacity(0.7)).padding(.trailing, 16)
                }
                if segments.isEmpty { emptyState } else { segmentList }
                if canEdit { addSegmentButton }
                Spacer().frame(height: 80)
            }.padding(.vertical)
        }
        .background(Color.bhqBackground)
        .sheet(isPresented: $showEditSheet) {
            if let seg = editingSegment, let index = segments.firstIndex(where: { $0.id == seg.id }) {
                SegmentEditSheet(segment: $segments[index], onDismiss: { showEditSheet = false; editingSegment = nil; authState.syncSegments() })
            }
        }
        .sheet(isPresented: $showSaveSheet) { SaveRundownSheet(segments: segments, onSave: { name in saveCurrentRundown(name: name) }) }
        .sheet(isPresented: $showLoadSheet) { LoadRundownSheet(rundowns: $savedRundowns, isLoading: isLoadingRundowns, onLoad: { r in loadRundown(r) }, onDelete: { r in deleteRundown(r) }) }
        .sheet(isPresented: $showAddSegment) { AddSegmentSheet(onAdd: { seg in var s = seg; s.order = segments.count; segments.append(s); authState.syncSegments() }) }
        .alert("New Rundown", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) { withAnimation { segments.removeAll() }; authState.syncSegments() }
        } message: { Text("This will clear all current segments. Save first if you want to keep them.") }
    }
    
    private var rundownToolbar: some View {
        HStack(spacing: 8) {
            Button { showSaveSheet = true } label: {
                HStack(spacing: 5) { Image(systemName: "square.and.arrow.down").font(.system(size: 12, weight: .semibold)); Text("Save").font(.system(size: 13, weight: .semibold)) }
                .foregroundStyle(Color.bhqBlue).padding(.horizontal, 12).padding(.vertical, 8).background(Color.bhqBlue.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10))
            }.disabled(segments.isEmpty)
            Button { fetchRundowns(); showLoadSheet = true } label: {
                HStack(spacing: 5) { Image(systemName: "folder").font(.system(size: 12, weight: .semibold)); Text("Saved").font(.system(size: 13, weight: .semibold)) }
                .foregroundStyle(Color.bhqGreen).padding(.horizontal, 12).padding(.vertical, 8).background(Color.bhqGreen.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            Button { showClearConfirm = true } label: {
                HStack(spacing: 5) { Image(systemName: "plus").font(.system(size: 12, weight: .semibold)); Text("New").font(.system(size: 13, weight: .semibold)) }
                .foregroundStyle(Color.bhqYellow).padding(.horizontal, 12).padding(.vertical, 8).background(Color.bhqYellow.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            Spacer()
        }.padding(.horizontal, 16)
    }
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.bullet.rectangle").font(.system(size: 36, weight: .light)).foregroundStyle(Color.secondary.opacity(0.2))
            Text("No Segments").font(.system(size: 17, weight: .semibold))
            Text("Add segments or load a saved rundown.").font(.system(size: 13)).foregroundStyle(Color.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 40).background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 14)).padding(.horizontal)
    }
    
    private var addSegmentButton: some View {
        Button { showAddSegment = true } label: {
            HStack(spacing: 8) { Image(systemName: "plus.circle.fill").font(.system(size: 16)); Text("Add Segment").font(.system(size: 14, weight: .medium)) }
            .foregroundStyle(Color.bhqBlue).frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.bhqBlue.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
        }.padding(.horizontal)
    }
    
    private var advanceButton: some View {
        Button { advanceSegment() } label: {
            HStack(spacing: 8) { Image(systemName: "forward.fill").font(.system(size: 12)); Text("Next Segment").font(.system(size: 15, weight: .semibold)) }
            .foregroundStyle(Color.white).frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(segments.contains { $0.status == .live } ? Color.bhqTint : Color.secondary.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius: 12))
        }.disabled(!segments.contains { $0.status == .live }).padding(.horizontal)
    }
    
    private var segmentList: some View {
        VStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, seg in
                segmentRow(seg: seg, index: index)
                if index < segments.count - 1 { Divider().padding(.leading, 56) }
            }
        }.background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
    }
    
    private func segmentRow(seg: Segment, index: Int) -> some View {
        let isExpanded = expandedId == seg.id
        return VStack(spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { expandedId = isExpanded ? nil : seg.id } } label: {
                HStack(spacing: 12) {
                    segmentNumber(seg: seg, index: index)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(seg.title).font(.body).fontWeight(seg.status == .live ? .semibold : .regular).foregroundStyle(seg.status == .completed ? Color.secondary : Color.primary)
                        Text("\(seg.assignedRole) · \(seg.formattedDuration)").font(.subheadline).foregroundStyle(Color.secondary)
                    }
                    Spacer()
                    if seg.status == .live {
                        Text("LIVE").font(.system(size: 11, weight: .semibold)).tracking(0.5).foregroundStyle(Color.bhqTint)
                            .padding(.horizontal, 8).padding(.vertical, 3).background(Color.bhqTint.opacity(0.18)).clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                }.padding(.horizontal, 16).padding(.vertical, 12).background(seg.status == .live ? Color.bhqTint.opacity(0.04) : Color.clear).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if isExpanded { expandedDetail(seg: seg) }
        }
    }
    
    private func segmentNumber(seg: Segment, index: Int) -> some View {
        let bg: Color = seg.status == .live ? Color.bhqTint.opacity(0.18) : seg.status == .completed ? Color.bhqGreen.opacity(0.15) : Color(.systemFill)
        let fg: Color = seg.status == .live ? Color.bhqTint : seg.status == .completed ? Color.bhqGreen : Color.secondary
        return ZStack { Circle().fill(bg).frame(width: 28, height: 28); Text(seg.status == .completed ? "✓" : "\(index + 1)").font(.system(size: 12, weight: .semibold)).foregroundStyle(fg) }
    }
    
    private func expandedDetail(seg: Segment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(seg.notes).font(.subheadline).foregroundStyle(Color.secondary)
            if !seg.description.isEmpty { Text(seg.description).font(.system(size: 13)).foregroundStyle(Color.secondary.opacity(0.8)).lineSpacing(2) }
            if canEdit {
                HStack(spacing: 8) {
                    if seg.status != .live {
                        Button { goLive(seg.id) } label: { Text("Go Live").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.bhqTint).padding(.horizontal, 14).padding(.vertical, 7).background(Color.bhqTint.opacity(0.18)).clipShape(RoundedRectangle(cornerRadius: 8)) }
                    }
                    Button { editingSegment = seg; showEditSheet = true } label: { Text("Edit").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.bhqBlue).padding(.horizontal, 14).padding(.vertical, 7).background(Color.bhqBlue.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 8)) }
                    Button { deleteSegment(seg.id) } label: { Image(systemName: "trash").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.bhqTint).padding(7).background(Color.bhqTint.opacity(0.1)).clipShape(Circle()) }
                }.padding(.top, 2)
            }
        }.padding(.leading, 56).padding(.trailing, 16).padding(.bottom, 12).transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private func advanceSegment() {
        guard let i = segments.firstIndex(where: { $0.status == .live }) else { return }
        withAnimation { segments[i].status = .completed; if i + 1 < segments.count { segments[i + 1].status = .live } }
        authState.syncSegments()
    }
    private func goLive(_ id: String) {
        withAnimation { if let c = segments.firstIndex(where: { $0.status == .live }) { segments[c].status = .upcoming }; if let t = segments.firstIndex(where: { $0.id == id }) { segments[t].status = .live } }
        authState.syncSegments()
    }
    private func deleteSegment(_ id: String) {
        withAnimation { segments.removeAll { $0.id == id }; for i in segments.indices { segments[i].order = i } }
        authState.syncSegments()
    }
    private func saveCurrentRundown(name: String) {
        Task { try? await FirestoreService.shared.saveRundownTemplate(name: name, segments: segments, createdBy: currentUser.displayName); await MainActor.run { showSaveSheet = false } }
    }
    private func fetchRundowns() {
        isLoadingRundowns = true
        Task { let r = (try? await FirestoreService.shared.fetchSavedRundowns()) ?? []; await MainActor.run { savedRundowns = r; isLoadingRundowns = false } }
    }
    private func loadRundown(_ r: FirestoreService.SavedRundown) {
        Task { let s = (try? await FirestoreService.shared.loadRundownTemplate(rundownId: r.id)) ?? []; await MainActor.run { withAnimation { segments = s }; authState.syncSegments(); showLoadSheet = false } }
    }
    private func deleteRundown(_ r: FirestoreService.SavedRundown) {
        Task { try? await FirestoreService.shared.deleteRundownTemplate(rundownId: r.id); fetchRundowns() }
    }
}

struct SaveRundownSheet: View {
    let segments: [Segment]; let onSave: (String) -> Void
    @State private var name: String = ""; @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) { Image(systemName: "square.and.arrow.down").font(.system(size: 32)).foregroundStyle(Color.bhqBlue); Text("Save Rundown").font(.system(size: 20, weight: .bold)); Text("\(segments.count) segments · \(Segment.formatTime(segments.reduce(0) { $0 + $1.duration }))").font(.system(size: 13)).foregroundStyle(Color.secondary) }.padding(.top, 20)
                TextField("e.g. Sunday Service, Youth Night", text: $name).font(.system(size: 16)).padding(14).background(Color(.systemFill).opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 20)
                Spacer()
                Button { onSave(name.isEmpty ? "Untitled" : name) } label: { Text("Save Rundown").font(.system(size: 16, weight: .bold)).foregroundStyle(Color.white).frame(maxWidth: .infinity).padding(.vertical, 16).background(name.isEmpty ? Color.secondary.opacity(0.3) : Color.bhqBlue).clipShape(RoundedRectangle(cornerRadius: 14)) }.disabled(name.isEmpty).padding(.horizontal, 20).padding(.bottom, 20)
            }.navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() }.foregroundStyle(Color.secondary) } }
        }
    }
}

struct LoadRundownSheet: View {
    @Binding var rundowns: [FirestoreService.SavedRundown]; let isLoading: Bool; let onLoad: (FirestoreService.SavedRundown) -> Void; let onDelete: (FirestoreService.SavedRundown) -> Void
    @State private var showDeleteConfirm: Bool = false; @State private var deletingRundown: FirestoreService.SavedRundown?; @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            Group {
                if isLoading { ProgressView().padding(.top, 40) }
                else if rundowns.isEmpty { VStack(spacing: 14) { Spacer().frame(height: 40); Image(systemName: "folder").font(.system(size: 36, weight: .light)).foregroundStyle(Color.secondary.opacity(0.2)); Text("No Saved Rundowns").font(.system(size: 17, weight: .semibold)); Text("Save your current rundown first.").font(.system(size: 13)).foregroundStyle(Color.secondary) } }
                else {
                    List {
                        ForEach(rundowns) { r in
                            Button { onLoad(r) } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "doc.text.fill").font(.system(size: 16)).foregroundStyle(Color.bhqBlue).frame(width: 36, height: 36).background(Color.bhqBlue.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 8))
                                    VStack(alignment: .leading, spacing: 3) { Text(r.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.primary); HStack(spacing: 4) { Text("\(r.segmentCount) segments"); Text("·"); Text(r.createdBy); Text("·"); Text(r.createdAt, style: .relative) }.font(.system(size: 12)).foregroundStyle(Color.secondary) }
                                    Spacer(); Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.secondary.opacity(0.3))
                                }
                            }.swipeActions(edge: .trailing) { Button(role: .destructive) { deletingRundown = r; showDeleteConfirm = true } label: { Label("Delete", systemImage: "trash") } }
                        }
                    }
                }
            }
            .navigationTitle("Saved Rundowns").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.foregroundStyle(Color.secondary) } }
            .alert("Delete Rundown", isPresented: $showDeleteConfirm) { Button("Cancel", role: .cancel) { deletingRundown = nil }; Button("Delete", role: .destructive) { if let r = deletingRundown { onDelete(r); deletingRundown = nil } } } message: { Text("Delete \"\(deletingRundown?.name ?? "")\"?") }
        }
    }
}

struct AddSegmentSheet: View {
    let onAdd: (Segment) -> Void
    @State private var title = ""; @State private var role = "Camera 1"; @State private var notes = ""; @State private var desc = ""; @State private var minutes = 5; @State private var seconds = 0; @Environment(\.dismiss) var dismiss
    private let roles = ["Camera 1","Camera 2","Camera 3","Audio","Graphics","Director","Tech Director","Projection","Lights","Worship Leader"]
    var body: some View {
        NavigationStack {
            List {
                Section { TextField("Segment Title", text: $title) } header: { Text("Title") }
                Section { Picker("Role", selection: $role) { ForEach(roles, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu) } header: { Text("Assigned Role") }
                Section { HStack(spacing: 16) { HStack(spacing: 4) { Picker("Min", selection: $minutes) { ForEach(0..<121) { Text("\($0)").tag($0) } }.pickerStyle(.wheel).frame(width: 80, height: 120).clipped(); Text("min").font(.subheadline).foregroundStyle(Color.secondary) }; HStack(spacing: 4) { Picker("Sec", selection: $seconds) { ForEach(0..<60) { Text("\($0)").tag($0) } }.pickerStyle(.wheel).frame(width: 80, height: 120).clipped(); Text("sec").font(.subheadline).foregroundStyle(Color.secondary) } }.frame(maxWidth: .infinity, alignment: .center) } header: { Text("Duration") }
                Section { TextField("Brief notes", text: $notes) } header: { Text("Notes") }
                Section { TextEditor(text: $desc).frame(minHeight: 80) } header: { Text("Description") }
            }.navigationTitle("Add Segment").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() }.foregroundStyle(Color.secondary) }; ToolbarItem(placement: .topBarTrailing) { Button("Add") { onAdd(Segment(id: UUID().uuidString, order: 0, title: title, duration: (minutes*60)+seconds, assignedRole: role, status: .upcoming, notes: notes, description: desc)); dismiss() }.fontWeight(.semibold).foregroundStyle(!title.isEmpty ? Color.bhqBlue : Color.secondary).disabled(title.isEmpty) } }
        }
    }
}

struct SegmentEditSheet: View {
    @Binding var segment: Segment; let onDismiss: () -> Void
    @State private var t = ""; @State private var r = ""; @State private var n = ""; @State private var d = ""; @State private var m = 0; @State private var s = 0
    private let roles = ["Camera 1","Camera 2","Camera 3","Audio","Graphics","Director","Tech Director","Projection","Lights","Worship Leader"]
    var body: some View {
        NavigationStack {
            List {
                Section { TextField("Title", text: $t) } header: { Text("Title") }
                Section { Picker("Role", selection: $r) { ForEach(roles, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu) } header: { Text("Role") }
                Section { HStack(spacing: 16) { HStack(spacing: 4) { Picker("Min", selection: $m) { ForEach(0..<121) { Text("\($0)").tag($0) } }.pickerStyle(.wheel).frame(width: 80, height: 120).clipped(); Text("min").font(.subheadline).foregroundStyle(Color.secondary) }; HStack(spacing: 4) { Picker("Sec", selection: $s) { ForEach(0..<60) { Text("\($0)").tag($0) } }.pickerStyle(.wheel).frame(width: 80, height: 120).clipped(); Text("sec").font(.subheadline).foregroundStyle(Color.secondary) } }.frame(maxWidth: .infinity, alignment: .center) } header: { Text("Duration") }
                Section { TextField("Notes", text: $n) } header: { Text("Notes") }
                Section { TextEditor(text: $d).frame(minHeight: 120) } header: { Text("Description") }
            }.navigationTitle("Edit Segment").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { onDismiss() }.foregroundStyle(Color.secondary) }; ToolbarItem(placement: .topBarTrailing) { Button("Save") { segment.title = t; segment.assignedRole = r; segment.notes = n; segment.description = d; segment.duration = (m*60)+s; onDismiss() }.fontWeight(.semibold).foregroundStyle(Color.bhqBlue) } }
            .onAppear { t = segment.title; r = segment.assignedRole; n = segment.notes; d = segment.description; m = segment.duration/60; s = segment.duration%60 }
        }
    }
}

#Preview { NavigationStack { RundownView(segments: .constant(Segment.samples), currentUser: AppUser.samples[0]).navigationTitle("Rundown").environmentObject(AuthState()) }.preferredColorScheme(.dark) }

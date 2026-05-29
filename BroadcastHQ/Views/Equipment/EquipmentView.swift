import SwiftUI

struct EquipmentView: View {
    @EnvironmentObject var authState: AuthState
    @State private var filter: String = "all"
    @State private var showAddGear: Bool = false
    @State private var showEditGear: Bool = false
    @State private var editingItem: Equipment?
    @State private var newName: String = ""
    @State private var newType: String = "Camera"
    @State private var editName: String = ""
    @State private var editType: String = "Camera"
    @State private var showDeleteConfirm: Bool = false
    @State private var deletingItem: Equipment?
    
    private var gear: [Equipment] { authState.equipment }
    
    private var filtered: [Equipment] {
        switch filter {
        case "available": return gear.filter { $0.status == "available" }
        case "out": return gear.filter { $0.status == "checked-out" }
        case "issues": return gear.filter { $0.hasIssue }
        default: return gear
        }
    }
    
    private var availableCount: Int { gear.filter { $0.status == "available" && !$0.hasIssue }.count }
    private var checkedOutCount: Int { gear.filter { $0.isCheckedOut }.count }
    private var flaggedCount: Int { gear.filter { $0.hasIssue }.count }
    private var isAdmin: Bool { authState.currentUser?.role == .admin || authState.currentUser?.role == .teamLead }
    private var userName: String { authState.currentUser?.displayName ?? "Unknown" }
    
    private let gearTypes = ["Camera", "Microphone", "Wireless Mic", "Switcher", "Computer", "TX System", "Shotgun Mic", "Monitor", "Tripod", "Cable", "Light", "Other"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statsRow
                filterPills
                
                if gear.isEmpty {
                    emptyState
                } else {
                    gearList
                }
                
                if isAdmin {
                    addGearButton
                }
            }
            .padding(.vertical)
        }
        .background(Color.bhqBackground)
        .sheet(isPresented: $showAddGear) {
            addGearSheet
        }
        .sheet(isPresented: $showEditGear) {
            editGearSheet
        }
        .alert("Delete Equipment", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { deletingItem = nil }
            Button("Delete", role: .destructive) {
                if let item = deletingItem {
                    Task { try? await FirestoreService.shared.deleteEquipment(item.id) }
                    deletingItem = nil
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(deletingItem?.name ?? "")\"? This cannot be undone.")
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wrench.and.screwdriver").font(.system(size: 36)).foregroundStyle(Color.secondary.opacity(0.4))
            Text("No Equipment").font(.system(size: 18, weight: .semibold))
            Text("Add gear to track your team's equipment.").font(.subheadline).foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
    }
    
    // MARK: - Stats
    private var statsRow: some View {
        HStack(spacing: 10) {
            StatCard(value: "\(availableCount)", label: "Available", color: .bhqGreen)
            StatCard(value: "\(checkedOutCount)", label: "Checked Out", color: .bhqBlue)
            StatCard(value: "\(flaggedCount)", label: "Flagged", color: .bhqTint)
        }.padding(.horizontal)
    }
    
    // MARK: - Filters
    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterChip("All", id: "all"); filterChip("Available", id: "available")
                filterChip("Checked Out", id: "out"); filterChip("⚠ Flagged", id: "issues")
            }.padding(.horizontal, 16)
        }
    }
    
    private func filterChip(_ label: String, id: String) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.15)) { filter = id } } label: {
            Text(label).font(.system(size: 13, weight: .medium))
                .foregroundStyle(filter == id ? .black : .secondary)
                .padding(.horizontal, 13).padding(.vertical, 7)
                .background(filter == id ? Color.white : Color(.systemFill)).clipShape(Capsule())
        }
    }
    
    // MARK: - Gear List
    private var gearList: some View {
        VStack(spacing: 0) {
            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).font(.body)
                            HStack(spacing: 4) {
                                Text(item.type).font(.subheadline).foregroundStyle(.secondary)
                                if let assignee = item.assignedTo {
                                    Text("·").foregroundStyle(.tertiary)
                                    Text(assignee).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer()
                        HStack(spacing: 5) {
                            if item.hasIssue {
                                Text(item.condition.rawValue.uppercased()).font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(item.condition == .missing ? Color.bhqYellow : Color.bhqTint)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background((item.condition == .missing ? Color.bhqYellow : Color.bhqTint).opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                            Text(item.isCheckedOut ? "Out" : "Available").font(.system(size: 11, weight: .medium))
                                .foregroundStyle(item.isCheckedOut ? Color.bhqBlue : Color.bhqGreen)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background((item.isCheckedOut ? Color.bhqBlue : Color.bhqGreen).opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Button {
                            withAnimation {
                                if item.isCheckedOut { authState.checkInEquipment(id: item.id) }
                                else { authState.checkOutEquipment(id: item.id, userName: userName) }
                            }
                        } label: {
                            Text(item.isCheckedOut ? "Check In" : "Check Out").font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(item.isCheckedOut ? Color.bhqBlue : Color.bhqGreen)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background((item.isCheckedOut ? Color.bhqBlue : Color.bhqGreen).opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        Button {
                            withAnimation {
                                authState.flagEquipment(id: item.id, condition: item.hasIssue ? .good : .damaged)
                            }
                        } label: {
                            Text(item.hasIssue ? "Clear Flag" : "Flag Issue").font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.bhqYellow)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(Color(.systemFill)).clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        Spacer()
                        
                        // Admin: Edit & Delete
                        if isAdmin {
                            Button {
                                editingItem = item
                                editName = item.name
                                editType = item.type
                                showEditGear = true
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.secondary)
                                    .padding(7)
                                    .background(Color(.systemFill))
                                    .clipShape(Circle())
                            }
                            
                            Button {
                                deletingItem = item
                                showDeleteConfirm = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.bhqTint)
                                    .padding(7)
                                    .background(Color.bhqTint.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                if index < filtered.count - 1 { Divider().padding(.leading, 16) }
            }
        }
        .background(Color.bhqCard).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal)
    }
    
    // MARK: - Add Gear
    private var addGearButton: some View {
        Button { showAddGear = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").font(.system(size: 16))
                Text("Add Equipment").font(.system(size: 14, weight: .medium))
            }.foregroundStyle(Color.bhqBlue).frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Color.bhqBlue.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
        }.padding(.horizontal)
    }
    
    private var addGearSheet: some View {
        NavigationStack {
            List {
                Section { TextField("e.g. Sony A7S III", text: $newName) } header: { Text("Equipment Name") }
                Section {
                    Picker("Type", selection: $newType) {
                        ForEach(gearTypes, id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu)
                } header: { Text("Type") }
            }
            .navigationTitle("Add Equipment").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { showAddGear = false }.foregroundStyle(Color.secondary) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let item = Equipment(id: UUID().uuidString, name: newName, type: newType, condition: .good, status: "available", assignedTo: nil)
                        Task { try? await FirestoreService.shared.saveEquipment(item) }
                        newName = ""; showAddGear = false
                    }.fontWeight(.semibold).foregroundStyle(!newName.isEmpty ? Color.bhqBlue : Color.secondary).disabled(newName.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Edit Gear
    private var editGearSheet: some View {
        NavigationStack {
            List {
                Section { TextField("Equipment name", text: $editName) } header: { Text("Equipment Name") }
                Section {
                    Picker("Type", selection: $editType) {
                        ForEach(gearTypes, id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu)
                } header: { Text("Type") }
            }
            .navigationTitle("Edit Equipment").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showEditGear = false; editingItem = nil }.foregroundStyle(Color.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if var item = editingItem {
                            item.name = editName
                            item.type = editType
                            Task { try? await FirestoreService.shared.saveEquipment(item) }
                        }
                        showEditGear = false; editingItem = nil
                    }.fontWeight(.semibold).foregroundStyle(!editName.isEmpty ? Color.bhqBlue : Color.secondary).disabled(editName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { EquipmentView().navigationTitle("Gear").environmentObject(AuthState()) }.preferredColorScheme(.dark)
}

import Foundation

enum EquipmentCondition: String, Codable, CaseIterable {
    case good, damaged, missing
}

struct Equipment: Identifiable, Codable {
    var id: String
    var name: String
    var type: String
    var condition: EquipmentCondition
    var status: String // "available" or "checked-out"
    var assignedTo: String?
    
    var isCheckedOut: Bool { status == "checked-out" }
    var hasIssue: Bool { condition != .good }
}

// MARK: - Sample Data
extension Equipment {
    static let samples: [Equipment] = [
        Equipment(id: "1", name: "Sony A7S III", type: "Camera", condition: .good, status: "checked-out", assignedTo: "Sarah Kim"),
        Equipment(id: "2", name: "ATEM Mini Pro", type: "Switcher", condition: .good, status: "checked-out", assignedTo: "Maria Santos"),
        Equipment(id: "3", name: "Sennheiser EW 100", type: "Wireless Mic", condition: .good, status: "checked-out", assignedTo: "Lisa Okafor"),
        Equipment(id: "4", name: "Shure SM7B", type: "Microphone", condition: .damaged, status: "checked-out", assignedTo: "Priya Patel"),
        Equipment(id: "5", name: "Canon C70", type: "Camera", condition: .good, status: "available", assignedTo: nil),
        Equipment(id: "6", name: "Hollyland Mars 300", type: "TX System", condition: .good, status: "checked-out", assignedTo: "Andre Williams"),
        Equipment(id: "7", name: "MacBook Pro 16\"", type: "Computer", condition: .good, status: "checked-out", assignedTo: "James Wright"),
        Equipment(id: "8", name: "Rode NTG5", type: "Shotgun Mic", condition: .missing, status: "available", assignedTo: nil),
    ]
}


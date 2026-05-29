import Foundation
import FirebaseFirestore

class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()
    
    var orgCode: String = ""
    
    private func orgRef() -> DocumentReference {
        db.collection("organizations").document(orgCode)
    }
    
    // MARK: - Organization
    
    struct OrgInfo: Identifiable {
        let id: String  // org code
        let name: String
        let adminName: String
        let memberCount: Int
    }
    
    func createOrganization(name: String, code: String, adminId: String) async throws {
        try await db.collection("organizations").document(code).setData([
            "name": name, "code": code, "adminId": adminId, "createdAt": Timestamp(date: Date()),
        ])
    }
    
    func organizationExists(code: String) async throws -> Bool {
        let doc = try await db.collection("organizations").document(code).getDocument()
        return doc.exists
    }
    
    func fetchOrganizationName(code: String) async throws -> String? {
        let doc = try await db.collection("organizations").document(code).getDocument()
        return doc.data()?["name"] as? String
    }
    
    func fetchAllOrganizations() async throws -> [OrgInfo] {
        let snapshot = try await db.collection("organizations").getDocuments()
        var orgs: [OrgInfo] = []
        
        for doc in snapshot.documents {
            let data = doc.data()
            let code = doc.documentID
            let name = data["name"] as? String ?? "Unknown Team"
            
            // Get admin name and member count
            let usersSnapshot = try await db.collection("organizations").document(code).collection("users").getDocuments()
            let memberCount = usersSnapshot.documents.count
            let adminDoc = usersSnapshot.documents.first { ($0.data()["role"] as? String) == "admin" }
            let adminFirst = adminDoc?.data()["firstName"] as? String ?? ""
            let adminLast = adminDoc?.data()["lastName"] as? String ?? ""
            let adminName = adminFirst.isEmpty ? "No admin" : "\(adminFirst) \(adminLast)"
            
            orgs.append(OrgInfo(id: code, name: name, adminName: adminName, memberCount: memberCount))
        }
        
        return orgs.sorted { $0.name < $1.name }
    }
    
    func fetchAdminForOrg(code: String) async throws -> StoredAccount? {
        let snapshot = try await db.collection("organizations").document(code).collection("users")
            .whereField("role", isEqualTo: "admin").limit(to: 1).getDocuments()
        
        guard let doc = snapshot.documents.first else { return nil }
        let data = doc.data()
        
        guard let firstName = data["firstName"] as? String,
              let lastName = data["lastName"] as? String,
              let email = data["email"] as? String,
              let phone = data["phone"] as? String,
              let pin = data["pin"] as? String,
              let position = data["position"] as? String,
              let team = data["team"] as? String
        else { return nil }
        
        let joinedDate = (data["joinedDate"] as? Timestamp)?.dateValue() ?? Date()
        return StoredAccount(id: doc.documentID, firstName: firstName, lastName: lastName,
            email: email, phone: phone, pin: pin, role: .admin, position: position,
            team: team, isApproved: true, joinedDate: joinedDate, presence: data["presence"] as? String ?? "offline", lastSeen: (data["lastSeen"] as? Timestamp)?.dateValue())
    }
    
    func generateUniqueCode() async throws -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ"
        let numbers = "23456789"
        for _ in 0..<10 {
            var code = ""
            for _ in 0..<3 { code += String(letters.randomElement()!) }
            for _ in 0..<3 { code += String(numbers.randomElement()!) }
            let exists = try await organizationExists(code: code)
            if !exists { return code }
        }
        return UUID().uuidString.prefix(6).uppercased()
    }
    
    // MARK: - Global PIN Lookup (searches ALL orgs)
    
    struct GlobalPinResult {
        let account: StoredAccount
        let orgCode: String
        let orgName: String
    }
    
    func globalPinLookup(pin: String) async throws -> GlobalPinResult? {
        // Fallback: check each org for this PIN
        let orgsSnapshot = try await db.collection("organizations").getDocuments()
        for orgDoc in orgsSnapshot.documents {
            let code = orgDoc.documentID
            let usersSnapshot = try await db.collection("organizations").document(code).collection("users")
                .whereField("pin", isEqualTo: pin).limit(to: 1).getDocuments()
            
            if let userDoc = usersSnapshot.documents.first {
                let data = userDoc.data()
                guard let firstName = data["firstName"] as? String,
                      let lastName = data["lastName"] as? String,
                      let email = data["email"] as? String,
                      let phone = data["phone"] as? String,
                      let roleStr = data["role"] as? String,
                      let role = UserRole(rawValue: roleStr),
                      let position = data["position"] as? String,
                      let team = data["team"] as? String,
                      let isApproved = data["isApproved"] as? Bool
                else { continue }
                
                let joinedDate = (data["joinedDate"] as? Timestamp)?.dateValue() ?? Date()
                let account = StoredAccount(id: userDoc.documentID, firstName: firstName, lastName: lastName,
                    email: email, phone: phone, pin: pin, role: role, position: position,
                    team: team, isApproved: isApproved, joinedDate: joinedDate, presence: data["presence"] as? String ?? "offline", lastSeen: (data["lastSeen"] as? Timestamp)?.dateValue())
                let orgName = orgDoc.data()["name"] as? String ?? ""
                return GlobalPinResult(account: account, orgCode: code, orgName: orgName)
            }
        }
        return nil
    }
    
    // Email + PIN lookup — find by email first, then verify PIN
    func emailPinLookup(email: String, pin: String) async throws -> GlobalPinResult? {
        let orgsSnapshot = try await db.collection("organizations").getDocuments()
        for orgDoc in orgsSnapshot.documents {
            let code = orgDoc.documentID
            let usersSnapshot = try await db.collection("organizations").document(code).collection("users")
                .whereField("email", isEqualTo: email).limit(to: 1).getDocuments()
            
            if let userDoc = usersSnapshot.documents.first {
                let data = userDoc.data()
                guard let storedPin = data["pin"] as? String, storedPin == pin else {
                    // Email found but wrong PIN
                    return nil
                }
                
                guard let firstName = data["firstName"] as? String,
                      let lastName = data["lastName"] as? String,
                      let phone = data["phone"] as? String,
                      let roleStr = data["role"] as? String,
                      let role = UserRole(rawValue: roleStr),
                      let position = data["position"] as? String,
                      let team = data["team"] as? String,
                      let isApproved = data["isApproved"] as? Bool
                else { return nil }
                
                let joinedDate = (data["joinedDate"] as? Timestamp)?.dateValue() ?? Date()
                let account = StoredAccount(id: userDoc.documentID, firstName: firstName, lastName: lastName,
                    email: email, phone: phone, pin: pin, role: role, position: position,
                    team: team, isApproved: isApproved, joinedDate: joinedDate, presence: data["presence"] as? String ?? "offline", lastSeen: (data["lastSeen"] as? Timestamp)?.dateValue())
                let orgName = orgDoc.data()["name"] as? String ?? ""
                return GlobalPinResult(account: account, orgCode: code, orgName: orgName)
            }
        }
        return nil
    }
    
    // MARK: - Admin PIN Reset (find admin by email across all orgs)
    
    func findAdminByEmail(email: String) async throws -> GlobalPinResult? {
        // Try collectionGroup first
        do {
            let snapshot = try await db.collectionGroup("users")
                .whereField("email", isEqualTo: email)
                .whereField("role", isEqualTo: "admin")
                .getDocuments()
            
            if let doc = snapshot.documents.first {
                let data = doc.data()
                guard let firstName = data["firstName"] as? String,
                      let lastName = data["lastName"] as? String,
                      let pin = data["pin"] as? String,
                      let position = data["position"] as? String,
                      let team = data["team"] as? String
                else { return nil }
                
                let phone = data["phone"] as? String ?? ""
                let joinedDate = (data["joinedDate"] as? Timestamp)?.dateValue() ?? Date()
                let account = StoredAccount(id: doc.documentID, firstName: firstName, lastName: lastName,
                    email: email, phone: phone, pin: pin, role: .admin, position: position,
                    team: team, isApproved: true, joinedDate: joinedDate, presence: data["presence"] as? String ?? "offline", lastSeen: (data["lastSeen"] as? Timestamp)?.dateValue())
                
                let pathComponents = doc.reference.path.split(separator: "/")
                let foundOrgCode = pathComponents.count >= 2 ? String(pathComponents[1]) : ""
                let orgName = try await fetchOrganizationName(code: foundOrgCode) ?? ""
                return GlobalPinResult(account: account, orgCode: foundOrgCode, orgName: orgName)
            }
        } catch {
            print("⚠️ CollectionGroup email query failed, falling back...")
        }
        
        // Fallback: check each org
        let orgsSnapshot = try await db.collection("organizations").getDocuments()
        for orgDoc in orgsSnapshot.documents {
            let code = orgDoc.documentID
            let usersSnapshot = try await db.collection("organizations").document(code).collection("users")
                .whereField("email", isEqualTo: email).whereField("role", isEqualTo: "admin").limit(to: 1).getDocuments()
            
            if let userDoc = usersSnapshot.documents.first {
                let data = userDoc.data()
                guard let firstName = data["firstName"] as? String,
                      let lastName = data["lastName"] as? String,
                      let pin = data["pin"] as? String,
                      let position = data["position"] as? String,
                      let team = data["team"] as? String
                else { continue }
                
                let phone = data["phone"] as? String ?? ""
                let joinedDate = (data["joinedDate"] as? Timestamp)?.dateValue() ?? Date()
                let account = StoredAccount(id: userDoc.documentID, firstName: firstName, lastName: lastName,
                    email: email, phone: phone, pin: pin, role: .admin, position: position,
                    team: team, isApproved: true, joinedDate: joinedDate, presence: data["presence"] as? String ?? "offline", lastSeen: (data["lastSeen"] as? Timestamp)?.dateValue())
                let orgName = orgDoc.data()["name"] as? String ?? ""
                return GlobalPinResult(account: account, orgCode: code, orgName: orgName)
            }
        }
        return nil
    }
    
    func updatePin(orgCode: String, userId: String, newPin: String) async throws {
        try await db.collection("organizations").document(orgCode).collection("users").document(userId).updateData(["pin": newPin])
    }
    
    // Check if email exists in any org
    func emailExists(email: String) async throws -> Bool {
        let orgsSnapshot = try await db.collection("organizations").getDocuments()
        for orgDoc in orgsSnapshot.documents {
            let code = orgDoc.documentID
            let snapshot = try await db.collection("organizations").document(code).collection("users")
                .whereField("email", isEqualTo: email).limit(to: 1).getDocuments()
            if !snapshot.documents.isEmpty { return true }
        }
        return false
    }
    
    // MARK: - Users
    
    func saveAccount(_ account: StoredAccount) async throws {
        try await orgRef().collection("users").document(account.id).setData([
            "firstName": account.firstName, "lastName": account.lastName,
            "email": account.email, "phone": account.phone, "pin": account.pin,
            "role": account.role.rawValue, "position": account.position, "team": account.team,
            "isApproved": account.isApproved, "joinedDate": Timestamp(date: account.joinedDate),
        ])
    }
    
    func updateAccountApproval(id: String, approved: Bool) async throws {
        try await orgRef().collection("users").document(id).updateData(["isApproved": approved])
    }
    
    func updateAccountRole(id: String, role: UserRole, position: String, team: String, phone: String) async throws {
        try await orgRef().collection("users").document(id).updateData([
            "role": role.rawValue, "position": position, "team": team, "phone": phone,
        ])
    }
    
    func deleteAccount(id: String) async throws {
        try await orgRef().collection("users").document(id).delete()
    }
    
    // MARK: - Segments
    
    func saveSegments(_ segments: [Segment]) async throws {
        let batch = db.batch()
        let existing = try await orgRef().collection("segments").getDocuments()
        for doc in existing.documents { batch.deleteDocument(doc.reference) }
        for seg in segments {
            let ref = orgRef().collection("segments").document(seg.id)
            batch.setData(["order": seg.order, "title": seg.title, "duration": seg.duration,
                "assignedRole": seg.assignedRole, "status": seg.status.rawValue,
                "notes": seg.notes, "description": seg.description], forDocument: ref)
        }
        try await batch.commit()
    }
    
    // MARK: - Saved Rundowns
    
    struct SavedRundown: Identifiable {
        let id: String
        var name: String
        var createdAt: Date
        var createdBy: String
        var segmentCount: Int
    }
    
    func saveRundownTemplate(name: String, segments: [Segment], createdBy: String) async throws {
        let rundownId = UUID().uuidString
        let rundownRef = orgRef().collection("rundowns").document(rundownId)
        
        // Save rundown metadata
        try await rundownRef.setData([
            "name": name,
            "createdAt": Timestamp(date: Date()),
            "createdBy": createdBy,
            "segmentCount": segments.count,
        ])
        
        // Save segments inside the rundown
        let batch = db.batch()
        for seg in segments {
            let segRef = rundownRef.collection("segments").document(seg.id)
            batch.setData([
                "order": seg.order, "title": seg.title, "duration": seg.duration,
                "assignedRole": seg.assignedRole, "status": "upcoming",
                "notes": seg.notes, "description": seg.description
            ], forDocument: segRef)
        }
        try await batch.commit()
    }
    
    func fetchSavedRundowns() async throws -> [SavedRundown] {
        let snapshot = try await orgRef().collection("rundowns")
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let name = data["name"] as? String,
                  let ts = data["createdAt"] as? Timestamp,
                  let createdBy = data["createdBy"] as? String
            else { return nil }
            return SavedRundown(
                id: doc.documentID, name: name,
                createdAt: ts.dateValue(), createdBy: createdBy,
                segmentCount: data["segmentCount"] as? Int ?? 0
            )
        }
    }
    
    func loadRundownTemplate(rundownId: String) async throws -> [Segment] {
        let snapshot = try await orgRef().collection("rundowns").document(rundownId)
            .collection("segments").order(by: "order").getDocuments()
        
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let order = data["order"] as? Int, let title = data["title"] as? String,
                  let duration = data["duration"] as? Int, let assignedRole = data["assignedRole"] as? String,
                  let notes = data["notes"] as? String else { return nil }
            return Segment(id: UUID().uuidString, order: order, title: title, duration: duration,
                           assignedRole: assignedRole, status: .upcoming, notes: notes,
                           description: data["description"] as? String ?? "")
        }
    }
    
    func deleteRundownTemplate(rundownId: String) async throws {
        // Delete segments sub-collection first
        let segs = try await orgRef().collection("rundowns").document(rundownId)
            .collection("segments").getDocuments()
        let batch = db.batch()
        for doc in segs.documents { batch.deleteDocument(doc.reference) }
        try await batch.commit()
        
        // Delete rundown doc
        try await orgRef().collection("rundowns").document(rundownId).delete()
    }
    
    // MARK: - Broadcast
    
    func saveBroadcastState(isLive: Bool) async throws {
        var data: [String: Any] = [
            "isLive": isLive, "updatedAt": Timestamp(date: Date()),
        ]
        if isLive {
            data["startTime"] = Timestamp(date: Date())
        }
        try await orgRef().collection("broadcast").document("current").setData(data, merge: true)
    }
    
    // MARK: - Events
    
    func saveEvent(_ event: BroadcastEvent) async throws {
        try await orgRef().collection("events").document(event.id).setData([
            "title": event.title, "date": Timestamp(date: event.date), "reminderSent": event.reminderSent,
        ])
    }
    
    func fetchEvents() async throws -> [BroadcastEvent] {
        let snapshot = try await orgRef().collection("events").order(by: "date").getDocuments()
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let title = data["title"] as? String, let dateTs = data["date"] as? Timestamp else { return nil }
            return BroadcastEvent(id: doc.documentID, title: title, date: dateTs.dateValue(), reminderSent: data["reminderSent"] as? Bool ?? false)
        }
    }
    
    func deleteEvent(id: String) async throws {
        try await orgRef().collection("events").document(id).delete()
    }
    
    // MARK: - Listeners
    
    func listenToAccounts(onChange: @escaping ([StoredAccount]) -> Void) -> ListenerRegistration {
        return orgRef().collection("users").addSnapshotListener { snapshot, error in
            guard let docs = snapshot?.documents, error == nil else { return }
            let accounts = docs.compactMap { doc -> StoredAccount? in
                let data = doc.data()
                guard let firstName = data["firstName"] as? String, let lastName = data["lastName"] as? String,
                      let email = data["email"] as? String, let phone = data["phone"] as? String,
                      let pin = data["pin"] as? String, let roleStr = data["role"] as? String,
                      let role = UserRole(rawValue: roleStr), let position = data["position"] as? String,
                      let team = data["team"] as? String, let isApproved = data["isApproved"] as? Bool
                else { return nil }
                let joinedDate = (data["joinedDate"] as? Timestamp)?.dateValue() ?? Date()
                let presence = data["presence"] as? String ?? "offline"
                let lastSeen = (data["lastSeen"] as? Timestamp)?.dateValue()
                return StoredAccount(id: doc.documentID, firstName: firstName, lastName: lastName,
                    email: email, phone: phone, pin: pin, role: role, position: position,
                    team: team, isApproved: isApproved, joinedDate: joinedDate,
                    presence: presence, lastSeen: lastSeen)
            }
            onChange(accounts)
        }
    }
    
    func listenToBroadcast(onChange: @escaping (Bool, Date?) -> Void) -> ListenerRegistration {
        return orgRef().collection("broadcast").document("current").addSnapshotListener { snapshot, error in
            guard let data = snapshot?.data(), error == nil else { return }
            let isLive = data["isLive"] as? Bool ?? false
            let startTime = (data["startTime"] as? Timestamp)?.dateValue()
            onChange(isLive, startTime)
        }
    }
    
    func listenToSegments(onChange: @escaping ([Segment]) -> Void) -> ListenerRegistration {
        return orgRef().collection("segments").order(by: "order").addSnapshotListener { snapshot, error in
            guard let snapshot = snapshot, error == nil else { return }
            // Ignore an empty snapshot that only came from the local cache (e.g. right
            // after reconnecting) — it would briefly wipe the rundown before the server
            // copy arrives. A server-confirmed empty IS honored (intentional "Clear All").
            if snapshot.documents.isEmpty && snapshot.metadata.isFromCache { return }
            let segments = snapshot.documents.compactMap { doc -> Segment? in
                let data = doc.data()
                guard let order = data["order"] as? Int, let title = data["title"] as? String,
                      let duration = data["duration"] as? Int, let assignedRole = data["assignedRole"] as? String,
                      let statusStr = data["status"] as? String, let status = SegmentStatus(rawValue: statusStr),
                      let notes = data["notes"] as? String else { return nil }
                return Segment(id: doc.documentID, order: order, title: title, duration: duration,
                               assignedRole: assignedRole, status: status, notes: notes, description: data["description"] as? String ?? "")
            }
            onChange(segments)
        }
    }
    
    // MARK: - Equipment
    
    func saveEquipment(_ item: Equipment) async throws {
        try await orgRef().collection("equipment").document(item.id).setData([
            "name": item.name, "type": item.type, "condition": item.condition.rawValue,
            "status": item.status, "assignedTo": item.assignedTo ?? NSNull(),
        ])
    }
    
    func deleteEquipment(_ id: String) async throws {
        try await orgRef().collection("equipment").document(id).delete()
    }
    
    func countAdmins(orgCode: String) async throws -> Int {
        let snapshot = try await db.collection("organizations").document(orgCode).collection("users")
            .whereField("role", isEqualTo: "admin")
            .getDocuments()
        return snapshot.documents.count
    }
    
    func seedEquipment(_ items: [Equipment]) async throws {
        let batch = db.batch()
        for item in items {
            let ref = orgRef().collection("equipment").document(item.id)
            batch.setData(["name": item.name, "type": item.type, "condition": item.condition.rawValue,
                "status": item.status, "assignedTo": item.assignedTo ?? NSNull()], forDocument: ref)
        }
        try await batch.commit()
    }
    
    func listenToEquipment(onChange: @escaping ([Equipment]) -> Void) -> ListenerRegistration {
        return orgRef().collection("equipment").addSnapshotListener { snapshot, error in
            guard let docs = snapshot?.documents, error == nil else { return }
            let items = docs.compactMap { doc -> Equipment? in
                let data = doc.data()
                guard let name = data["name"] as? String, let type = data["type"] as? String,
                      let condStr = data["condition"] as? String, let condition = EquipmentCondition(rawValue: condStr),
                      let status = data["status"] as? String else { return nil }
                let assignedTo = data["assignedTo"] as? String
                return Equipment(id: doc.documentID, name: name, type: type, condition: condition, status: status, assignedTo: assignedTo)
            }
            onChange(items)
        }
    }
    
    // MARK: - Messages
    
    func sendMessage(_ msg: ChatMessage) async throws {
        try await orgRef().collection("messages").document(msg.id).setData([
            "senderId": msg.senderId, "senderName": msg.senderName,
            "teamId": msg.teamId ?? NSNull(), "recipientId": msg.recipientId ?? NSNull(),
            "text": msg.text, "type": msg.type,
            "timestamp": Timestamp(date: msg.timestamp),
        ])
    }
    
    func listenToMessages(onChange: @escaping ([ChatMessage]) -> Void) -> ListenerRegistration {
        return orgRef().collection("messages").order(by: "timestamp").addSnapshotListener { snapshot, error in
            guard let docs = snapshot?.documents, error == nil else { return }
            let msgs = docs.compactMap { doc -> ChatMessage? in
                let data = doc.data()
                guard let senderId = data["senderId"] as? String,
                      let senderName = data["senderName"] as? String,
                      let text = data["text"] as? String,
                      let type = data["type"] as? String,
                      let ts = data["timestamp"] as? Timestamp
                else { return nil }
                return ChatMessage(id: doc.documentID, senderId: senderId, senderName: senderName,
                    teamId: data["teamId"] as? String, recipientId: data["recipientId"] as? String,
                    text: text, type: type, broadcastId: nil, timestamp: ts.dateValue())
            }
            onChange(msgs)
        }
    }
    
    // MARK: - Presence
    
    func updatePresence(userId: String, status: String) async throws {
        try await updatePresence(orgCode: orgCode, userId: userId, status: status)
    }

    /// Explicit-org variant. Used during logout, where `orgCode` is cleared
    /// synchronously and an async presence write must not race against it.
    /// Empty paths are skipped — `document("")` throws a fatal Firestore exception.
    func updatePresence(orgCode: String, userId: String, status: String) async throws {
        guard !orgCode.isEmpty, !userId.isEmpty else { return }
        try await db.collection("organizations").document(orgCode)
            .collection("users").document(userId).updateData([
                "presence": status, "lastSeen": Timestamp(date: Date()),
            ])
    }
    
    func saveFCMToken(userId: String, token: String) async throws {
        try await orgRef().collection("users").document(userId).updateData([
            "fcmToken": token,
        ])
    }
    
    // MARK: - PTT Channel State
    
    struct PTTState {
        let userId: String
        let userName: String
        let channel: String // team id or "dm:{recipientId}"
        let startedAt: Date
    }
    
    func startTransmitting(userId: String, userName: String, channel: String) async throws {
        try await orgRef().collection("ptt").document("active").setData([
            "userId": userId, "userName": userName, "channel": channel,
            "startedAt": Timestamp(date: Date()), "active": true,
        ])
    }
    
    func stopTransmitting() async throws {
        try await orgRef().collection("ptt").document("active").setData([
            "active": false, "userId": "", "userName": "", "channel": "", "stoppedAt": Timestamp(date: Date()),
        ])
    }
    
    func listenToPTT(onChange: @escaping (PTTState?) -> Void) -> ListenerRegistration {
        return orgRef().collection("ptt").document("active").addSnapshotListener { snapshot, error in
            guard let data = snapshot?.data(), error == nil else { onChange(nil); return }
            let active = data["active"] as? Bool ?? false
            guard active,
                  let userId = data["userId"] as? String, !userId.isEmpty,
                  let userName = data["userName"] as? String,
                  let channel = data["channel"] as? String,
                  let ts = data["startedAt"] as? Timestamp
            else { onChange(nil); return }
            
            // Auto-expire after 30 seconds (safety — in case someone disconnects while transmitting)
            if Date().timeIntervalSince(ts.dateValue()) > 30 { onChange(nil); return }
            
            onChange(PTTState(userId: userId, userName: userName, channel: channel, startedAt: ts.dateValue()))
        }
    }
    
    // MARK: - Segment Alerts
    
    func saveSegmentAlert(_ alert: SegmentChangeAlert) async throws {
        try await orgRef().collection("alerts").document(alert.id).setData([
            "type": alert.type.rawValue, "segmentTitle": alert.segmentTitle,
            "changedBy": alert.changedBy, "changedByUserId": alert.changedByUserId,
            "changedByRole": alert.changedByRole.rawValue,
            "timestamp": Timestamp(date: alert.timestamp),
            "acknowledgedBy": alert.acknowledgedBy,
        ])
    }
    
    func updateAlertAcknowledgment(alertId: String, userId: String) async throws {
        try await orgRef().collection("alerts").document(alertId).updateData([
            "acknowledgedBy": FieldValue.arrayUnion([userId])
        ])
    }
    
    func listenToActiveAlert(onChange: @escaping (SegmentChangeAlert?) -> Void) -> ListenerRegistration {
        return orgRef().collection("alerts").order(by: "timestamp", descending: true).limit(to: 1)
            .addSnapshotListener { snapshot, error in
                guard let doc = snapshot?.documents.first, error == nil else { onChange(nil); return }
                let data = doc.data()
                guard let typeStr = data["type"] as? String,
                      let type = SegmentChangeAlert.SegmentChangeType(rawValue: typeStr),
                      let segmentTitle = data["segmentTitle"] as? String,
                      let changedBy = data["changedBy"] as? String,
                      let changedByUserId = data["changedByUserId"] as? String,
                      let changedByRoleStr = data["changedByRole"] as? String,
                      let changedByRole = UserRole(rawValue: changedByRoleStr),
                      let ts = data["timestamp"] as? Timestamp
                else { onChange(nil); return }
                
                let acknowledgedBy = data["acknowledgedBy"] as? [String] ?? []
                
                // Only show alerts from last 5 minutes
                let age = Date().timeIntervalSince(ts.dateValue())
                guard age < 300 else { onChange(nil); return }
                
                let alert = SegmentChangeAlert(id: doc.documentID, type: type, segmentTitle: segmentTitle,
                    changedBy: changedBy, changedByUserId: changedByUserId, changedByRole: changedByRole,
                    timestamp: ts.dateValue(), acknowledgedBy: acknowledgedBy)
                onChange(alert)
            }
    }
    
    // MARK: - Team Alerts
    
    func sendTeamAlert(_ alert: TeamAlert) async throws {
        try await orgRef().collection("teamAlerts").document(alert.id).setData([
            "message": alert.message,
            "senderName": alert.senderName,
            "senderId": alert.senderId,
            "senderRole": alert.senderRole,
            "timestamp": Timestamp(date: alert.timestamp),
            "read": false,
        ])
        
        // Also write to "latestAlert" doc for real-time banner trigger
        try await orgRef().collection("teamAlerts").document("latest").setData([
            "alertId": alert.id,
            "message": alert.message,
            "senderName": alert.senderName,
            "senderId": alert.senderId,
            "senderRole": alert.senderRole,
            "timestamp": Timestamp(date: alert.timestamp),
        ])
    }
    
    func listenToTeamAlerts(onChange: @escaping (TeamAlert?) -> Void) -> ListenerRegistration {
        return orgRef().collection("teamAlerts").document("latest")
            .addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data(),
                      let message = data["message"] as? String,
                      let senderName = data["senderName"] as? String,
                      let senderId = data["senderId"] as? String,
                      let senderRole = data["senderRole"] as? String,
                      let ts = data["timestamp"] as? Timestamp,
                      let alertId = data["alertId"] as? String
                else { onChange(nil); return }
                
                // Only show alerts from last 15 seconds (fresh ones)
                let age = Date().timeIntervalSince(ts.dateValue())
                guard age < 15 else { onChange(nil); return }
                
                let alert = TeamAlert(
                    id: alertId, message: message, senderName: senderName,
                    senderId: senderId, senderRole: senderRole,
                    timestamp: ts.dateValue(), read: false
                )
                onChange(alert)
            }
    }
    
    func fetchAlertHistory() async -> [TeamAlert] {
        do {
            let snapshot = try await orgRef().collection("teamAlerts")
                .whereField("message", isNotEqualTo: NSNull())
                .order(by: "timestamp", descending: true)
                .limit(to: 20)
                .getDocuments()
            
            return snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard doc.documentID != "latest",
                      let message = data["message"] as? String,
                      let senderName = data["senderName"] as? String,
                      let senderId = data["senderId"] as? String,
                      let senderRole = data["senderRole"] as? String,
                      let ts = data["timestamp"] as? Timestamp
                else { return nil }
                
                return TeamAlert(
                    id: doc.documentID, message: message, senderName: senderName,
                    senderId: senderId, senderRole: senderRole,
                    timestamp: ts.dateValue(), read: data["read"] as? Bool ?? false
                )
            }
        } catch { return [] }
    }
}

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Firestore serialization & real-time listeners

struct FirestoreService {
    private static var db: Firestore { Firestore.firestore() }

    // MARK: - Collection references

    private static var loads: CollectionReference { db.collection("loads") }
    private static var units: CollectionReference { db.collection("units") }
    private static var offers: CollectionReference { db.collection("offers") }
    private static var notifs: CollectionReference { db.collection("notifications") }
    private static var users: CollectionReference { db.collection("users") }

    // MARK: - Helpers

    private static func ts(_ date: Date) -> Timestamp { Timestamp(date: date) }
    private static func date(_ value: Any?) -> Date {
        (value as? Timestamp)?.dateValue() ?? Date()
    }
    private static func decimal(_ value: Any?) -> Decimal {
        guard let d = value as? Double else { return 0 }
        return Decimal(d)
    }
    private static func uuid(_ value: Any?) -> UUID? {
        guard let s = value as? String else { return nil }
        return UUID(uuidString: s)
    }

    // MARK: - StatusChange

    private static func statusChangeToData(_ sc: StatusChange) -> [String: Any] {
        ["id": sc.id.uuidString,
         "status": sc.status.rawValue,
         "changedBy": sc.changedBy.uuidString,
         "changedByName": sc.changedByName,
         "changedAt": ts(sc.changedAt),
         "notes": sc.notes]
    }

    private static func parseStatusChange(_ d: [String: Any]) -> StatusChange? {
        guard let statusStr = d["status"] as? String,
              let status = LoadStatus(rawValue: statusStr),
              let changedByStr = d["changedBy"] as? String,
              let changedBy = UUID(uuidString: changedByStr),
              let changedByName = d["changedByName"] as? String else { return nil }
        var sc = StatusChange(status: status, changedBy: changedBy,
                              changedByName: changedByName,
                              notes: d["notes"] as? String ?? "")
        if let idStr = d["id"] as? String, let id = UUID(uuidString: idStr) { sc.id = id }
        sc.changedAt = date(d["changedAt"])
        return sc
    }

    // MARK: - CarrierRoute

    private static func routeToData(_ r: CarrierRoute) -> [String: Any] {
        ["id": r.id.uuidString,
         "originState": r.originState,
         "destinationState": r.destinationState,
         "bidirectional": r.bidirectional,
         "equipmentTypes": r.equipmentTypes.map { $0.rawValue }]
    }

    private static func parseRoute(_ d: [String: Any]) -> CarrierRoute? {
        guard let origin = d["originState"] as? String,
              let destination = d["destinationState"] as? String else { return nil }
        let id = uuid(d["id"]) ?? UUID()
        let bidirectional = d["bidirectional"] as? Bool ?? true
        let eqStrs = d["equipmentTypes"] as? [String] ?? []
        let equipment = eqStrs.compactMap { EquipmentType(rawValue: $0) }
        return CarrierRoute(id: id, originState: origin, destinationState: destination,
                            bidirectional: bidirectional, equipmentTypes: equipment)
    }

    // MARK: - Load

    static func loadToData(_ load: Load) -> [String: Any] {
        var data: [String: Any] = [
            "id": load.id.uuidString,
            "reference": load.reference,
            "originCity": load.originCity,
            "originState": load.originState,
            "destinationCity": load.destinationCity,
            "destinationState": load.destinationState,
            "pickupDate": ts(load.pickupDate),
            "deliveryDate": ts(load.deliveryDate),
            "equipmentType": load.equipmentType.rawValue,
            "unitCount": load.unitCount,
            "confirmedUnitCount": load.confirmedUnitCount,
            "weightKg": load.weightKg,
            "merchandiseDescription": load.merchandiseDescription,
            "measurementsDescription": load.measurementsDescription,
            "specialRequirements": load.specialRequirements.map { $0.rawValue },
            "offeredPrice": NSDecimalNumber(decimal: load.offeredPrice).doubleValue,
            "currency": load.currency.rawValue,
            "includesVAT": load.includesVAT,
            "includedConcepts": load.includedConcepts,
            "allowedExtraExpenses": load.allowedExtraExpenses,
            "assignmentMode": load.assignmentMode.rawValue,
            "deadline": ts(load.deadline),
            "minBidDecrement": NSDecimalNumber(decimal: load.minBidDecrement).doubleValue,
            "observations": load.observations,
            "status": load.status.rawValue,
            "publishedBy": load.publishedBy.uuidString,
            "publishedAt": ts(load.publishedAt),
            "trackingUrl": load.trackingUrl,
            "statusHistory": load.statusHistory.map { statusChangeToData($0) },
            "clientContactName": load.clientContactName,
            "clientContactPhone": load.clientContactPhone,
            "exactPickupAddress": load.exactPickupAddress,
            "exactDeliveryAddress": load.exactDeliveryAddress
        ]
        if let v = load.assignedCarrierId { data["assignedCarrierId"] = v.uuidString }
        if let v = load.assignedUnitId { data["assignedUnitId"] = v.uuidString }
        if let v = load.assignedOperatorId { data["assignedOperatorId"] = v.uuidString }
        if let v = load.unitETA { data["unitETA"] = ts(v) }
        if let v = load.maxAuthorizedPriceSinIVA { data["maxAuthorizedPriceSinIVA"] = NSDecimalNumber(decimal: v).doubleValue }
        if let v = load.assignedPriceSinIVA { data["assignedPriceSinIVA"] = NSDecimalNumber(decimal: v).doubleValue }
        if !load.confirmedCarrierIds.isEmpty {
            data["confirmedCarrierIds"] = load.confirmedCarrierIds.map { $0.uuidString }
        }
        let nc = load.notificationChannels
        data["notificationChannels"] = [
            "inApp": nc.inApp, "email": nc.email,
            "whatsapp": nc.whatsapp, "aiCall": nc.aiCall
        ]
        return data
    }

    static func parseLoad(from data: [String: Any]) -> Load? {
        guard let idStr = data["id"] as? String, let id = UUID(uuidString: idStr),
              let reference = data["reference"] as? String,
              let originCity = data["originCity"] as? String,
              let originState = data["originState"] as? String,
              let destinationCity = data["destinationCity"] as? String,
              let destinationState = data["destinationState"] as? String,
              let eqStr = data["equipmentType"] as? String,
              let equipmentType = EquipmentType(rawValue: eqStr),
              let modeStr = data["assignmentMode"] as? String,
              let assignmentMode = AssignmentMode(rawValue: modeStr),
              let statusStr = data["status"] as? String,
              let status = LoadStatus(rawValue: statusStr),
              let publishedByStr = data["publishedBy"] as? String,
              let publishedBy = UUID(uuidString: publishedByStr) else { return nil }

        var load = Load(
            id: id,
            reference: reference,
            originCity: originCity,
            originState: originState,
            destinationCity: destinationCity,
            destinationState: destinationState,
            pickupDate: date(data["pickupDate"]),
            deliveryDate: date(data["deliveryDate"]),
            equipmentType: equipmentType,
            unitCount: data["unitCount"] as? Int ?? 1,
            weightKg: data["weightKg"] as? Double ?? 0,
            merchandiseDescription: data["merchandiseDescription"] as? String ?? "",
            specialRequirements: (data["specialRequirements"] as? [String] ?? [])
                .compactMap { SpecialRequirement(rawValue: $0) },
            offeredPrice: decimal(data["offeredPrice"]),
            currency: Currency(rawValue: data["currency"] as? String ?? "") ?? .mxn,
            includesVAT: data["includesVAT"] as? Bool ?? false,
            includedConcepts: data["includedConcepts"] as? String ?? "",
            allowedExtraExpenses: data["allowedExtraExpenses"] as? String ?? "",
            assignmentMode: assignmentMode,
            deadline: date(data["deadline"]),
            minBidDecrement: decimal(data["minBidDecrement"]),
            observations: data["observations"] as? String ?? "",
            publishedBy: publishedBy,
            clientContactName: data["clientContactName"] as? String ?? "",
            clientContactPhone: data["clientContactPhone"] as? String ?? "",
            exactPickupAddress: data["exactPickupAddress"] as? String ?? "",
            exactDeliveryAddress: data["exactDeliveryAddress"] as? String ?? ""
        )
        load.status = status
        load.publishedAt = date(data["publishedAt"])
        load.trackingUrl = data["trackingUrl"] as? String ?? ""
        load.assignedCarrierId = uuid(data["assignedCarrierId"])
        load.assignedUnitId = uuid(data["assignedUnitId"])
        load.assignedOperatorId = uuid(data["assignedOperatorId"])
        load.unitETA = (data["unitETA"] as? Timestamp)?.dateValue()
        if let v = data["maxAuthorizedPriceSinIVA"] as? Double { load.maxAuthorizedPriceSinIVA = Decimal(v) }
        if let v = data["assignedPriceSinIVA"] as? Double { load.assignedPriceSinIVA = Decimal(v) }
        if let v = data["confirmedUnitCount"] as? Int { load.confirmedUnitCount = v }
        if let ids = data["confirmedCarrierIds"] as? [String] {
            load.confirmedCarrierIds = ids.compactMap { UUID(uuidString: $0) }
        }
        load.measurementsDescription = data["measurementsDescription"] as? String ?? ""
        load.statusHistory = (data["statusHistory"] as? [[String: Any]] ?? [])
            .compactMap { parseStatusChange($0) }
        if let nc = data["notificationChannels"] as? [String: Any] {
            load.notificationChannels = NotificationChannels(
                inApp:    nc["inApp"]    as? Bool ?? true,
                email:    nc["email"]   as? Bool ?? true,
                whatsapp: nc["whatsapp"] as? Bool ?? true,
                aiCall:   nc["aiCall"]  as? Bool ?? false
            )
        }
        return load
    }

    // MARK: - Unit

    static func unitToData(_ unit: Unit) -> [String: Any] {
        var data: [String: Any] = [
            "id": unit.id.uuidString,
            "ownerId": unit.ownerId.uuidString,
            "equipmentType": unit.equipmentType.rawValue,
            "plates": unit.plates,
            "trailerNumber": unit.trailerNumber,
            "currentLocation": unit.currentLocation,
            "operatorName": unit.operatorName,
            "scac": unit.scac,
            "caat": unit.caat,
            "availableFrom": ts(unit.availableFrom),
            "coverageZones": unit.coverageZones,
            "status": unit.status.rawValue,
            "notes": unit.notes
        ]
        if let v = unit.operatorId { data["operatorId"] = v.uuidString }
        return data
    }

    static func parseUnit(from data: [String: Any]) -> Unit? {
        guard let idStr = data["id"] as? String, let id = UUID(uuidString: idStr),
              let ownerStr = data["ownerId"] as? String, let ownerId = UUID(uuidString: ownerStr),
              let eqStr = data["equipmentType"] as? String,
              let equipmentType = EquipmentType(rawValue: eqStr) else { return nil }
        return Unit(
            id: id,
            ownerId: ownerId,
            equipmentType: equipmentType,
            plates: data["plates"] as? String ?? "",
            trailerNumber: data["trailerNumber"] as? String ?? "",
            currentLocation: data["currentLocation"] as? String ?? "",
            operatorName: data["operatorName"] as? String ?? "",
            scac: data["scac"] as? String ?? "",
            caat: data["caat"] as? String ?? "",
            availableFrom: date(data["availableFrom"]),
            coverageZones: data["coverageZones"] as? [String] ?? [],
            status: UnitStatus(rawValue: data["status"] as? String ?? "") ?? .available,
            operatorId: uuid(data["operatorId"]),
            notes: data["notes"] as? String ?? "",
            postedOriginState: data["postedOriginState"] as? String ?? "",
            postedDestinationState: data["postedDestinationState"] as? String ?? "",
            isAvailabilityPosted: data["isAvailabilityPosted"] as? Bool ?? false
        )
    }

    // MARK: - Offer

    static func offerToData(_ offer: Offer) -> [String: Any] {
        var data: [String: Any] = [
            "id": offer.id.uuidString,
            "loadId": offer.loadId.uuidString,
            "carrierId": offer.carrierId.uuidString,
            "carrierName": offer.carrierName,
            "amount": NSDecimalNumber(decimal: offer.amount).doubleValue,
            "currency": offer.currency.rawValue,
            "isAvailabilityOnly": offer.isAvailabilityOnly,
            "availableUnitCount": offer.availableUnitCount,
            "status": offer.status.rawValue,
            "submittedAt": ts(offer.submittedAt),
            "notes": offer.notes
        ]
        if let v = offer.unitId { data["unitId"] = v.uuidString }
        if let v = offer.operatorId { data["operatorId"] = v.uuidString }
        if let v = offer.proposedPrice {
            data["proposedPrice"] = NSDecimalNumber(decimal: v).doubleValue
        }
        return data
    }

    static func parseOffer(from data: [String: Any]) -> Offer? {
        guard let idStr = data["id"] as? String, let id = UUID(uuidString: idStr),
              let loadIdStr = data["loadId"] as? String, let loadId = UUID(uuidString: loadIdStr),
              let carrierIdStr = data["carrierId"] as? String,
              let carrierId = UUID(uuidString: carrierIdStr),
              let carrierName = data["carrierName"] as? String,
              let statusStr = data["status"] as? String,
              let status = OfferStatus(rawValue: statusStr) else { return nil }
        var offer = Offer(
            id: id,
            loadId: loadId,
            carrierId: carrierId,
            carrierName: carrierName,
            unitId: uuid(data["unitId"]),
            operatorId: uuid(data["operatorId"]),
            amount: decimal(data["amount"]),
            currency: Currency(rawValue: data["currency"] as? String ?? "") ?? .mxn,
            isAvailabilityOnly: data["isAvailabilityOnly"] as? Bool ?? false,
            proposedPrice: (data["proposedPrice"] as? Double).map { Decimal($0) },
            availableUnitCount: data["availableUnitCount"] as? Int ?? 1,
            notes: data["notes"] as? String ?? ""
        )
        offer.status = status
        offer.submittedAt = date(data["submittedAt"])
        return offer
    }

    // MARK: - AppNotification

    static func notificationToData(_ n: AppNotification) -> [String: Any] {
        var data: [String: Any] = [
            "id": n.id.uuidString,
            "userId": n.userId.uuidString,
            "type": n.type.rawValue,
            "title": n.title,
            "body": n.body,
            "isRead": n.isRead,
            "createdAt": ts(n.createdAt)
        ]
        if let v = n.loadId { data["loadId"] = v.uuidString }
        return data
    }

    static func parseNotification(from data: [String: Any]) -> AppNotification? {
        guard let idStr = data["id"] as? String, let id = UUID(uuidString: idStr),
              let userIdStr = data["userId"] as? String, let userId = UUID(uuidString: userIdStr),
              let typeStr = data["type"] as? String, let type = NotificationType(rawValue: typeStr),
              let title = data["title"] as? String,
              let body = data["body"] as? String else { return nil }
        var n = AppNotification(id: id, userId: userId, type: type,
                                title: title, body: body,
                                loadId: uuid(data["loadId"]))
        n.isRead = data["isRead"] as? Bool ?? false
        n.createdAt = date(data["createdAt"])
        return n
    }

    // MARK: - AppUser

    static func userToData(_ user: AppUser) -> [String: Any] {
        var data: [String: Any] = [
            "uuid": user.id.uuidString,
            "name": user.name,
            "email": user.email,
            "phone": user.phone,
            "role": user.role.rawValue,
            "status": user.status.rawValue,
            "canNegotiateRates": user.canNegotiateRates,
            "handlesLTL": user.handlesLTL,
            "handlesLocal": user.handlesLocal,
            "handlesIntraState": user.handlesIntraState,
            "createdAt": ts(user.createdAt),
            "routes": user.routes.map { routeToData($0) }
        ]
        if let v = user.companyId { data["companyId"] = v.uuidString }
        if !user.coverageStates.isEmpty {
            data["coverageStates"] = user.coverageStates
        }
        if !user.notificationEmails.isEmpty {
            data["notificationEmails"] = user.notificationEmails
        }
        if !user.whatsappNumbers.isEmpty {
            data["whatsappNumbers"] = user.whatsappNumbers
        }
        if !user.coverageZones.isEmpty {
            data["coverageZones"] = user.coverageZones.map { $0.rawValue }
        }
        if !user.coverageEquipmentTypes.isEmpty {
            data["coverageEquipmentTypes"] = user.coverageEquipmentTypes.map { $0.rawValue }
        }
        if user.coversUSA {
            data["coversUSA"] = true
        }
        if !user.coverageUSAStates.isEmpty {
            data["coverageUSAStates"] = user.coverageUSAStates
        }
        if let v = user.pricerId { data["pricerId"] = v.uuidString }
        return data
    }

    static func parseUser(from data: [String: Any]) -> AppUser? {
        // Phone/email may be missing on some carrier docs; dropping them under-counts
        // Competencia exitosos vs web (which reads raw Firestore fields).
        guard let name = data["name"] as? String,
              let roleStr = data["role"] as? String, let role = UserRole(rawValue: roleStr),
              let statusStr = data["status"] as? String,
              let status = UserStatus(rawValue: statusStr) else { return nil }
        let email = (data["email"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        let phone = data["phone"] as? String ?? ""
        let uuidStr = data["uuid"] as? String ?? ""
        let id = UUID(uuidString: uuidStr) ?? UUID()
        let routes = (data["routes"] as? [[String: Any]] ?? []).compactMap { parseRoute($0) }
        let coverageStates = data["coverageStates"] as? [String] ?? []
        let coverageZones = (data["coverageZones"] as? [String] ?? [])
            .compactMap { MexicanZone(rawValue: $0) }
        let coverageEquipmentTypes = (data["coverageEquipmentTypes"] as? [String] ?? [])
            .compactMap { EquipmentType(rawValue: $0) }
        let coverageUSAStates = data["coverageUSAStates"] as? [String] ?? []
        var user = AppUser(id: id, name: name, email: email, phone: phone,
                           role: role, status: status,
                           companyId: uuid(data["companyId"]),
                           canNegotiateRates: data["canNegotiateRates"] as? Bool ?? true,
                           routes: routes,
                           handlesLTL: data["handlesLTL"] as? Bool ?? false,
                           handlesLocal: data["handlesLocal"] as? Bool ?? false,
                           handlesIntraState: data["handlesIntraState"] as? Bool ?? false,
                           coversUSA: data["coversUSA"] as? Bool ?? false,
                           coverageZones: coverageZones,
                           coverageStates: coverageStates,
                           coverageEquipmentTypes: coverageEquipmentTypes,
                           coverageUSAStates: coverageUSAStates,
                           notificationEmails: data["notificationEmails"] as? [String] ?? [],
                           whatsappNumbers: data["whatsappNumbers"] as? [String] ?? [],
                           pricerId: uuid(data["pricerId"]))
        user.pricerRawId = data["pricerId"] as? String ?? ""
        // Keep raw Auth UID when uuid is not a Swift UUID (common for pricers/carriers).
        if UUID(uuidString: uuidStr) == nil, !uuidStr.isEmpty {
            user.firebaseUID = uuidStr
        }
        user.pricerEmail = emailOf(data["pricerEmail"] as? String ?? "")
        return user
    }

    /// Mirrors web emailOf: extract first email and lowercase.
    static func emailOf(_ value: String) -> String {
        let pattern = #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return value.trimmingCharacters(in: .whitespaces).lowercased()
        }
        let range = NSRange(value.startIndex..., in: value)
        guard let match = regex.firstMatch(in: value, range: range),
              let swiftRange = Range(match.range, in: value) else {
            let trimmed = value.trimmingCharacters(in: .whitespaces).lowercased()
            return trimmed.contains("@") ? trimmed : ""
        }
        return String(value[swiftRange]).lowercased()
    }

    // MARK: - Writes

    static func saveLoad(_ load: Load) {
        let data = loadToData(load)
        print("[DBG] saveLoad \(load.reference) docId=\(load.id.uuidString.prefix(8)) fields=\(data.keys.sorted())")
        loads.document(load.id.uuidString).setData(data) { error in
            if let error = error {
                let nsErr = error as NSError
                print("❌ [Firestore] saveLoad failed for \(load.reference): \(error.localizedDescription) (domain=\(nsErr.domain) code=\(nsErr.code))")
            } else {
                print("✅ [Firestore] saveLoad OK for \(load.reference)")
            }
        }
    }

    // Usa updateData (no setData) para que campos del backend como cartaInstruccion no sean borrados.
    static func updateLoadForCarrierConfirmation(_ load: Load) {
        var fields: [String: Any] = [
            "confirmedCarrierIds": load.confirmedCarrierIds.map { $0.uuidString },
            "confirmedUnitCount": load.confirmedUnitCount,
            "statusHistory": load.statusHistory.map { statusChangeToData($0) },
            "trackingUrl": load.trackingUrl
        ]
        if let v = load.assignedUnitId   { fields["assignedUnitId"]   = v.uuidString }
        if let v = load.assignedOperatorId { fields["assignedOperatorId"] = v.uuidString }
        if let v = load.unitETA          { fields["unitETA"]           = ts(v) }
        if let v = load.assignedPriceSinIVA {
            fields["assignedPriceSinIVA"] = NSDecimalNumber(decimal: v).doubleValue
        }
        // Solo incluir campos de asignación completa cuando la carga ya está llena
        if load.status == .assigned {
            fields["status"] = load.status.rawValue
            if let v = load.assignedCarrierId { fields["assignedCarrierId"] = v.uuidString }
        }
        print("[DBG] updateLoadForCarrierConfirmation \(load.reference) fields=\(fields.keys.sorted())")
        loads.document(load.id.uuidString).updateData(fields) { error in
            if let error = error {
                let nsErr = error as NSError
                print("❌ [Firestore] updateLoadForCarrierConfirmation failed for \(load.reference): \(error.localizedDescription) (domain=\(nsErr.domain) code=\(nsErr.code))")
            } else {
                print("✅ [Firestore] updateLoadForCarrierConfirmation OK for \(load.reference)")
            }
        }
    }

    static func updateLoadFields(_ loadId: UUID, _ fields: [String: Any]) {
        loads.document(loadId.uuidString).updateData(fields) { error in
            if let error = error {
                print("❌ [Firestore] updateLoadFields failed for \(loadId): \(error.localizedDescription)")
            }
        }
    }

    static func saveUnit(_ unit: Unit) {
        units.document(unit.id.uuidString).setData(unitToData(unit))
    }

    static func updateUnitFields(_ unitId: UUID, _ fields: [String: Any]) {
        units.document(unitId.uuidString).updateData(fields)
    }

    static func deleteUnit(_ unitId: UUID) {
        units.document(unitId.uuidString).delete()
    }

    static func saveOffer(_ offer: Offer) {
        offers.document(offer.id.uuidString).setData(offerToData(offer))
    }

    static func updateOfferFields(_ offerId: UUID, _ fields: [String: Any],
                                  completion: ((Error?) -> Void)? = nil) {
        offers.document(offerId.uuidString).updateData(fields) { error in
            if let error = error {
                print("❌ [Firestore] updateOfferFields failed for \(offerId): \(error.localizedDescription)")
            }
            completion?(error)
        }
    }

    static func saveNotification(_ n: AppNotification) {
        notifs.document(n.id.uuidString).setData(notificationToData(n))
    }

    static func updateNotificationFields(_ notifId: UUID, _ fields: [String: Any]) {
        notifs.document(notifId.uuidString).updateData(fields)
    }

    static func companyToData(_ company: TransportCompany) -> [String: Any] {
        [
            "id": company.id.uuidString,
            "name": company.name,
            "contactName": company.contactName,
            "phone": company.phone,
            "email": company.email,
            "rfc": company.rfc,
            "status": company.status.rawValue,
            "createdAt": ts(company.createdAt)
        ]
    }

    static func parseCompany(from data: [String: Any]) -> TransportCompany? {
        guard let name = data["name"] as? String,
              let contactName = data["contactName"] as? String,
              let phone = data["phone"] as? String,
              let email = data["email"] as? String,
              let status = UserStatus(rawValue: data["status"] as? String ?? "") else { return nil }
        let id = uuid(data["id"]) ?? UUID()
        var company = TransportCompany(id: id, name: name, contactName: contactName,
                                       phone: phone, email: email,
                                       rfc: data["rfc"] as? String ?? "",
                                       status: status)
        company.createdAt = date(data["createdAt"])
        return company
    }

    static func phoneDigits(_ phone: String) -> String {
        phone.filter { $0.isNumber }
    }

    static func phoneIndexData(uuid: UUID, name: String, phone: String,
                               role: UserRole, status: UserStatus) -> [String: Any]? {
        let digits = phoneDigits(phone)
        guard (10...15).contains(digits.count) else { return nil }
        return [
            "phoneDigits": digits,
            "uuid": uuid.uuidString,
            "name": name,
            "role": role.rawValue,
            "status": status.rawValue
        ]
    }

    static func updateCarrierPricer(_ carrierId: UUID, pricerId: UUID?) {
        users.whereField("uuid", isEqualTo: carrierId.uuidString).getDocuments { snapshot, _ in
            guard let doc = snapshot?.documents.first else { return }
            if let pricerId {
                doc.reference.updateData(["pricerId": pricerId.uuidString])
            } else {
                doc.reference.updateData(["pricerId": FieldValue.delete()])
            }
        }
    }

    static func updateUserStatus(_ userId: UUID, status: UserStatus) {
        users.whereField("uuid", isEqualTo: userId.uuidString).getDocuments { snapshot, _ in
            guard let doc = snapshot?.documents.first else { return }
            doc.reference.updateData(["status": status.rawValue])
            if let digits = doc.data()["phoneDigits"] as? String, !digits.isEmpty {
                db.collection("users_by_phone").document(digits)
                    .updateData(["status": status.rawValue])
            }
        }
    }

    static func setLoadUrgencyAlert(_ loadId: UUID, newPrice: Decimal, allowCounterOffer: Bool) {
        var data: [String: Any] = [
            "urgentRepost": true,
            "offeredPrice": NSDecimalNumber(decimal: newPrice).doubleValue
        ]
        if allowCounterOffer {
            data["assignmentMode"] = AssignmentMode.manualConfirmation.rawValue
        }
        loads.document(loadId.uuidString).updateData(data)
    }

    static func updateUserRoutes(_ userId: UUID, routes: [CarrierRoute]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        users.document(uid).updateData(["routes": routes.map { routeToData($0) }])
    }

    static func updateUserRoutesAsync(_ userId: UUID, routes: [CarrierRoute]) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AppError", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Usuario no autenticado"])
        }
        // Switching to explicit routes: clear state/zone coverage so matching stays consistent.
        try await users.document(uid).updateData([
            "routes": routes.map { routeToData($0) },
            "coverageStates": [String](),
            "coverageZones": [String]()
        ])
    }

    static func updateUserLTL(_ userId: UUID, handlesLTL: Bool) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        users.document(uid).updateData(["handlesLTL": handlesLTL])
    }

    static func deleteUserData(_ userId: UUID) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let userRef = users.document(uid)
        userRef.getDocument { snapshot, _ in
            let data = snapshot?.data() ?? [:]
            if let companyId = data["companyId"] as? String {
                db.collection("companies").document(companyId).delete()
            }
            if let digits = data["phoneDigits"] as? String, !digits.isEmpty {
                db.collection("users_by_phone").document(digits).delete()
            }
            userRef.delete()
        }
        notifs.whereField("userId", isEqualTo: userId.uuidString)
            .getDocuments { snapshot, _ in
                snapshot?.documents.forEach { $0.reference.delete() }
            }
        offers.whereField("carrierId", isEqualTo: userId.uuidString)
            .getDocuments { snapshot, _ in
                snapshot?.documents.forEach { $0.reference.delete() }
            }
        units.whereField("ownerId", isEqualTo: userId.uuidString)
            .getDocuments { snapshot, _ in
                snapshot?.documents.forEach { $0.reference.delete() }
            }
    }

    // MARK: - Listeners

    @discardableResult
    static func listenToLoads(onChange: @escaping ([Load]) -> Void) -> ListenerRegistration {
        loads.addSnapshotListener { snapshot, _ in
            let result = snapshot?.documents.compactMap { parseLoad(from: $0.data()) } ?? []
            DispatchQueue.main.async { onChange(result) }
        }
    }

    @discardableResult
    static func listenToUnits(onChange: @escaping ([Unit]) -> Void) -> ListenerRegistration {
        units.addSnapshotListener { snapshot, _ in
            let result = snapshot?.documents.compactMap { parseUnit(from: $0.data()) } ?? []
            DispatchQueue.main.async { onChange(result) }
        }
    }

    @discardableResult
    static func listenToOffers(onChange: @escaping ([Offer]) -> Void) -> ListenerRegistration {
        offers.addSnapshotListener { snapshot, _ in
            let result = snapshot?.documents.compactMap { parseOffer(from: $0.data()) } ?? []
            DispatchQueue.main.async { onChange(result) }
        }
    }

    @discardableResult
    static func listenToNotifications(userId: UUID,
                                       onChange: @escaping ([AppNotification]) -> Void) -> ListenerRegistration {
        notifs.whereField("userId", isEqualTo: userId.uuidString)
            .addSnapshotListener { snapshot, _ in
                let result = snapshot?.documents.compactMap { parseNotification(from: $0.data()) } ?? []
                DispatchQueue.main.async { onChange(result) }
            }
    }

    @discardableResult
    static func listenToUsers(onChange: @escaping ([AppUser]) -> Void) -> ListenerRegistration {
        users.addSnapshotListener { snapshot, _ in
            let result: [AppUser] = snapshot?.documents.compactMap { doc in
                var user = parseUser(from: doc.data())
                // Document ID is the Auth UID; always wins over uuid-field fallback in parseUser.
                user?.firebaseUID = doc.documentID
                return user
            } ?? []
            DispatchQueue.main.async { onChange(result) }
        }
    }

    @discardableResult
    static func listenToOwnUser(onChange: @escaping (AppUser?) -> Void) -> ListenerRegistration {
        let uid = Auth.auth().currentUser?.uid ?? ""
        return users.document(uid).addSnapshotListener { snapshot, _ in
            var user = snapshot?.data().flatMap { parseUser(from: $0) }
            user?.firebaseUID = snapshot?.documentID ?? uid
            DispatchQueue.main.async { onChange(user) }
        }
    }

    @discardableResult
    static func listenToCompanies(onChange: @escaping ([TransportCompany]) -> Void) -> ListenerRegistration {
        db.collection("companies").addSnapshotListener { snapshot, _ in
            let result = snapshot?.documents.compactMap { parseCompany(from: $0.data()) } ?? []
            DispatchQueue.main.async { onChange(result) }
        }
    }

    static func fetchUserByPhone(_ phone: String) async -> AppUser? {
        let digits = phoneDigits(phone)
        guard (10...15).contains(digits.count) else { return nil }
        guard let snapshot = try? await db.collection("users_by_phone").document(digits).getDocument(),
              let data = snapshot.data(),
              let name = data["name"] as? String,
              let role = UserRole(rawValue: data["role"] as? String ?? ""),
              let status = UserStatus(rawValue: data["status"] as? String ?? ""),
              status == .approved,
              role != .admin,
              let id = uuid(data["uuid"]) else { return nil }
        return AppUser(id: id, name: name, email: "", phone: phone,
                       role: role, status: status)
    }
}

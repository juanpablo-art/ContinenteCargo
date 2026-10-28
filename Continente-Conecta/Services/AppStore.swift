import Foundation
import SwiftUI
import UserNotifications
import FirebaseAuth
import FirebaseFirestore

// MARK: - Carrier directory record (used by DirectorioInvitacionesView)

struct CarrierDirectoryRecord: Identifiable {
    let id: String          // 10-digit phone (Firestore document ID)
    let companyName: String
    let contactName: String
    let phone: String
    let email: String
    let baseCity: String
    let equipmentTypes: [String]
    let coverageZones: [String]
    let handlesLTL: Bool
    var status: String      // pending_invitation | sent | failed | registered
    var pricerEmail: String = ""
    /// UUID of the pricer who created this record via the invitation UI (mirrors web's invitedBy field).
    var invitedBy: String   = ""
    /// Mirrors web's followUpFor: ready | issue | waiting | failed | unsent
    var followUp: String    = "unsent"
    /// Status of the matched user account, if any: approved | pending_approval | rejected | suspended | ""
    var accountStatus: String = ""
}

// MARK: - App Store (central state)

@Observable
final class AppStore {

    // MARK: Auth
    var currentUser: AppUser?
    var isLoggedIn: Bool { currentUser != nil }
    var isDemoMode: Bool = true

    // MARK: Data collections
    var users: [AppUser] = []
    var companies: [TransportCompany] = []
    var units: [Unit] = []
    var loads: [Load] = []
    var offers: [Offer] = []
    var notifications: [AppNotification] = []

    // MARK: UI State
    var isLoading: Bool = false
    var isCheckingAuth: Bool = true   // true until startup auth check completes
    var errorMessage: String?
    var successMessage: String?
    var appColorScheme: AppColorScheme = .system

    // MARK: Firestore listeners (active in non-demo mode)
    var firestoreListeners: [ListenerRegistration] = []

    init() {
        // When running under XCTest the Firebase stack is not configured — skip it.
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil {
            isDemoMode = true
            isCheckingAuth = false
            return
        }
        #endif
        if Auth.auth().currentUser == nil {
            // No persisted Firebase session — start in demo mode immediately
            DemoDataService.seed(into: self)
            isCheckingAuth = false
        }
        // Otherwise isCheckingAuth stays true until restoreSession() finishes
    }

    // Called once from ContentView.task on app launch
    func restoreSession() async {
        guard let firebaseUser = Auth.auth().currentUser else {
            await MainActor.run { isCheckingAuth = false }
            return
        }
        do {
            if let profile = try await fetchFirestoreProfile(uid: firebaseUser.uid) {
                await MainActor.run {
                    self.currentUser = profile
                    self.isDemoMode = false
                    self.isCheckingAuth = false
                    self.startFirestoreListeners()
                }
            } else {
                // Profile missing — fall back to demo
                await MainActor.run {
                    DemoDataService.seed(into: self)
                    self.isCheckingAuth = false
                }
            }
        } catch {
            await MainActor.run {
                DemoDataService.seed(into: self)
                self.isCheckingAuth = false
            }
        }
    }

    // MARK: - Auth

    func login(email: String, password: String) -> Bool {
        // Demo: cualquier contraseña funciona para usuarios existentes
        if let user = users.first(where: { $0.email.lowercased() == email.lowercased() }) {
            currentUser = user
            return true
        }
        errorMessage = "Correo o contraseña incorrectos"
        return false
    }

    // Login real con Firebase Auth (intenta Firebase, cae a demo si no existe)
    func loginAsync(email: String, password: String) async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            let profile = try? await fetchFirestoreProfile(uid: result.user.uid)
            if let profile {
                if profile.role != .admin && profile.status != .approved {
                    try? Auth.auth().signOut()
                    await MainActor.run {
                        self.errorMessage = "Tu cuenta está pendiente de aprobación. Te notificaremos cuando sea revisada."
                        self.isLoading = false
                    }
                    return
                }
                await MainActor.run {
                    self.currentUser = profile
                    self.isDemoMode = false
                    self.isLoading = false
                    self.startFirestoreListeners()
                }
                return
            }
            // Firebase Auth ok pero sin perfil en Firestore — buscar en demo
            if let user = users.first(where: { $0.email.lowercased() == email.lowercased() }) {
                await MainActor.run { self.currentUser = user; self.isLoading = false }
            } else {
                await MainActor.run {
                    self.errorMessage = "Usuario autenticado pero sin perfil. Contacta al administrador."
                    self.isLoading = false
                }
            }
            return
        } catch let authError as NSError {
            // Si el error es de credenciales, no intentar demo — mostrar error real
            let authErrorCode = AuthErrorCode(rawValue: authError.code)
            if authErrorCode == .wrongPassword || authErrorCode == .invalidCredential
                || authErrorCode == .invalidEmail || authErrorCode == .userNotFound
                || authErrorCode == .userDisabled {
                await MainActor.run {
                    self.errorMessage = "Correo o contraseña incorrectos"
                    self.isLoading = false
                }
                return
            }
            // Otro error (red, configuración) — mostrar error, no caer a demo
            await MainActor.run {
                self.errorMessage = "Sin conexión con el servidor. Verifica tu red e intenta de nuevo."
                self.isLoading = false
            }
            return
        }
    }

    // Registro real con Firebase Auth + perfil en Firestore
    func registerWithFirebase(name: String, email: String, password: String, phone: String,
                               role: UserRole, companyName: String = "",
                               companyContact: String = "",
                               routes: [CarrierRoute] = [],
                               coverageStates: [String] = [],
                               coverageEquipmentTypes: [EquipmentType] = [],
                               handlesLTL: Bool = false,
                               handlesLocal: Bool = false,
                               handlesIntraState: Bool = false,
                               coversUSA: Bool = false,
                               coverageUSAStates: [String] = [],
                               notificationEmails: [String] = [],
                               whatsappNumbers: [String] = []) async -> Bool {
        await MainActor.run { isLoading = true; errorMessage = nil }

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let uid = result.user.uid

            // Forzar idioma español en el correo y la página de acción de Firebase
            Auth.auth().languageCode = "es"

            // Enviar correo de verificación con URL personalizada para mostrar
            // mensaje contextual en lugar de la pantalla genérica de Firebase
            let actionSettings = ActionCodeSettings()
            actionSettings.url = URL(string: "https://continente-conecta.firebaseapp.com/verificado")
            actionSettings.handleCodeInApp = false
            do {
                try await result.user.sendEmailVerification(with: actionSettings)
                print("✅ [Email] Verificación enviada a \(email)")
            } catch {
                // Reintentar sin ActionCodeSettings si falla (fallback)
                try? await result.user.sendEmailVerification()
                print("⚠️ [Email] Verificación enviada sin settings personalizados: \(error.localizedDescription)")
            }

            // Obtener el ID token para autenticar la llamada al Cloud Function.
            let idToken = try await result.user.getIDToken(forcingRefresh: true)

            let newUser: AppUser
            if role == .carrier {
                newUser = registerCarrier(name: name, email: email, phone: phone,
                                          companyName: companyName,
                                          companyContact: companyContact,
                                          routes: routes,
                                          handlesLTL: handlesLTL,
                                          handlesLocal: handlesLocal,
                                          handlesIntraState: handlesIntraState,
                                          coversUSA: coversUSA,
                                          coverageStates: coverageStates,
                                          coverageEquipmentTypes: coverageEquipmentTypes,
                                          coverageUSAStates: coverageUSAStates,
                                          notificationEmails: notificationEmails,
                                          whatsappNumbers: whatsappNumbers)
            } else {
                newUser = registerIndependentOperator(name: name, email: email, phone: phone,
                                                      routes: routes,
                                                      handlesLocal: handlesLocal,
                                                      handlesIntraState: handlesIntraState,
                                                      coversUSA: coversUSA,
                                                      coverageStates: coverageStates,
                                                      coverageEquipmentTypes: coverageEquipmentTypes,
                                                      coverageUSAStates: coverageUSAStates,
                                                      notificationEmails: notificationEmails,
                                                      whatsappNumbers: whatsappNumbers)
            }

            // Preparar datos JSON del usuario. Excluir "createdAt" (Firestore Timestamp, no
            // serializable como JSON) — el Cloud Function lo establece con serverTimestamp().
            var userData = FirestoreService.userToData(newUser)
            userData.removeValue(forKey: "createdAt")
            let digits = FirestoreService.phoneDigits(phone)
            if (10...15).contains(digits.count) {
                userData["phoneDigits"] = digits
            }

            // Para carriers, incluir datos de la empresa en el mismo payload para que el CF
            // los escriba en un batch con Admin SDK.
            if let companyId = newUser.companyId,
               let company = companies.first(where: { $0.id == companyId }) {
                var companyJson = FirestoreService.companyToData(company)
                companyJson.removeValue(forKey: "createdAt") // Set server-side
                companyJson.removeValue(forKey: "status")    // Forzado a pending_approval en CF
                userData["company"] = companyJson
            }

            // Crear perfil vía Cloud Function (Admin SDK) para evitar la carrera de
            // propagación del token de auth que causaba Permission Denied en el SDK de iOS.
            do {
                try await Self.callCloudFunction(name: "createUserProfile",
                                                  data: userData, idToken: idToken)
                print("✅ [Cloud] Perfil de \(uid) creado correctamente")
            } catch {
                // El CF falló — eliminar el usuario de Auth para evitar cuentas huérfanas.
                try? await Auth.auth().currentUser?.delete()
                throw error
            }

            await MainActor.run { self.isLoading = false }
            return true
        } catch let error as NSError {
            let authCode = error.domain == AuthErrorDomain ? AuthErrorCode(rawValue: error.code) : nil
            if authCode == .networkError || authCode == .webNetworkRequestFailed {
                if role == .carrier {
                    _ = registerCarrier(name: name, email: email, phone: phone,
                                        companyName: companyName,
                                        companyContact: companyContact,
                                        routes: routes,
                                        handlesLTL: handlesLTL,
                                        handlesLocal: handlesLocal,
                                        handlesIntraState: handlesIntraState,
                                        coversUSA: coversUSA,
                                        coverageStates: coverageStates,
                                        coverageEquipmentTypes: coverageEquipmentTypes,
                                        coverageUSAStates: coverageUSAStates)
                } else {
                    _ = registerIndependentOperator(name: name, email: email, phone: phone,
                                                    routes: routes,
                                                    handlesLocal: handlesLocal,
                                                    handlesIntraState: handlesIntraState,
                                                    coversUSA: coversUSA,
                                                    coverageStates: coverageStates,
                                                    coverageEquipmentTypes: coverageEquipmentTypes,
                                                    coverageUSAStates: coverageUSAStates)
                }
                await MainActor.run { self.isLoading = false }
                return true
            }
            let message: String
            switch authCode {
            case .emailAlreadyInUse:
                message = "Ese correo ya está registrado"
            case .weakPassword:
                message = "La contraseña debe tener al menos 6 caracteres"
            case .invalidEmail:
                message = "El correo no es válido"
            default:
                message = error.localizedDescription
            }
            await MainActor.run {
                self.errorMessage = message
                self.isLoading = false
            }
            return false
        }
    }

    private func fetchFirestoreProfile(uid: String) async throws -> AppUser? {
        let doc = try await Firestore.firestore().collection("users").document(uid).getDocument()
        guard let data = doc.data() else { return nil }
        var user = FirestoreService.parseUser(from: data)
        user?.firebaseUID = uid
        return user
    }

    func logout() {
        stopFirestoreListeners()
        try? Auth.auth().signOut()
        // Clear all in-memory data — no stale state after logout
        users = []
        companies = []
        units = []
        loads = []
        offers = []
        notifications = []
        currentUser = nil
        isDemoMode = true
        errorMessage = nil
    }

    func startFirestoreListeners() {
        guard let user = currentUser else { return }
        loads = []
        units = []
        offers = []
        notifications = []
        companies = []
        users = (user.role == .admin || user.role == .pricer) ? [] : [user]

        let l1 = FirestoreService.listenToLoads { [weak self] incoming in
            self?.loads = incoming
        }
        let l2 = FirestoreService.listenToUnits { [weak self] incoming in
            guard let self else { return }
            // Las reglas de Firestore no permiten campos extra en units, por lo que
            // isAvailabilityPosted/postedOriginState/postedDestinationState solo viven en memoria.
            // Al recibir un snapshot nuevo, preservamos esos campos del array actual.
            self.units = incoming.map { incomingUnit in
                guard let existing = self.units.first(where: { $0.id == incomingUnit.id }),
                      existing.isAvailabilityPosted else { return incomingUnit }
                var unit = incomingUnit
                unit.isAvailabilityPosted = existing.isAvailabilityPosted
                unit.postedOriginState = existing.postedOriginState
                unit.postedDestinationState = existing.postedDestinationState
                return unit
            }
        }
        let l3 = FirestoreService.listenToOffers { [weak self] incoming in
            self?.offers = incoming
        }
        let l4 = FirestoreService.listenToNotifications(userId: user.id) { [weak self] incoming in
            self?.notifications = incoming
        }
        var registrations = [l1, l2, l3, l4]
        if user.role == .admin || user.role == .pricer {
            registrations.append(FirestoreService.listenToUsers { [weak self] incoming in
                self?.users = incoming
            })
            registrations.append(FirestoreService.listenToCompanies { [weak self] incoming in
                self?.companies = incoming
            })
        } else {
            registrations.append(FirestoreService.listenToOwnUser { [weak self] incoming in
                guard let incoming else { return }
                self?.users = [incoming]
                if self?.currentUser?.id == incoming.id {
                    self?.currentUser = incoming
                }
            })
        }
        firestoreListeners = registrations
    }

    func stopFirestoreListeners() {
        firestoreListeners.forEach { $0.remove() }
        firestoreListeners.removeAll()
    }

    func switchDemoRole(to role: UserRole) {
        guard isDemoMode else { return }
        switch role {
        case .admin:
            currentUser = users.first { $0.role == .admin }
        case .carrier:
            currentUser = users.first { $0.role == .carrier }
        case .independentOperator:
            currentUser = users.first { $0.role == .independentOperator }
        case .pricer:
            currentUser = users.first { $0.role == .pricer }
        }
    }

    func registerCarrier(name: String, email: String, phone: String,
                         companyName: String, companyContact: String,
                         routes: [CarrierRoute] = [],
                         handlesLTL: Bool = false,
                         handlesLocal: Bool = false,
                         handlesIntraState: Bool = false,
                         coversUSA: Bool = false,
                         coverageStates: [String] = [],
                         coverageEquipmentTypes: [EquipmentType] = [],
                         coverageUSAStates: [String] = [],
                         notificationEmails: [String] = [],
                         whatsappNumbers: [String] = []) -> AppUser {
        let company = TransportCompany(name: companyName, contactName: companyContact,
                                       phone: phone, email: email)
        companies.append(company)
        let user = AppUser(name: name, email: email, phone: phone,
                           role: .carrier, status: .pendingApproval,
                           companyId: company.id, canNegotiateRates: true,
                           routes: routes, handlesLTL: handlesLTL,
                           handlesLocal: handlesLocal, handlesIntraState: handlesIntraState,
                           coversUSA: coversUSA,
                           coverageStates: coverageStates,
                           coverageEquipmentTypes: coverageEquipmentTypes,
                           coverageUSAStates: coverageUSAStates,
                           notificationEmails: notificationEmails,
                           whatsappNumbers: whatsappNumbers)
        users.append(user)
        return user
    }

    func registerIndependentOperator(name: String, email: String, phone: String,
                                     routes: [CarrierRoute] = [],
                                     handlesLocal: Bool = false,
                                     handlesIntraState: Bool = false,
                                     coversUSA: Bool = false,
                                     coverageStates: [String] = [],
                                     coverageEquipmentTypes: [EquipmentType] = [],
                                     coverageUSAStates: [String] = [],
                                     notificationEmails: [String] = [],
                                     whatsappNumbers: [String] = []) -> AppUser {
        let user = AppUser(name: name, email: email, phone: phone,
                           role: .independentOperator, status: .pendingApproval,
                           canNegotiateRates: true, routes: routes,
                           handlesLocal: handlesLocal, handlesIntraState: handlesIntraState,
                           coversUSA: coversUSA,
                           coverageStates: coverageStates,
                           coverageEquipmentTypes: coverageEquipmentTypes,
                           coverageUSAStates: coverageUSAStates,
                           notificationEmails: notificationEmails,
                           whatsappNumbers: whatsappNumbers)
        users.append(user)
        return user
    }

    func updateCarrierProfile(routes: [CarrierRoute]) async throws {
        guard let userId = currentUser?.id,
              let idx = users.firstIndex(where: { $0.id == userId }) else { return }
        let previousRoutes = users[idx].routes
        let previousCoverageStates = users[idx].coverageStates
        let previousCoverageZones = users[idx].coverageZones
        // Optimistic update — switch to explicit route mode, clearing state/zone coverage.
        users[idx].routes = routes
        users[idx].coverageStates = []
        users[idx].coverageZones = []
        currentUser = users[idx]
        if !isDemoMode {
            do {
                // updateData resolves on local cache write (offline persistence),
                // not server ACK. listenToOwnUser will confirm or roll back later.
                try await FirestoreService.updateUserRoutesAsync(userId, routes: routes)
            } catch {
                // Roll back optimistic update on confirmed write failure.
                if let rollbackIdx = users.firstIndex(where: { $0.id == userId }) {
                    users[rollbackIdx].routes = previousRoutes
                    users[rollbackIdx].coverageStates = previousCoverageStates
                    users[rollbackIdx].coverageZones = previousCoverageZones
                    currentUser = users[rollbackIdx]
                }
                throw error
            }
        }
    }

    func setHandlesLTL(_ value: Bool) {
        guard let userId = currentUser?.id,
              let idx = users.firstIndex(where: { $0.id == userId }) else { return }
        users[idx].handlesLTL = value
        currentUser = users[idx]
        if !isDemoMode { FirestoreService.updateUserLTL(userId, handlesLTL: value) }
    }

    // MARK: - Account deletion

    func deleteAccount() {
        guard let user = currentUser else { return }
        let userId = user.id

        // Eliminar empresa (si aplica)
        if let companyId = user.companyId {
            companies.removeAll { $0.id == companyId }
        }

        // Eliminar unidades, ofertas y notificaciones del usuario
        units.removeAll { $0.ownerId == userId || $0.ownerId == user.companyId }
        offers.removeAll { $0.carrierId == userId }
        notifications.removeAll { $0.userId == userId }

        // Desasignar cargas que estén activas a nombre del usuario
        for i in loads.indices where loads[i].assignedCarrierId == userId {
            loads[i].assignedCarrierId = nil
            loads[i].assignedUnitId = nil
            loads[i].assignedOperatorId = nil
            loads[i].status = .published
        }

        users.removeAll { $0.id == userId }
        if !isDemoMode { FirestoreService.deleteUserData(userId) }
        currentUser = nil
    }

    // MARK: - Carrier approval

    func approveCarrier(userId: UUID) {
        guard let idx = users.firstIndex(where: { $0.id == userId }) else { return }
        users[idx].status = .approved
        if !isDemoMode { FirestoreService.updateUserStatus(userId, status: .approved) }
        notify(userId: userId, type: .registrationApproved,
               title: "Registro aprobado",
               body: "Tu registro fue aprobado. Ya puedes participar en cargas.")
    }

    func rejectCarrier(userId: UUID) {
        guard let idx = users.firstIndex(where: { $0.id == userId }) else { return }
        users[idx].status = .rejected
        if !isDemoMode { FirestoreService.updateUserStatus(userId, status: .rejected) }
        notify(userId: userId, type: .registrationRejected,
               title: "Registro rechazado",
               body: "Tu solicitud de registro no fue aprobada. Contacta a Continente Cargo.")
    }

    // MARK: - Pricer

    func pricers() -> [AppUser] {
        users.filter { $0.role == .pricer && $0.isApproved }
    }

    func carriersForPricer() -> [AppUser] {
        guard let pricerId = currentUser?.id else { return [] }
        return users.filter { $0.pricerId == pricerId }
    }

    func loadsForPricer() -> [Load] {
        let carrierIds = Set(carriersForPricer().map { $0.id })
        return loads.filter { load in
            if load.status == .published { return true }
            if let assignedId = load.assignedCarrierId, carrierIds.contains(assignedId) { return true }
            return load.confirmedCarrierIds.contains(where: { carrierIds.contains($0) })
        }
    }

    private func pricerFor(carrierId: UUID) -> AppUser? {
        guard let carrier = users.first(where: { $0.id == carrierId }),
              let pricerId = carrier.pricerId else { return nil }
        return users.first(where: { $0.id == pricerId })
    }

    func assignPricerToCarrier(carrierId: UUID, pricerId: UUID?) {
        guard let idx = users.firstIndex(where: { $0.id == carrierId }) else { return }
        users[idx].pricerId = pricerId
        if !isDemoMode { FirestoreService.updateCarrierPricer(carrierId, pricerId: pricerId) }
    }

    // MARK: - Invitations

    func sendInvitations(_ contacts: [(name: String, phone: String)]) async -> Bool {
        guard !isDemoMode else { return true }
        let db = Firestore.firestore()
        let now = Date()
        let createdBy = currentUser?.id.uuidString ?? ""
        for contact in contacts {
            let ref = db.collection("invitations").document()
            do {
                try await ref.setData([
                    "name": contact.name,
                    "phone": contact.phone,
                    "createdAt": Timestamp(date: now),
                    "status": "pending",
                    "createdBy": createdBy
                ])
            } catch {
                return false
            }
        }
        return true
    }

    // MARK: - Carrier directory (bulk import + invitations)

    /// Mirrors web's directoryPhone(): strips non-digits, removes Mexican country code prefix,
    /// trims to last 10 digits. Returns "" if result is not exactly 10 digits.
    private func directoryPhone(_ phone: String) -> String {
        var d = phone.filter { $0.isNumber }
        if d.hasPrefix("521") && d.count == 13 { d = String(d.dropFirst(3)) }
        else if d.hasPrefix("52") && d.count == 12 { d = String(d.dropFirst(2)) }
        if d.count > 10 { d = String(d.suffix(10)) }
        return d.count == 10 ? d : ""
    }

    /// Status rank mirrors web's ACCOUNT_RANK (higher = overrides lower when same phone/email).
    private func statusRank(_ s: UserStatus) -> Int {
        switch s {
        case .approved:        return 1
        case .pendingApproval: return 2
        case .suspended:       return 3
        case .rejected:        return 4
        }
    }

    /// Builds phone/email → UserStatus index from all carrier/operator users (any status),
    /// using rank-based override so the highest-priority status wins on collision.
    private func buildRegistrationIndex() -> (phones: [String: UserStatus], emails: [String: UserStatus]) {
        var phoneIndex: [String: UserStatus] = [:]
        var emailIndex: [String: UserStatus] = [:]
        for user in users where user.role == .carrier || user.role == .independentOperator {
            let ph = directoryPhone(user.phone)
            if !ph.isEmpty {
                if let prev = phoneIndex[ph] {
                    if statusRank(user.status) > statusRank(prev) { phoneIndex[ph] = user.status }
                } else {
                    phoneIndex[ph] = user.status
                }
            }
            let em = user.email.trimmingCharacters(in: .whitespaces).lowercased()
            if em.contains("@") {
                if let prev = emailIndex[em] {
                    if statusRank(user.status) > statusRank(prev) { emailIndex[em] = user.status }
                } else {
                    emailIndex[em] = user.status
                }
            }
        }
        return (phoneIndex, emailIndex)
    }

    func loadCarrierDirectory() async -> [CarrierDirectoryRecord] {
        guard !isDemoMode else { return [] }
        let db = Firestore.firestore()
        let col = db.collection("carrier_preprofiles")

        // Build phone+email index from known users/companies — mirrors web's registrationIndexFromContacts()
        let (phoneIndex, emailIndex) = buildRegistrationIndex()

        func resolveRecord(phone: String, email: String, status: String) -> (followUp: String, accountStatus: String) {
            let ph = directoryPhone(phone)
            let em = email.trimmingCharacters(in: .whitespaces).lowercased()
            let matchStatus = (!ph.isEmpty ? phoneIndex[ph] : nil) ?? (em.contains("@") ? emailIndex[em] : nil)
            let acctStatus = matchStatus?.rawValue ?? ""
            if matchStatus == .approved { return ("ready",   acctStatus) }
            if matchStatus != nil       { return ("issue",   acctStatus) }
            if status == "registered"   { return ("issue",   acctStatus) }
            if status == "failed"       { return ("failed",  acctStatus) }
            if status == "sent"         { return ("waiting", acctStatus) }
            return ("unsent", acctStatus)
        }

        func parse(_ documents: [QueryDocumentSnapshot]) -> [CarrierDirectoryRecord] {
            documents.compactMap { doc -> CarrierDirectoryRecord? in
                let d = doc.data()
                guard let company = d["companyName"] as? String, !company.isEmpty else { return nil }
                let phone  = d["phone"]  as? String ?? doc.documentID
                let email  = d["email"]  as? String ?? ""
                let status = d["status"] as? String ?? "pending_invitation"
                var record = CarrierDirectoryRecord(
                    id:             doc.documentID,
                    companyName:    company,
                    contactName:    d["contactName"]    as? String   ?? "",
                    phone:          phone,
                    email:          email,
                    baseCity:       d["baseCity"]       as? String   ?? "",
                    equipmentTypes: d["equipmentTypes"] as? [String] ?? [],
                    coverageZones:  d["coverageZones"]  as? [String] ?? [],
                    handlesLTL:     d["handlesLTL"]     as? Bool     ?? false,
                    status:         status
                )
                record.pricerEmail = (d["pricerEmail"] as? String ?? "")
                    .trimmingCharacters(in: .whitespaces).lowercased()
                let resolved = resolveRecord(phone: phone, email: email, status: status)
                record.followUp     = resolved.followUp
                record.accountStatus = resolved.accountStatus
                return record
            }
        }

        do {
            // Mirrors web's fetchCarrierDirectory() + ownedByCurrentPricer():
            // fetch ALL documents, then filter client-side.
            // A Firestore query `whereField("pricerEmail", isEqualTo: "")` misses
            // documents where the field is absent entirely — those are unassigned records
            // that belong to every pricer. The web avoids this by loading all docs first.
            let snap = try await col.getDocuments()
            if currentUser?.role == .pricer, let pricerEmail = currentUser?.email, !pricerEmail.isEmpty {
                let normalizedEmail = pricerEmail.trimmingCharacters(in: .whitespaces).lowercased()
                let owned = snap.documents.filter { doc in
                    let owner = ((doc.data()["pricerEmail"] as? String) ?? "")
                        .trimmingCharacters(in: .whitespaces).lowercased()
                    return owner.isEmpty || owner == normalizedEmail
                }
                return parse(owned)
            } else {
                return parse(snap.documents)
            }
        } catch {
            print("❌ [AppStore] loadCarrierDirectory: \(error.localizedDescription)")
            return []
        }
    }

    /// Loads ALL carrier directory records without role-based filtering — used by CompetenciaView.
    func loadFullCarrierDirectory() async -> [CarrierDirectoryRecord] {
        guard !isDemoMode else { return [] }
        let db = Firestore.firestore()
        let (phoneIndex, emailIndex) = buildRegistrationIndex()
        func resolveRecord(phone: String, email: String, status: String) -> (followUp: String, accountStatus: String) {
            let ph = directoryPhone(phone)
            let em = email.trimmingCharacters(in: .whitespaces).lowercased()
            let matchStatus = (!ph.isEmpty ? phoneIndex[ph] : nil) ?? (em.contains("@") ? emailIndex[em] : nil)
            let acctStatus = matchStatus?.rawValue ?? ""
            if matchStatus == .approved { return ("ready",   acctStatus) }
            if matchStatus != nil       { return ("issue",   acctStatus) }
            if status == "registered"   { return ("issue",   acctStatus) }
            if status == "failed"       { return ("failed",  acctStatus) }
            if status == "sent"         { return ("waiting", acctStatus) }
            return ("unsent", acctStatus)
        }
        do {
            let snap = try await db.collection("carrier_preprofiles").getDocuments(source: .server)
            return snap.documents.compactMap { doc -> CarrierDirectoryRecord? in
                let d = doc.data()
                let company = d["companyName"] as? String ?? ""
                let phone  = d["phone"]  as? String ?? doc.documentID
                let email  = d["email"]  as? String ?? ""
                let status = d["status"] as? String ?? "pending_invitation"
                var record = CarrierDirectoryRecord(
                    id:             doc.documentID,
                    companyName:    company,
                    contactName:    d["contactName"]    as? String   ?? "",
                    phone:          phone,
                    email:          email,
                    baseCity:       d["baseCity"]       as? String   ?? "",
                    equipmentTypes: d["equipmentTypes"] as? [String] ?? [],
                    coverageZones:  d["coverageZones"]  as? [String] ?? [],
                    handlesLTL:     d["handlesLTL"]     as? Bool     ?? false,
                    status:         status
                )
                record.pricerEmail = FirestoreService.emailOf(d["pricerEmail"] as? String ?? "")
                record.invitedBy = (d["invitedBy"] as? String ?? "")
                let resolved = resolveRecord(phone: phone, email: email, status: status)
                record.followUp      = resolved.followUp
                record.accountStatus = resolved.accountStatus
                return record
            }
        } catch {
            print("❌ [AppStore] loadFullCarrierDirectory: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Por invitar counts (supplier_altas, mirrors pricer-pending-match.js)

    private static let nameSuffixes = [
        " S A P I DE C V", " S A S DE C V", " S A DE C V", " S DE R L DE C V", " S DE R L",
        " S A", " S C", " A C", " SA DE CV", " S DE RL DE CV", " SAPI DE CV", " SAS DE CV",
        " S DE RL", " SPR DE RL", " SA", " SC", " AC", " CV"
    ]
    private static let nameStopWords: Set<String> = [
        "TRANSPORTES", "TRANSPORTE", "FLETES", "FLETE", "LOGISTICS", "LOGISTICA", "LOGISTICO",
        "GRUPO", "AUTOTRANSPORTES", "AUTO", "EXPRESS", "CARGA", "CARGO", "SA", "DE", "CV", "RL",
        "Y", "LOS", "LAS", "DEL", "LA", "EL", "MI", "SC", "AC", "TRUCKING", "FREIGHT",
        "TRANSPORT", "LOGISTIC", "LLC", "INC"
    ]

    private func foldString(_ value: String) -> String {
        var s = value.applyingTransform(.stripDiacritics, reverse: false) ?? value
        s = s.replacingOccurrences(of: "ñ", with: "n", options: .caseInsensitive)
        s = s.uppercased()
        let cleaned = String(s.unicodeScalars.map { scalar -> Character in
            let c = Character(scalar)
            return (c.isLetter || c.isNumber) ? c : " "
        })
        return cleaned.split(separator: " ").joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private func firstToken(_ value: String) -> String {
        foldString(value).split(separator: " ").first.map(String.init) ?? ""
    }

    /// Mirrors web plainKey(): strip corporate suffixes repeatedly.
    private func plainCompanyKey(_ value: String) -> String {
        var text = foldString(value)
        var previous = ""
        while previous != text {
            previous = text
            for suffix in Self.nameSuffixes where text.hasSuffix(suffix) {
                text = String(text.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        return text
    }

    /// Mirrors web sameDirectoryName().
    private func sameDirectoryName(altaToks: [String], preToks: [String]) -> Bool {
        guard !altaToks.isEmpty, !preToks.isEmpty else { return false }
        let short = altaToks.count <= preToks.count ? altaToks : preToks
        let long  = altaToks.count <= preToks.count ? preToks : altaToks
        let prefix = short.count < long.count && zip(short, long).allSatisfy { $0 == $1 }
        if prefix && short.count >= 2 && short.contains(where: { $0.count >= 4 && !Self.nameStopWords.contains($0) }) {
            return true
        }
        if preToks.count == 1 && altaToks.count < 4 {
            let token = preToks[0]
            if token.count >= 5 && !Self.nameStopWords.contains(token) && altaToks.contains(token) {
                return true
            }
        }
        return false
    }

    private func emailFromBlob(_ value: String) -> String {
        let pattern = #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return "" }
        let range = NSRange(value.startIndex..., in: value)
        guard let match = regex.firstMatch(in: value, range: range),
              let swiftRange = Range(match.range, in: value) else { return "" }
        return String(value[swiftRange]).lowercased()
    }

    /// Returns "Por invitar" counts keyed by pricer.firebaseUID (= Auth UID).
    /// Only includes a key when `alta_pending` closed-set was readable (web shows "—" otherwise).
    /// Mirrors pendingToInvite + alreadyRegistered from pricer-pending-match.js.
    func loadToInviteCounts(directory: [CarrierDirectoryRecord]) async -> [String: Int] {
        guard !isDemoMode else { return [:] }
        let db = Firestore.firestore()
        do {
            let altasSnap = try await db.collection("supplier_altas")
                .whereField("source", isEqualTo: "sheet")
                .getDocuments(source: .server)
            let altaDocs = altasSnap.documents.map { (id: $0.documentID, data: $0.data()) }

            // registrationIndex phones/emails: approved carriers only (web)
            var regPhones = Set<String>()
            var regEmails = Set<String>()
            for user in users where (user.role == .carrier || user.role == .independentOperator) && user.isApproved {
                let ph = directoryPhone(user.phone)
                if !ph.isEmpty { regPhones.insert(ph) }
                for raw in [user.phone] + user.whatsappNumbers {
                    let p = directoryPhone(raw)
                    if !p.isEmpty { regPhones.insert(p) }
                }
                let em = FirestoreService.emailOf(user.email)
                if !em.isEmpty { regEmails.insert(em) }
                for raw in user.notificationEmails {
                    let e = FirestoreService.emailOf(raw)
                    if !e.isEmpty { regEmails.insert(e) }
                }
            }

            // registrationIndex names/entries: every preprofile companyName (web)
            var nameKeys = Set<String>()
            var nameEntries: [[String]] = []
            for record in directory {
                let plain = plainCompanyKey(record.companyName)
                let toks = plain.split(separator: " ").map(String.init).filter { !$0.isEmpty }
                let key = toks.sorted().joined(separator: " ")
                if key.count >= 4 { nameKeys.insert(key) }
                if !toks.isEmpty { nameEntries.append(toks) }
            }

            func alreadyRegistered(data: [String: Any]) -> Bool {
                if !(data["directoryPhone"] as? String ?? "").isEmpty { return true }
                let supplier = data["supplierName"] as? String ?? ""
                let chunks = supplier.components(separatedBy: CharacterSet(charactersIn: "/|"))
                var plains = chunks.map { plainCompanyKey($0) }.filter { !$0.isEmpty }
                let whole = plainCompanyKey(supplier)
                if !whole.isEmpty && !plains.contains(whole) { plains.append(whole) }
                for plain in plains {
                    let key = plain.split(separator: " ").map(String.init).filter { !$0.isEmpty }.sorted().joined(separator: " ")
                    if key.count >= 4 && nameKeys.contains(key) { return true }
                }
                let altaToks = whole.split(separator: " ").map(String.init).filter { !$0.isEmpty }
                if nameEntries.contains(where: { sameDirectoryName(altaToks: altaToks, preToks: $0) }) {
                    return true
                }
                let blob = "\(data["contactMedium"] as? String ?? "") \(data["phone"] as? String ?? "") \(data["email"] as? String ?? "")"
                let email = emailFromBlob(blob)
                let phone = directoryPhone(blob)
                return (!email.isEmpty && regEmails.contains(email)) || (!phone.isEmpty && regPhones.contains(phone))
            }

            func readerUids(from data: [String: Any]) -> [String] {
                if let readers = data["readerUids"] as? [String] { return readers }
                if let readers = data["readerUids"] as? [Any] {
                    return readers.compactMap { $0 as? String }
                }
                return []
            }

            let closedActions: Set<String> = ["invited", "removed", "blocked"]
            var counts: [String: Int] = [:]

            for pricer in pricers() {
                guard !pricer.firebaseUID.isEmpty else { continue }
                let pricerUID = pricer.firebaseUID
                let pricerToken = firstToken(pricer.name)

                // Web: if alta_pending read fails, that pricer is omitted → UI shows "—".
                // Never fall back to an empty closed set (that inflates Por invitar).
                let closedIDs: Set<String>
                do {
                    let snap = try await db.collection("alta_pending")
                        .document(pricerUID).collection("items")
                        .getDocuments(source: .server)
                    var closed = Set<String>()
                    for doc in snap.documents {
                        let action = doc.data()["action"] as? String ?? ""
                        if closedActions.contains(action) { closed.insert(doc.documentID) }
                    }
                    closedIDs = closed
                } catch {
                    print("⚠️ [AppStore] alta_pending/\(pricerUID): \(error.localizedDescription)")
                    continue
                }

                var count = 0
                for alta in altaDocs {
                    let d = alta.data
                    // unregistered(item)
                    if !(d["matchedUserId"]    as? String ?? "").isEmpty { continue }
                    if !(d["matchedCompanyId"] as? String ?? "").isEmpty { continue }
                    if !(d["directoryPhone"]   as? String ?? "").isEmpty { continue }
                    let sheetCarrier = d["sheetCarrier"] as? String ?? ""
                    if firstToken(sheetCarrier) != pricerToken { continue }
                    if d["altaStatus"] as? String == "Terminado - Bloqueado" { continue }
                    if d["claimState"] as? String == "open" { continue }
                    let readers = readerUids(from: d)
                    guard readers.contains(pricerUID) else { continue }
                    if closedIDs.contains(alta.id) { continue }
                    if alreadyRegistered(data: d) { continue }
                    count += 1
                }
                counts[pricerUID] = count
            }
            return counts
        } catch {
            print("❌ [AppStore] loadToInviteCounts: \(error.localizedDescription)")
            return [:]
        }
    }

    /// Mirrors web's inviteFromDirectory with channel='auto':
    /// creates one invitation document per available channel (WA + email if both exist).
    func inviteFromDirectory(_ records: [CarrierDirectoryRecord]) async -> (success: Int, failed: Int) {
        guard !isDemoMode else { return (records.count, 0) }
        let db = Firestore.firestore()
        let now = Timestamp(date: Date())
        let createdBy = currentUser?.id.uuidString ?? ""
        let pricerEmail = currentUser?.role == .pricer ? (currentUser?.email ?? "") : ""
        var success = 0, failed = 0

        for record in records {
            let hasPhone = !record.phone.filter({ $0.isNumber }).isEmpty
            let hasEmail = record.email.contains("@")
            var channels: [String] = []
            if hasPhone { channels.append("whatsapp") }
            if hasEmail { channels.append("email") }
            guard !channels.isEmpty else { failed += 1; continue }

            let rawName = record.contactName.isEmpty ? record.companyName : record.contactName
            let name = String(rawName.prefix(80))
            var sentChannels: [String] = []

            for chosen in channels {
                var inviteData: [String: Any] = [
                    "name":            name,
                    "phone":           record.phone,
                    "channel":         chosen,
                    "status":          "pending",
                    "createdAt":       now,
                    "createdBy":       createdBy,
                    "preProfilePhone": record.id,
                ]
                if !record.email.isEmpty { inviteData["email"] = record.email }
                if !pricerEmail.isEmpty  { inviteData["pricerEmail"] = pricerEmail }
                do {
                    try await db.collection("invitations").document().setData(inviteData)
                    sentChannels.append(chosen)
                } catch {
                    print("❌ [AppStore] invite \(chosen) \(record.phone): \(error.localizedDescription)")
                }
            }

            if sentChannels.isEmpty { failed += 1; continue }
            success += 1

            let preProfileRef = db.collection("carrier_preprofiles").document(record.id)
            var profileUpdate: [String: Any] = [
                "status":        "sent",
                "lastInvitedAt": now,
                "inviteChannel": sentChannels.joined(separator: "+"),
            ]
            if !pricerEmail.isEmpty { profileUpdate["pricerEmail"] = pricerEmail }
            do {
                try await preProfileRef.updateData(profileUpdate)
            } catch {
                print("⚠️ [AppStore] preProfile update \(record.phone): \(error.localizedDescription)")
            }
        }
        return (success, failed)
    }

    // MARK: - Carrier pre-profile lookup (for registration pre-fill)

    struct CarrierPreProfile {
        let companyName:    String
        let contactName:    String
        let email:          String
        let equipmentTypes: [String]
        let coverageZones:  [String]
        let handlesLTL:     Bool
        let handlesLocal:   Bool
    }

    func lookupCarrierPreProfile(phone: String) async -> CarrierPreProfile? {
        guard !isDemoMode else { return nil }
        let digits = phone.filter { $0.isNumber }
        guard digits.count == 10 else { return nil }
        let db = Firestore.firestore()
        do {
            let doc = try await db.collection("carrier_preprofiles").document(digits).getDocument()
            guard let data = doc.data() else { return nil }
            return CarrierPreProfile(
                companyName:    data["companyName"]    as? String   ?? "",
                contactName:    data["contactName"]    as? String   ?? "",
                email:          data["email"]          as? String   ?? "",
                equipmentTypes: data["equipmentTypes"] as? [String] ?? [],
                coverageZones:  data["coverageZones"]  as? [String] ?? [],
                handlesLTL:     data["handlesLTL"]     as? Bool     ?? false,
                handlesLocal:   data["handlesLocal"]   as? Bool     ?? false
            )
        } catch {
            return nil
        }
    }

    // MARK: - Save manual pre-profile and send invitation(s)

    func saveManualPreProfileAndInvite(
        contactName: String,
        companyName: String,
        phone: String,
        email: String,
        baseCity: String,
        equipmentTypes: [String],
        coverageZones: [String],
        handlesLTL: Bool,
        handlesLocal: Bool,
        handlesIntraState: Bool,
        coversUSA: Bool
    ) async -> Bool {
        guard !isDemoMode else { return true }
        let db  = Firestore.firestore()
        let now = Timestamp(date: Date())
        let createdBy = currentUser?.id.uuidString ?? ""

        do {
            // 1. Upsert carrier_preprofiles (merge so we don't stomp an existing record)
            if !phone.isEmpty {
                var profileData: [String: Any] = [
                    "companyName":       companyName,
                    "contactName":       contactName,
                    "phone":             phone,
                    "email":             email,
                    "baseCity":          baseCity,
                    "equipmentTypes":    equipmentTypes,
                    "coverageZones":     coverageZones,
                    "handlesLTL":        handlesLTL,
                    "handlesLocal":      handlesLocal,
                    "handlesIntraState": handlesIntraState,
                    "handlesHazmat":     false,
                    "handlesImpoExpo":   false,
                    "status":            "pending_invitation",
                    "importedAt":        now,
                ]
                if currentUser?.role == .pricer, let pe = currentUser?.email, !pe.isEmpty {
                    profileData["pricerEmail"] = pe
                }
                try await db.collection("carrier_preprofiles").document(phone).setData(profileData, merge: true)
            }

            // 2. Create invitation doc(s) — one per available channel
            let name = contactName.isEmpty ? companyName : contactName

            if !phone.isEmpty {
                var waData: [String: Any] = [
                    "name":            name,
                    "phone":           phone,
                    "channel":         "whatsapp",
                    "status":          "pending",
                    "createdAt":       now,
                    "createdBy":       createdBy,
                    "preProfilePhone": phone,
                ]
                if !email.isEmpty { waData["email"] = email }
                try await db.collection("invitations").document().setData(waData)
            }

            if !email.isEmpty {
                let emailData: [String: Any] = [
                    "name":            name,
                    "phone":           phone,
                    "email":           email,
                    "channel":         "email",
                    "status":          "pending",
                    "createdAt":       now,
                    "createdBy":       createdBy,
                    "preProfilePhone": phone,
                ]
                try await db.collection("invitations").document().setData(emailData)
            }

            return true
        } catch {
            print("❌ [AppStore] saveManualPreProfileAndInvite: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Import carrier directory (admin callable)

    func importCarrierDirectoryFromCloud() async -> (imported: Int, error: String?) {
        guard !isDemoMode else { return (0, "Demo mode") }
        guard let idToken = try? await Auth.auth().currentUser?.getIDToken() else {
            return (0, "No autenticado")
        }
        let url = URL(string: "https://us-central1-continente-conecta.cloudfunctions.net/importCarrierDirectory")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["data": [:]])
        req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let result = json?["result"] as? [String: Any]
            let count = result?["imported"] as? Int ?? 0
            return (count, nil)
        } catch {
            return (0, error.localizedDescription)
        }
    }

    // MARK: - Loads

    func publishLoad(_ load: Load) {
        print("[DBG] publishLoad \(load.reference) isDemoMode=\(isDemoMode) user=\(currentUser?.email ?? "nil") uid=\(Auth.auth().currentUser?.uid ?? "nil")")
        guard !isDemoMode else {
            errorMessage = "Estás en modo demostración. Cierra sesión e inicia sesión con tu cuenta real para publicar cargas."
            return
        }
        var newLoad = load
        newLoad.statusHistory = [StatusChange(status: .published,
                                              changedBy: load.publishedBy,
                                              changedByName: currentUser?.name ?? "Admin")]
        loads.append(newLoad)
        notifyCarriersForNewLoad(newLoad)
        FirestoreService.saveLoad(newLoad)
    }

    func cancelLoad(_ loadId: UUID, reason: String = "") {
        guard let idx = loads.firstIndex(where: { $0.id == loadId }) else { return }
        loads[idx].status = .cancelled
        appendStatusChange(loadId: loadId, status: .cancelled, notes: reason)
        for i in offers.indices where offers[i].loadId == loadId {
            offers[i].status = .cancelled
            if !isDemoMode { FirestoreService.updateOfferFields(offers[i].id, ["status": OfferStatus.cancelled.rawValue]) }
        }
        if !isDemoMode { FirestoreService.saveLoad(loads[idx]) }
    }

    func updateLoadStatus(_ loadId: UUID, status: LoadStatus, notes: String = "") {
        guard let idx = loads.firstIndex(where: { $0.id == loadId }) else { return }
        loads[idx].status = status
        appendStatusChange(loadId: loadId, status: status, notes: notes)
        if !isDemoMode { FirestoreService.saveLoad(loads[idx]) }
    }

    private func appendStatusChange(loadId: UUID, status: LoadStatus, notes: String) {
        guard let idx = loads.firstIndex(where: { $0.id == loadId }) else { return }
        let change = StatusChange(status: status,
                                  changedBy: currentUser?.id ?? UUID(),
                                  changedByName: currentUser?.name ?? "Sistema",
                                  notes: notes)
        loads[idx].statusHistory.append(change)
    }

    // MARK: - Take load (tarifa fija, atómico)

    enum TakeLoadResult {
        case success
        case alreadyAssigned
        case notApproved
        case deadlinePassed
        case noUnit
        case pendingApproval
    }

    func takeLoad(loadId: UUID, unitId: UUID?, operatorId: UUID?,
                  unitETA: Date?, trackingUrl: String = "",
                  availableUnitCount: Int = 1,
                  proposedPricePerUnit: Decimal? = nil) -> TakeLoadResult {
        guard let user = currentUser, user.isApproved else { return .notApproved }
        guard let loadIdx = loads.firstIndex(where: { $0.id == loadId }) else { return .noUnit }

        let load = loads[loadIdx]
        guard load.status == .published else { return .alreadyAssigned }
        guard Date() < load.deadline else { return .deadlinePassed }
        guard load.assignmentMode == .fixedRate else { return .alreadyAssigned }
        guard !load.isFull else { return .alreadyAssigned }
        // Para cargas de unidad única, bloquear re-confirmación del mismo carrier.
        // Para cargas multi-unidad, permitir que el mismo carrier agregue más unidades.
        guard load.unitCount > 1 || !load.confirmedCarrierIds.contains(user.id) else { return .alreadyAssigned }

        // Verificar unidad solo cuando se proporciona — en cargas multi-unidad es opcional
        var optUnitIdx: Int? = nil
        if let uid = unitId {
            guard let idx = units.firstIndex(where: { $0.id == uid }),
                  units[idx].isAvailableFor(pickupDate: load.pickupDate,
                                             deliveryDate: load.deliveryDate) else {
                return .noUnit
            }
            optUnitIdx = idx
        }

        // Registrar confirmación de este transportista (evitar duplicados en multi-unidad)
        if !loads[loadIdx].confirmedCarrierIds.contains(user.id) {
            loads[loadIdx].confirmedCarrierIds.append(user.id)
        }
        let remaining = loads[loadIdx].unitCount - loads[loadIdx].confirmedUnitCount
        loads[loadIdx].confirmedUnitCount += min(availableUnitCount, max(1, remaining))

        if let uid = unitId { loads[loadIdx].assignedUnitId = uid }
        loads[loadIdx].assignedOperatorId = operatorId
        loads[loadIdx].unitETA = unitETA
        loads[loadIdx].trackingUrl = trackingUrl
        let agreedPrice = proposedPricePerUnit ?? load.offeredPrice
        loads[loadIdx].assignedPriceSinIVA = agreedPrice
        if let idx = optUnitIdx { units[idx].status = .reserved }

        // Cerrar la carga solo cuando se completan todas las unidades
        if loads[loadIdx].isFull {
            loads[loadIdx].status = .assigned
            loads[loadIdx].assignedCarrierId = user.id
            appendStatusChange(loadId: loadId, status: .assigned,
                               notes: "Todas las unidades confirmadas (\(loads[loadIdx].unitCount)/\(loads[loadIdx].unitCount))")
        } else {
            appendStatusChange(loadId: loadId, status: .published,
                               notes: "Unidad confirmada (\(loads[loadIdx].confirmedUnitCount)/\(loads[loadIdx].unitCount))")
        }

        // Registrar oferta ganadora para que el admin vea las unidades disponibles
        var wonOffer = Offer(loadId: loadId, carrierId: user.id,
                             carrierName: user.name, unitId: unitId,
                             amount: agreedPrice, currency: load.currency,
                             proposedPrice: agreedPrice,
                             availableUnitCount: availableUnitCount)
        wonOffer.status = .won
        offers.append(wonOffer)

        if !isDemoMode {
            // updateData en lugar de setData para no borrar campos del backend (cartaInstruccion, etc.)
            let isMultiUnit = loads[loadIdx].unitCount > 1
            if loads[loadIdx].isFull || isMultiUnit {
                FirestoreService.updateLoadForCarrierConfirmation(loads[loadIdx])
            }
            if let idx = optUnitIdx { FirestoreService.saveUnit(units[idx]) }
            FirestoreService.saveOffer(wonOffer)
        }

        notify(userId: user.id, type: .loadAssigned,
               title: "¡Participación confirmada!",
               body: "Confirmaste tu unidad para el viaje \(load.reference).", loadId: loadId)

        if let opId = operatorId, opId != user.id {
            notify(userId: opId, type: .loadAssigned,
                   title: "Nuevo viaje asignado",
                   body: "Se te asignó el viaje \(load.reference). Abre la app para ver los detalles.",
                   loadId: loadId)
        }

        if let pricer = pricerFor(carrierId: user.id) {
            notify(userId: pricer.id, type: .loadAssigned,
                   title: "Transportista confirmado: \(user.name)",
                   body: "\(user.name) confirmó su unidad en el viaje \(load.reference).",
                   loadId: loadId)
        }

        return .success
    }

    // MARK: - Submit counter-offer pending admin approval

    func submitCounterOffer(loadId: UUID, unitId: UUID?, operatorId: UUID?,
                            unitETA: Date?, trackingUrl: String = "",
                            availableUnitCount: Int, proposedPricePerUnit: Decimal) -> TakeLoadResult {
        guard let user = currentUser, user.isApproved else { return .notApproved }
        guard let load = loads.first(where: { $0.id == loadId }) else { return .noUnit }
        guard load.status == .published else { return .alreadyAssigned }
        guard Date() < load.deadline else { return .deadlinePassed }

        var offer = Offer(
            loadId: loadId,
            carrierId: user.id,
            carrierName: user.name,
            unitId: unitId,
            operatorId: operatorId,
            amount: proposedPricePerUnit * Decimal(availableUnitCount),
            currency: load.currency,
            isAvailabilityOnly: false,
            proposedPrice: proposedPricePerUnit,
            availableUnitCount: availableUnitCount,
            notes: trackingUrl.isEmpty ? "" : "Rastreo: \(trackingUrl)"
        )
        offer.status = .pendingApproval
        offers.append(offer)
        if !isDemoMode { FirestoreService.saveOffer(offer) }

        return .pendingApproval
    }

    // MARK: - Counter-offer admin actions

    func approveCounterOffer(offerId: UUID) {
        guard let offerIdx = offers.firstIndex(where: { $0.id == offerId }) else { return }
        guard offers[offerIdx].status == .pendingApproval else { return }
        let offer = offers[offerIdx]

        guard let loadIdx = loads.firstIndex(where: { $0.id == offer.loadId }) else { return }

        offers[offerIdx].status = .won

        // Apply proposed price to the load
        loads[loadIdx].assignedPriceSinIVA = offer.proposedPrice ?? offer.amount

        // Confirm units
        let remaining = loads[loadIdx].unitCount - loads[loadIdx].confirmedUnitCount
        let unitsToConfirm = min(offer.availableUnitCount, max(1, remaining))
        loads[loadIdx].confirmedCarrierIds.append(offer.carrierId)
        loads[loadIdx].confirmedUnitCount += unitsToConfirm
        if let uid = offer.unitId { loads[loadIdx].assignedUnitId = uid }
        loads[loadIdx].assignedOperatorId = offer.operatorId

        if loads[loadIdx].isFull {
            loads[loadIdx].status = .assigned
            loads[loadIdx].assignedCarrierId = offer.carrierId
            appendStatusChange(loadId: offer.loadId, status: .assigned,
                               notes: "Contra-oferta aprobada por administrador")
            if !isDemoMode { FirestoreService.saveLoad(loads[loadIdx]) }
        } else {
            appendStatusChange(loadId: offer.loadId, status: .published,
                               notes: "Contra-oferta aprobada (\(loads[loadIdx].confirmedUnitCount)/\(loads[loadIdx].unitCount))")
            if !isDemoMode { FirestoreService.saveLoad(loads[loadIdx]) }
        }

        if !isDemoMode {
            FirestoreService.updateOfferFields(offerId, ["status": OfferStatus.won.rawValue])
        }

        notify(userId: offer.carrierId, type: .loadAssigned,
               title: "¡Propuesta aprobada!",
               body: "Tu contra-oferta para el viaje fue aprobada.",
               loadId: offer.loadId)
        if let pricer = pricerFor(carrierId: offer.carrierId) {
            let carrierName = offer.carrierName
            notify(userId: pricer.id, type: .loadAssigned,
                   title: "Transportista confirmado: \(carrierName)",
                   body: "\(carrierName) fue asignado al viaje \(loads[loadIdx].reference) (contra-oferta aprobada).",
                   loadId: offer.loadId)
        }
    }

    func rejectCounterOffer(offerId: UUID) {
        guard let offerIdx = offers.firstIndex(where: { $0.id == offerId }) else { return }
        guard offers[offerIdx].status == .pendingApproval else { return }

        offers[offerIdx].status = .rejected

        if !isDemoMode {
            FirestoreService.updateOfferFields(offerId, ["status": OfferStatus.rejected.rawValue])
        }
    }

    // MARK: - Update existing offer

    func updateOffer(offerId: UUID, newAmountPerUnit: Decimal, newUnitCount: Int,
                     completion: ((Error?) -> Void)? = nil) {
        guard let idx = offers.firstIndex(where: { $0.id == offerId }) else {
            completion?(nil)
            return
        }
        let editableStatuses: [OfferStatus] = [.active, .winning, .outbid, .pendingApproval]
        guard editableStatuses.contains(offers[idx].status) else {
            completion?(nil)
            return
        }
        let previous = offers[idx]
        let count = max(1, newUnitCount)
        offers[idx].proposedPrice = newAmountPerUnit
        offers[idx].amount = newAmountPerUnit * Decimal(count)
        offers[idx].availableUnitCount = count
        if isDemoMode {
            completion?(nil)
            return
        }
        FirestoreService.updateOfferFields(offerId, [
            "amount": NSDecimalNumber(decimal: offers[idx].amount).doubleValue,
            "proposedPrice": NSDecimalNumber(decimal: newAmountPerUnit).doubleValue,
            "availableUnitCount": count,
        ]) { [weak self] error in
            DispatchQueue.main.async {
                if error != nil, let self, let i = self.offers.firstIndex(where: { $0.id == offerId }) {
                    self.offers[i].proposedPrice = previous.proposedPrice
                    self.offers[i].amount = previous.amount
                    self.offers[i].availableUnitCount = previous.availableUnitCount
                }
                completion?(error)
            }
        }
    }

    // MARK: - Urgency alert

    func sendUrgencyAlert(loadId: UUID, priceIncrement: Decimal, allowCounterOffer: Bool) {
        guard let idx = loads.firstIndex(where: { $0.id == loadId }) else { return }
        if priceIncrement > 0 {
            loads[idx].offeredPrice += priceIncrement
        }
        if allowCounterOffer && loads[idx].assignmentMode == .fixedRate {
            loads[idx].assignmentMode = .reverseAuction
        }
        if !isDemoMode {
            FirestoreService.setLoadUrgencyAlert(loadId,
                                                  newPrice: loads[idx].offeredPrice,
                                                  allowCounterOffer: allowCounterOffer)
        }
    }

    // MARK: - Bids (subasta inversa)

    enum BidResult {
        case success
        case deadlinePassed
        case notApproved
        case decrementTooSmall
        case alreadyAssigned
    }

    func placeBid(loadId: UUID, amount: Decimal, unitId: UUID?, availableUnitCount: Int = 1) -> BidResult {
        guard let user = currentUser, user.isApproved else { return .notApproved }
        guard let load = loads.first(where: { $0.id == loadId }) else { return .alreadyAssigned }
        guard load.status == .published, load.assignmentMode == .reverseAuction else {
            return .alreadyAssigned
        }
        guard Date() < load.deadline else { return .deadlinePassed }

        // Si el usuario ya tiene una oferta activa
        if let existingIdx = offers.firstIndex(where: {
            $0.loadId == loadId && $0.carrierId == user.id && ($0.status == .active || $0.status == .winning)
        }) {
            let existing = offers[existingIdx]
            // Decremento mínimo aplica solo cuando se baja el precio
            if amount < existing.amount {
                guard amount <= existing.amount - load.minBidDecrement else {
                    return .decrementTooSmall
                }
            }
            offers[existingIdx].status = .cancelled
            if !isDemoMode { FirestoreService.updateOfferFields(offers[existingIdx].id, ["status": OfferStatus.cancelled.rawValue]) }
        }

        var offer = Offer(loadId: loadId, carrierId: user.id,
                          carrierName: user.name, unitId: unitId,
                          amount: amount, currency: load.currency,
                          availableUnitCount: availableUnitCount)
        offer.status = updateBidStatuses(loadId: loadId, newOffer: offer)
        offers.append(offer)
        if !isDemoMode { FirestoreService.saveOffer(offer) }
        return .success
    }

    private func updateBidStatuses(loadId: UUID, newOffer: Offer) -> OfferStatus {
        let active = offers.filter { $0.loadId == loadId && $0.status == .active || $0.status == .winning }
        let minExisting = active.map { $0.amount }.min() ?? Decimal.greatestFiniteMagnitude

        if newOffer.amount < minExisting {
            for i in offers.indices where offers[i].loadId == loadId &&
                (offers[i].status == .winning || offers[i].status == .active) {
                offers[i].status = .outbid
                if !isDemoMode { FirestoreService.updateOfferFields(offers[i].id, ["status": OfferStatus.outbid.rawValue]) }
                notify(userId: offers[i].carrierId, type: .outbid,
                       title: "Tu oferta fue superada",
                       body: "Alguien ofreció una tarifa menor para el viaje.", loadId: loadId)
            }
            return .winning
        }
        return .active
    }

    // MARK: - Close auction

    func closeAuction(loadId: UUID) {
        guard let loadIdx = loads.firstIndex(where: { $0.id == loadId }) else { return }
        let load = loads[loadIdx]
        guard load.assignmentMode == .reverseAuction else { return }

        let validOffers = offers
            .filter { $0.loadId == loadId && ($0.status == .active || $0.status == .winning) }
            .filter { offer in
                // Verificar que el transportista esté aprobado
                users.first(where: { $0.id == offer.carrierId })?.isApproved == true
            }
            .sorted { lhs, rhs in
                if lhs.amount != rhs.amount { return lhs.amount < rhs.amount }
                return lhs.submittedAt < rhs.submittedAt  // desempate por hora
            }

        if let winner = validOffers.first {
            loads[loadIdx].status = .assigned
            loads[loadIdx].assignedCarrierId = winner.carrierId
            loads[loadIdx].assignedUnitId = winner.unitId
            loads[loadIdx].assignedOperatorId = winner.operatorId

            for i in offers.indices where offers[i].loadId == loadId {
                let newStatus: OfferStatus = offers[i].id == winner.id ? .won : .lost
                offers[i].status = newStatus
                if !isDemoMode { FirestoreService.updateOfferFields(offers[i].id, ["status": newStatus.rawValue]) }
            }
            appendStatusChange(loadId: loadId, status: .assigned,
                                notes: "Subasta cerrada. Ganador: \(winner.carrierName)")
            if !isDemoMode { FirestoreService.saveLoad(loads[loadIdx]) }
            notify(userId: winner.carrierId, type: .loadAssigned,
                   title: "¡Ganaste la subasta!",
                   body: "Tu oferta ganó el viaje \(load.reference).", loadId: loadId)
            if let pricer = pricerFor(carrierId: winner.carrierId) {
                notify(userId: pricer.id, type: .loadAssigned,
                       title: "Transportista ganó subasta: \(winner.carrierName)",
                       body: "\(winner.carrierName) ganó la subasta del viaje \(load.reference).",
                       loadId: loadId)
            }
        } else {
            appendStatusChange(loadId: loadId, status: .published,
                                notes: "Subasta cerrada sin ofertas válidas")
            if !isDemoMode { FirestoreService.saveLoad(loads[loadIdx]) }
        }
    }

    // MARK: - LTL Consolidated quotes

    func submitLTLQuote(loadId: UUID, amount: Decimal, notes: String = "") -> Bool {
        guard let user = currentUser, user.isApproved else { return false }
        guard let load = loads.first(where: { $0.id == loadId }),
              load.assignmentMode == .ltlConsolidated,
              load.status == .published,
              Date() < load.deadline else { return false }
        // One submission only per carrier
        guard !offers.contains(where: { $0.loadId == loadId && $0.carrierId == user.id }) else { return false }
        var offer = Offer(loadId: loadId, carrierId: user.id,
                          carrierName: user.name, amount: amount,
                          currency: load.currency, notes: notes)
        offer.status = .active
        offers.append(offer)
        if !isDemoMode { FirestoreService.saveOffer(offer) }
        return true
    }

    func confirmLTLOffer(_ offerId: UUID) {
        guard let offerIdx = offers.firstIndex(where: { $0.id == offerId }) else { return }
        let offer = offers[offerIdx]
        guard let loadIdx = loads.firstIndex(where: { $0.id == offer.loadId }) else { return }
        let load = loads[loadIdx]

        offers[offerIdx].status = .won
        if !isDemoMode { FirestoreService.updateOfferFields(offerId, ["status": OfferStatus.won.rawValue]) }

        for i in offers.indices where offers[i].loadId == offer.loadId && offers[i].id != offerId {
            if offers[i].status == .active {
                offers[i].status = .lost
                if !isDemoMode { FirestoreService.updateOfferFields(offers[i].id, ["status": OfferStatus.lost.rawValue]) }
            }
        }

        loads[loadIdx].status = .assigned
        loads[loadIdx].assignedCarrierId = offer.carrierId
        loads[loadIdx].assignedPriceSinIVA = offer.amount
        appendStatusChange(loadId: load.id, status: .assigned,
                           notes: "Cotización LTL confirmada. Ganador: \(offer.carrierName)")
        if !isDemoMode { FirestoreService.saveLoad(loads[loadIdx]) }

        notify(userId: offer.carrierId, type: .loadAssigned,
               title: "¡Cotización aceptada!",
               body: "Tu cotización para el viaje \(load.reference) fue confirmada.", loadId: load.id)
        if let pricer = pricerFor(carrierId: offer.carrierId) {
            notify(userId: pricer.id, type: .loadAssigned,
                   title: "Transportista confirmado: \(offer.carrierName)",
                   body: "\(offer.carrierName) fue confirmado en el viaje LTL \(load.reference).",
                   loadId: load.id)
        }
    }

    func rejectLTLOffer(_ offerId: UUID) {
        guard let offerIdx = offers.firstIndex(where: { $0.id == offerId }) else { return }
        offers[offerIdx].status = .rejected
        if !isDemoMode { FirestoreService.updateOfferFields(offerId, ["status": OfferStatus.rejected.rawValue]) }
    }

    // MARK: - Availability indication (manual confirmation)

    func indicateAvailability(loadId: UUID, unitId: UUID?, proposedPrice: Decimal?) {
        guard let user = currentUser, user.isApproved else { return }
        guard let load = loads.first(where: { $0.id == loadId }) else { return }
        guard load.assignmentMode == .manualConfirmation else { return }

        let amount = proposedPrice ?? load.offeredPrice
        var offer = Offer(loadId: loadId, carrierId: user.id,
                          carrierName: user.name, unitId: unitId,
                          amount: amount, currency: load.currency,
                          isAvailabilityOnly: proposedPrice == nil, proposedPrice: proposedPrice)
        offer.status = .active
        offers.append(offer)
        if !isDemoMode { FirestoreService.saveOffer(offer) }
    }

    func assignManually(loadId: UUID, carrierId: UUID, unitId: UUID?, operatorId: UUID?) {
        guard let loadIdx = loads.firstIndex(where: { $0.id == loadId }) else { return }
        loads[loadIdx].status = .assigned
        loads[loadIdx].assignedCarrierId = carrierId
        loads[loadIdx].assignedUnitId = unitId
        loads[loadIdx].assignedOperatorId = operatorId
        appendStatusChange(loadId: loadId, status: .assigned, notes: "Asignación manual")

        for i in offers.indices where offers[i].loadId == loadId {
            let newStatus: OfferStatus = offers[i].carrierId == carrierId ? .won : .lost
            offers[i].status = newStatus
            if !isDemoMode { FirestoreService.updateOfferFields(offers[i].id, ["status": newStatus.rawValue]) }
        }
        if !isDemoMode { FirestoreService.saveLoad(loads[loadIdx]) }
        notify(userId: carrierId, type: .loadAssigned,
               title: "¡Viaje asignado!",
               body: "Se te asignó el viaje \(loads[loadIdx].reference).", loadId: loadId)
    }

    // MARK: - Units

    func addUnit(_ unit: Unit) {
        units.append(unit)
        if !isDemoMode { FirestoreService.saveUnit(unit) }
    }

    func updateUnit(_ unit: Unit) {
        guard let idx = units.firstIndex(where: { $0.id == unit.id }) else { return }
        units[idx] = unit
        if !isDemoMode { FirestoreService.saveUnit(unit) }
    }

    func deleteUnit(_ unitId: UUID) {
        units.removeAll { $0.id == unitId }
        if !isDemoMode { FirestoreService.deleteUnit(unitId) }
    }

    func postQuickAvailability(equipmentType: EquipmentType, count: Int,
                               originState: String, destinationState: String) {
        guard let user = currentUser else { return }
        let zones: [String] = destinationState.isEmpty ? [] : [destinationState]
        let unit = Unit(
            ownerId: user.companyId ?? user.id,
            equipmentType: equipmentType,
            trailerNumber: "\(count)",
            currentLocation: originState,
            coverageZones: zones,
            notes: "availability_post"
        )
        addUnit(unit)
    }

    func updateUnitStatus(_ unitId: UUID, status: UnitStatus) {
        guard let idx = units.firstIndex(where: { $0.id == unitId }) else { return }
        units[idx].status = status
        if !isDemoMode { FirestoreService.updateUnitFields(unitId, ["status": status.rawValue]) }
    }

    func postUnitAvailability(_ unitId: UUID, originState: String, destinationState: String) {
        guard let idx = units.firstIndex(where: { $0.id == unitId }) else { return }
        units[idx].postedOriginState = originState
        units[idx].postedDestinationState = destinationState
        units[idx].isAvailabilityPosted = true
        // No se persiste en Firestore: isValidUnit usa hasOnly y no permite campos extra.
        // La disponibilidad vive en memoria durante la sesión.
    }

    func removeUnitPost(_ unitId: UUID) {
        guard let idx = units.firstIndex(where: { $0.id == unitId }) else { return }
        units[idx].isAvailabilityPosted = false
        units[idx].postedOriginState = ""
        units[idx].postedDestinationState = ""
    }

    func updateUnitLocation(_ unitId: UUID, location: String) {
        guard let idx = units.firstIndex(where: { $0.id == unitId }) else { return }
        units[idx].currentLocation = location
        if !isDemoMode { FirestoreService.updateUnitFields(unitId, ["currentLocation": location]) }
    }

    // MARK: - Helpers

    func offersForLoad(_ loadId: UUID) -> [Offer] {
        offers.filter { $0.loadId == loadId }
              .sorted { $0.amount < $1.amount }
    }

    func loadsForCurrentUser() -> [Load] {
        guard let user = currentUser else { return [] }
        switch user.role {
        case .admin:
            return loads
        case .pricer:
            return loadsForPricer()
        case .carrier, .independentOperator:
            return loads.filter { load in
                if load.confirmedCarrierIds.contains(user.id) { return true }
                if load.assignedCarrierId == user.id { return true }
                guard load.status == .published && !load.isFull else { return false }
                // LTL: visible solo para carriers con handlesLTL activo
                if load.assignmentMode == .ltlConsolidated {
                    return user.handlesLTL && Date() < load.deadline
                }
                return user.coversLoad(originCity: load.originCity,
                                       originState: load.originState,
                                       destinationCity: load.destinationCity,
                                       destinationState: load.destinationState,
                                       equipmentType: load.equipmentType)
            }
        }
    }

    func myOffers() -> [Offer] {
        guard let user = currentUser else { return [] }
        // Solo ofertas activas/pendientes — las confirmadas aparecen en Mis viajes
        let pendingStatuses: Set<OfferStatus> = [.active, .winning, .outbid, .pendingApproval]
        return offers.filter { $0.carrierId == user.id && pendingStatuses.contains($0.status) }
    }

    func myTrips() -> [Load] {
        guard let user = currentUser else { return [] }
        // Incluir también cargas con ofertas ganadas (cubre casos donde confirmedCarrierIds
        // no se actualizó, p.ej. asignación vía WhatsApp bot)
        let wonLoadIds = Set(
            offers.filter { $0.carrierId == user.id && $0.status == .won }.map { $0.loadId }
        )
        return loads.filter {
            $0.assignedCarrierId == user.id
            || $0.assignedOperatorId == user.id
            || $0.confirmedCarrierIds.contains(user.id)
            || wonLoadIds.contains($0.id)
        }
    }

    /// Busca un usuario por número de teléfono normalizando dígitos (ignora espacios, guiones, etc.)
    func lookupOperator(phone: String) async -> AppUser? {
        if isDemoMode { return findUserByPhone(phone) }
        return await FirestoreService.fetchUserByPhone(phone)
    }

    func findUserByPhone(_ phone: String) -> AppUser? {
        let digits = phone.filter { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        return users.first { $0.phone.filter { $0.isNumber } == digits && $0.role != .admin }
    }

    func myUnits() -> [Unit] {
        guard let user = currentUser else { return [] }
        if user.role == .admin { return units }
        return units.filter { $0.ownerId == user.id || $0.ownerId == user.companyId }
    }

    func company(for user: AppUser) -> TransportCompany? {
        guard let companyId = user.companyId else { return nil }
        return companies.first { $0.id == companyId }
    }

    func pendingUsers() -> [AppUser] {
        users.filter { $0.status == .pendingApproval && $0.role != .admin }
    }

    func unreadNotificationCount() -> Int {
        guard let user = currentUser else { return 0 }
        return notifications.filter { $0.userId == user.id && !$0.isRead }.count
    }

    func markNotificationRead(_ id: UUID) {
        guard let idx = notifications.firstIndex(where: { $0.id == id }) else { return }
        notifications[idx].isRead = true
        if !isDemoMode { FirestoreService.updateNotificationFields(id, ["isRead": true]) }
    }

    func markAllRead() {
        guard let user = currentUser else { return }
        for i in notifications.indices where notifications[i].userId == user.id {
            notifications[i].isRead = true
            if !isDemoMode { FirestoreService.updateNotificationFields(notifications[i].id, ["isRead": true]) }
        }
    }

    private func notify(userId: UUID, type: NotificationType,
                         title: String, body: String, loadId: UUID? = nil) {
        let n = AppNotification(userId: userId, type: type,
                                title: title, body: body, loadId: loadId)
        if isDemoMode {
            notifications.append(n)
        } else {
            FirestoreService.saveNotification(n)
        }
    }

    // MARK: - Push notifications for new load

    // MARK: - Carta Instrucción

    func saveCartaInstruccion(loadId: UUID, ci: CartaInstruccion) {
        guard let idx = loads.firstIndex(where: { $0.id == loadId }) else { return }
        loads[idx].cartaInstruccion = ci
        if !isDemoMode { FirestoreService.saveLoad(loads[idx]) }
    }

    // MARK: - WhatsApp number verification

    /// Calls the `checkWhatsApp` Cloud Function to determine if a phone number
    /// is registered on WhatsApp. Returns true/false, or nil on transient error.
    /// nil means "couldn't verify" — callers should not block on nil.
    func checkWhatsApp(phone: String) async -> Bool? {
        guard let projectId = Self.firebaseProjectId, !projectId.isEmpty else { return nil }
        let region = "us-central1"
        let urlString = "https://\(region)-\(projectId).cloudfunctions.net/checkWhatsApp"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Callable protocol: wrap in {"data": ...}
        guard let body = try? JSONSerialization.data(withJSONObject: ["data": ["phone": phone]]) else { return nil }
        request.httpBody = body

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["result"] as? [String: Any],
               let hasWA = result["hasWhatsApp"] as? Bool {
                return hasWA
            }
        } catch {
            print("[WA] checkWhatsApp network error:", error)
        }
        return nil
    }

    private static let firebaseProjectId: String? = {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) else { return nil }
        return plist["PROJECT_ID"] as? String
    }()

    /// Calls any Firebase Callable Cloud Function with an explicit auth token.
    /// Throws on HTTP errors or non-200 responses; used for authenticated CF calls
    /// that bypass Firestore security rules via Admin SDK.
    private static func callCloudFunction(name: String, data: [String: Any], idToken: String) async throws {
        guard let projectId = firebaseProjectId, !projectId.isEmpty else {
            throw NSError(domain: "AppError", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Error de configuración del proyecto"])
        }
        let urlString = "https://us-central1-\(projectId).cloudfunctions.net/\(name)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "AppError", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "URL de función inválida"])
        }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        let body = try JSONSerialization.data(withJSONObject: ["data": data])
        request.httpBody = body

        let (responseData, httpResponse) = try await URLSession.shared.data(for: request)
        let statusCode = (httpResponse as? HTTPURLResponse)?.statusCode ?? 0

        guard statusCode == 200 else {
            let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any]
            let message = (json?["error"] as? [String: Any])?["message"] as? String
                ?? "Error en la función del servidor (\(statusCode))"
            throw NSError(domain: "AppError", code: statusCode,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    // MARK: - Push notifications for new load

    private func notifyCarriersForNewLoad(_ load: Load) {
        guard load.notificationChannels.inApp else { return }

        let matching = users.filter { user in
            user.role != .admin &&
            user.coversLoad(originCity: load.originCity,
                            originState: load.originState,
                            destinationCity: load.destinationCity,
                            destinationState: load.destinationState,
                            equipmentType: load.equipmentType)
        }

        for carrier in matching {
            // In-app notification (visible en la pestaña Avisos de cada transportista)
            notify(userId: carrier.id, type: .newLoad,
                   title: "Nueva carga en tu ruta",
                   body: "\(load.originDisplay) → \(load.destinationDisplay) · \(load.equipmentType.rawValue)",
                   loadId: load.id)
        }

        // Una sola notificación iOS en el dispositivo actual, solo si el usuario logueado
        // es transportista y tiene una ruta que coincide con la carga
        if let me = currentUser, me.role != .admin, matching.contains(where: { $0.id == me.id }) {
            let content = UNMutableNotificationContent()
            content.title = "Nueva carga en tu ruta"
            content.subtitle = load.equipmentType.rawValue
            content.body = "\(load.originDisplay) → \(load.destinationDisplay)"
            content.sound = .default
            content.userInfo = ["loadId": load.id.uuidString]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.5, repeats: false)
            let request = UNNotificationRequest(
                identifier: "new-load-\(load.id)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }
}

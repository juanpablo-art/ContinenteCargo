package mx.continentecargo.conecta.data

import com.google.firebase.Timestamp
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import kotlinx.coroutines.tasks.await
import java.util.Date
import java.util.UUID

class CarrierRepository(
    private val db: FirebaseFirestore = FirebaseFirestore.getInstance(),
) {
    private val registrations = mutableListOf<ListenerRegistration>()
    private var clientOwnLoads: List<FreightLoad> = emptyList()
    private var clientMarketLoads: List<FreightLoad> = emptyList()

    fun stop() {
        registrations.forEach { it.remove() }
        registrations.clear()
        clientOwnLoads = emptyList()
        clientMarketLoads = emptyList()
    }

    fun listen(
        profile: CarrierProfile,
        onLoads: (List<FreightLoad>) -> Unit,
        onOffers: (List<FreightOffer>) -> Unit,
        onUnits: (List<FleetUnit>) -> Unit,
        onNotices: (List<Notice>) -> Unit,
        onPasses: (Set<String>, Set<String>) -> Unit,
        onProfile: (CarrierProfile?) -> Unit,
        onDirectory: (List<CarrierProfile>) -> Unit,
        onClaims: (Set<String>) -> Unit,
        onError: (String) -> Unit,
    ) {
        stop()
        when (profile.role) {
            "client" -> listenClient(profile, onLoads, onUnits, onClaims, onError)
            "admin", "pricer" -> listenStaff(onLoads, onOffers, onUnits, onDirectory, onError)
            else -> listenCarrier(profile, onLoads, onOffers, onUnits, onPasses, onError)
        }
        if (profile.role == "client" || profile.role in Catalog.carrierRoles) {
            onDirectory(emptyList())
        }
        if (profile.role != "client") onClaims(emptySet())
        if (profile.role != "carrier" && profile.role != "independent_operator") {
            onPasses(emptySet(), emptySet())
        }
        if (profile.role == "client") onOffers(emptyList())
        listenNotices(profile, onNotices, onError)
        registrations += db.collection("users").document(profile.authUid)
            .addSnapshotListener { snap, _ ->
                if (snap == null || !snap.exists()) {
                    onProfile(null)
                } else {
                    onProfile(parseProfile(profile.authUid, snapshotMap(snap.data)))
                }
            }
    }

    private fun listenCarrier(
        profile: CarrierProfile,
        onLoads: (List<FreightLoad>) -> Unit,
        onOffers: (List<FreightOffer>) -> Unit,
        onUnits: (List<FleetUnit>) -> Unit,
        onPasses: (Set<String>, Set<String>) -> Unit,
        onError: (String) -> Unit,
    ) {
        registrations += db.collection("loads").addSnapshotListener { snap, error ->
            if (error != null) {
                onError("No se pudieron cargar las cargas.")
                return@addSnapshotListener
            }
            onLoads(snap?.documents?.mapNotNull { parseLoad(it.id, snapshotMap(it.data)) }.orEmpty())
        }
        listenOffers(onOffers, onError)
        listenUnits(onUnits, onError)
        registrations += db.collection("load_passes")
            .whereEqualTo("carrierId", profile.uuid)
            .addSnapshotListener { snap, error ->
                if (error != null) return@addSnapshotListener
                val routes = mutableSetOf<String>()
                val loads = mutableSetOf<String>()
                snap?.documents?.forEach { doc ->
                    val data = doc.data ?: return@forEach
                    val reason = data["reason"] as? String
                    if (reason == "sin_dispo") {
                        (data["loadId"] as? String)?.takeIf { it.isNotBlank() }?.let(loads::add)
                    } else {
                        val origin = data["originState"] as? String
                        val destination = data["destinationState"] as? String
                        val equipment = data["equipmentType"] as? String
                        if (origin != null && destination != null && equipment != null) {
                            routes += "$origin|$destination|$equipment"
                        }
                    }
                }
                onPasses(routes, loads)
            }
    }

    private fun listenStaff(
        onLoads: (List<FreightLoad>) -> Unit,
        onOffers: (List<FreightOffer>) -> Unit,
        onUnits: (List<FleetUnit>) -> Unit,
        onDirectory: (List<CarrierProfile>) -> Unit,
        onError: (String) -> Unit,
    ) {
        registrations += db.collection("loads").addSnapshotListener { snap, error ->
            if (error != null) {
                onError("No se pudieron cargar las cargas.")
                return@addSnapshotListener
            }
            onLoads(snap?.documents?.mapNotNull { parseLoad(it.id, snapshotMap(it.data)) }.orEmpty())
        }
        listenOffers(onOffers, onError)
        listenUnits(onUnits, onError)
        registrations += db.collection("users").addSnapshotListener { snap, error ->
            if (error != null) {
                onError("No se pudo cargar el directorio.")
                return@addSnapshotListener
            }
            onDirectory(
                snap?.documents
                    ?.mapNotNull { parseProfile(it.id, snapshotMap(it.data)) }
                    ?.sortedBy { it.name.lowercase() }
                    .orEmpty(),
            )
        }
    }

    private fun listenClient(
        profile: CarrierProfile,
        onLoads: (List<FreightLoad>) -> Unit,
        onUnits: (List<FleetUnit>) -> Unit,
        onClaims: (Set<String>) -> Unit,
        onError: (String) -> Unit,
    ) {
        fun emitLoads() {
            val merged = LinkedHashMap<String, FreightLoad>()
            clientMarketLoads.forEach { merged[it.id] = it }
            clientOwnLoads.forEach { merged[it.id] = it }
            onLoads(merged.values.toList())
        }
        registrations += db.collection("loads")
            .whereEqualTo("publishedBy", profile.uuid)
            .addSnapshotListener { snap, error ->
                if (error != null) {
                    onError("No se pudieron cargar las cargas.")
                    return@addSnapshotListener
                }
                clientOwnLoads = snap?.documents?.mapNotNull { parseLoad(it.id, snapshotMap(it.data)) }.orEmpty()
                emitLoads()
            }
        registrations += db.collection("loads")
            .whereEqualTo("status", "Publicado")
            .addSnapshotListener { snap, error ->
                if (error != null) {
                    onError("No se pudieron cargar las oportunidades.")
                    return@addSnapshotListener
                }
                clientMarketLoads = snap?.documents?.mapNotNull { parseLoad(it.id, snapshotMap(it.data)) }.orEmpty()
                emitLoads()
            }
        registrations += db.collection("units")
            .whereEqualTo("notes", "availability_post")
            .addSnapshotListener { snap, error ->
                if (error != null) {
                    onError("No se pudieron cargar las unidades.")
                    return@addSnapshotListener
                }
                onUnits(
                    snap?.documents
                        ?.mapNotNull { parseUnit(it.id, snapshotMap(it.data)) }
                        ?.filter { it.notes == "availability_post" && it.status == "Disponible" }
                        .orEmpty(),
                )
            }
        registrations += db.collection("client_interests")
            .whereEqualTo("clientId", profile.uuid)
            .addSnapshotListener { snap, error ->
                if (error != null) return@addSnapshotListener
                onClaims(snap?.documents?.mapNotNull { it.getString("unitId") }?.toSet().orEmpty())
            }
    }

    private fun listenOffers(onOffers: (List<FreightOffer>) -> Unit, onError: (String) -> Unit) {
        registrations += db.collection("offers").addSnapshotListener { snap, error ->
            if (error != null) {
                onError("No se pudieron cargar las ofertas.")
                return@addSnapshotListener
            }
            onOffers(snap?.documents?.mapNotNull { parseOffer(it.id, snapshotMap(it.data)) }.orEmpty())
        }
    }

    private fun listenUnits(onUnits: (List<FleetUnit>) -> Unit, onError: (String) -> Unit) {
        registrations += db.collection("units").addSnapshotListener { snap, error ->
            if (error != null) {
                onError("No se pudieron cargar las unidades.")
                return@addSnapshotListener
            }
            onUnits(snap?.documents?.mapNotNull { parseUnit(it.id, snapshotMap(it.data)) }.orEmpty())
        }
    }

    private fun listenNotices(
        profile: CarrierProfile,
        onNotices: (List<Notice>) -> Unit,
        onError: (String) -> Unit,
    ) {
        registrations += db.collection("notifications")
            .whereEqualTo("userId", profile.uuid)
            .addSnapshotListener { snap, error ->
                if (error != null) {
                    onError("No se pudieron cargar los avisos.")
                    return@addSnapshotListener
                }
                onNotices(
                    snap?.documents
                        ?.mapNotNull { parseNotice(it.id, snapshotMap(it.data)) }
                        ?.sortedByDescending { it.createdAt.time }
                        .orEmpty(),
                )
            }
    }

    suspend fun takeLoad(
        profile: CarrierProfile,
        load: FreightLoad,
        unitId: String?,
        operatorId: String?,
        unitEta: Date,
        trackingUrl: String,
        unitCount: Int,
        pricePerUnit: Double,
    ): String {
        if (profile.status != "approved") return "notApproved"
        if (load.status != "Publicado") return "alreadyAssigned"
        if (!Date().before(load.deadline)) return "deadlinePassed"
        if (load.assignmentMode != "Tarifa Fija" || isFull(load)) return "alreadyAssigned"
        if (load.unitCount <= 1 && profile.uuid in load.confirmedCarrierIds) return "alreadyAssigned"
        if (unitCount < 1 || unitCount > load.placesLeft) return "notEnoughUnits"
        val offerId = UUID.randomUUID().toString()
        val agreed = if (pricePerUnit > 0) pricePerUnit else load.offeredPrice
        val offer = FreightOffer(
            id = offerId,
            loadId = load.id,
            carrierId = profile.uuid,
            carrierName = profile.name,
            unitId = unitId,
            operatorId = operatorId,
            amount = agreed,
            currency = load.currency,
            isAvailabilityOnly = false,
            proposedPrice = agreed,
            availableUnitCount = unitCount,
            status = "Ganadora",
            submittedAt = Date(),
            notes = "",
            staffCounterPrice = null,
            staffCounterByName = null,
            staffCounterBy = null,
            staffCounterStatus = null,
        )
        val tx = db.runTransaction { transaction ->
            val loadRef = db.collection("loads").document(load.id)
            val offerRef = db.collection("offers").document(offer.id)
            val unitRef = unitId?.let { db.collection("units").document(it) }
            val loadSnap = transaction.get(loadRef)
            if (!loadSnap.exists()) return@runTransaction "closed"
            val data = loadSnap.data ?: return@runTransaction "closed"
            if (data["status"] != "Publicado") return@runTransaction "closed"
            val deadline = data["deadline"].asDate()
            if (!deadline.after(Date())) return@runTransaction "closed"
            val total = data["unitCount"].asInt(1)
            val confirmed = data["confirmedUnitCount"].asInt(0)
            val left = total - confirmed
            if (left <= 0 || unitCount > left) return@runTransaction "notEnough"
            if (unitRef != null) {
                val unitSnap = transaction.get(unitRef)
                if (!unitSnap.exists() || unitSnap.getString("status") != "Disponible") {
                    return@runTransaction "noUnit"
                }
            }
            val next = confirmed + unitCount
            val full = next >= total
            val carriers = data["confirmedCarrierIds"].asStringList().toMutableList()
            if (profile.uuid !in carriers) carriers += profile.uuid
            val history = (data["statusHistory"] as? List<*>).orEmpty().toMutableList()
            history += mapOf(
                "id" to offer.id,
                "status" to if (full) "Asignado" else "Publicado",
                "changedBy" to profile.uuid,
                "changedByName" to profile.name,
                "changedAt" to Timestamp(Date()),
                "notes" to if (full) {
                    "Todas las unidades confirmadas ($next/$total)"
                } else {
                    "Unidad confirmada ($next/$total)"
                },
            )
            val update = mutableMapOf<String, Any>(
                "confirmedCarrierIds" to carriers,
                "confirmedUnitCount" to next,
                "statusHistory" to history,
                "trackingUrl" to trackingUrl,
                "assignedPriceSinIVA" to agreed,
                "unitETA" to Timestamp(unitEta),
            )
            if (!unitId.isNullOrBlank()) update["assignedUnitId"] = unitId
            if (!operatorId.isNullOrBlank()) update["assignedOperatorId"] = operatorId
            if (full) {
                update["status"] = "Asignado"
                update["assignedCarrierId"] = profile.uuid
            }
            transaction.update(loadRef, update)
            transaction.set(offerRef, offer.toWriteMap())
            "success"
        }.await()
        if (tx == "success" && !unitId.isNullOrBlank()) {
            runCatching {
                db.collection("units").document(unitId).update("status", "Reservada").await()
            }
            runCatching {
                notify(
                    profile.uuid,
                    "load_assigned",
                    "¡Participación confirmada!",
                    "Confirmaste $unitCount de ${load.unitCount} unidades para el viaje ${load.reference}.",
                    load.id,
                )
            }
        }
        return tx
    }

    suspend fun submitCounter(
        profile: CarrierProfile,
        load: FreightLoad,
        unitId: String?,
        operatorId: String?,
        trackingUrl: String,
        unitCount: Int,
        pricePerUnit: Double,
    ): String {
        if (profile.status != "approved") return "notApproved"
        if (load.status != "Publicado") return "alreadyAssigned"
        if (!Date().before(load.deadline)) return "deadlinePassed"
        if (unitCount < 1 || unitCount > load.placesLeft) return "notEnoughUnits"
        val offer = FreightOffer(
            id = UUID.randomUUID().toString(),
            loadId = load.id,
            carrierId = profile.uuid,
            carrierName = profile.name,
            unitId = unitId,
            operatorId = operatorId,
            amount = pricePerUnit * unitCount,
            currency = load.currency,
            isAvailabilityOnly = false,
            proposedPrice = pricePerUnit,
            availableUnitCount = unitCount,
            status = "PendienteAprobacion",
            submittedAt = Date(),
            notes = if (trackingUrl.isBlank()) "" else "Rastreo: $trackingUrl",
            staffCounterPrice = null,
            staffCounterByName = null,
            staffCounterBy = null,
            staffCounterStatus = null,
        )
        db.collection("offers").document(offer.id).set(offer.toWriteMap()).await()
        return "pendingApproval"
    }

    suspend fun placeBid(
        profile: CarrierProfile,
        load: FreightLoad,
        offers: List<FreightOffer>,
        amount: Double,
        unitId: String?,
        unitCount: Int,
    ): String {
        if (profile.status != "approved") return "notApproved"
        if (load.status != "Publicado" || load.assignmentMode != "Subasta Inversa") return "alreadyAssigned"
        if (!Date().before(load.deadline)) return "deadlinePassed"
        if (amount <= 0) return "amountRequired"
        val rivals = offers.filter {
            it.loadId == load.id &&
                it.carrierId != profile.uuid &&
                (it.status == "Activa" || it.status == "Ganando")
        }
        val best = rivals.minOfOrNull { it.amount } ?: Double.POSITIVE_INFINITY
        val step = load.minBidDecrement
        if (best.isFinite() && amount > best - step) return "decrementTooSmall"
        val own = offers.filter {
            it.loadId == load.id &&
                it.carrierId == profile.uuid &&
                (it.status == "Activa" || it.status == "Ganando")
        }
        if (own.any { previous -> amount < previous.amount && amount > previous.amount - step }) {
            return "decrementTooSmall"
        }
        own.forEach { previous ->
            db.collection("offers").document(previous.id).update("status", "Cancelada").await()
        }
        val remaining = offers.filter {
            it.loadId == load.id &&
                it.id !in own.map { bid -> bid.id }.toSet() &&
                (it.status == "Activa" || it.status == "Ganando")
        }
        val floor = remaining.minOfOrNull { it.amount } ?: Double.POSITIVE_INFINITY
        val status = if (amount < floor) {
            remaining.forEach { rival ->
                db.collection("offers").document(rival.id).update("status", "Superada").await()
                runCatching {
                    notify(
                        rival.carrierId,
                        "outbid",
                        "Tu oferta fue superada",
                        "Alguien ofreció una tarifa menor para el viaje.",
                        load.id,
                    )
                }
            }
            "Ganando"
        } else {
            "Activa"
        }
        val offer = FreightOffer(
            id = UUID.randomUUID().toString(),
            loadId = load.id,
            carrierId = profile.uuid,
            carrierName = profile.name,
            unitId = unitId,
            operatorId = null,
            amount = amount,
            currency = load.currency,
            isAvailabilityOnly = false,
            proposedPrice = null,
            availableUnitCount = unitCount.coerceAtLeast(1),
            status = status,
            submittedAt = Date(),
            notes = "",
            staffCounterPrice = null,
            staffCounterByName = null,
            staffCounterBy = null,
            staffCounterStatus = null,
        )
        db.collection("offers").document(offer.id).set(offer.toWriteMap()).await()
        return "success"
    }

    suspend fun indicateAvailability(
        profile: CarrierProfile,
        load: FreightLoad,
        unitId: String?,
        customPrice: Double?,
    ) {
        if (profile.status != "approved") error("Tu cuenta aún no está aprobada.")
        if (load.assignmentMode != "Confirmación Manual" || load.status != "Publicado") {
            error("Esta carga ya no recibe disponibilidad.")
        }
        val price = customPrice ?: load.offeredPrice
        val offer = FreightOffer(
            id = UUID.randomUUID().toString(),
            loadId = load.id,
            carrierId = profile.uuid,
            carrierName = profile.name,
            unitId = unitId,
            operatorId = null,
            amount = price,
            currency = load.currency,
            isAvailabilityOnly = customPrice == null,
            proposedPrice = customPrice,
            availableUnitCount = 1,
            status = "Activa",
            submittedAt = Date(),
            notes = "",
            staffCounterPrice = null,
            staffCounterByName = null,
            staffCounterBy = null,
            staffCounterStatus = null,
        )
        db.collection("offers").document(offer.id).set(offer.toWriteMap()).await()
    }

    suspend fun submitLtl(profile: CarrierProfile, load: FreightLoad, amount: Double, notes: String): Boolean {
        if (profile.status != "approved" || !profile.handlesLTL) return false
        if (load.assignmentMode != "Consolidada LTL" || load.status != "Publicado") return false
        if (!Date().before(load.deadline)) return false
        val offer = FreightOffer(
            id = UUID.randomUUID().toString(),
            loadId = load.id,
            carrierId = profile.uuid,
            carrierName = profile.name,
            unitId = null,
            operatorId = null,
            amount = amount,
            currency = load.currency,
            isAvailabilityOnly = false,
            proposedPrice = null,
            availableUnitCount = 1,
            status = "Activa",
            submittedAt = Date(),
            notes = notes,
            staffCounterPrice = null,
            staffCounterByName = null,
            staffCounterBy = null,
            staffCounterStatus = null,
        )
        db.collection("offers").document(offer.id).set(offer.toWriteMap()).await()
        return true
    }

    suspend fun updateOffer(offer: FreightOffer, price: Double, units: Int) {
        val count = units.coerceAtLeast(1)
        db.collection("offers").document(offer.id).update(
            mapOf(
                "proposedPrice" to price,
                "amount" to price * count,
                "availableUnitCount" to count,
            ),
        ).await()
    }

    suspend fun answerCounter(profile: CarrierProfile, offer: FreightOffer, decision: String) {
        if (offer.carrierId != profile.uuid) error("Solo el transportista puede responder.")
        if (offer.status != "PendienteAprobacion" || offer.staffCounterStatus != "PendienteTransportista") {
            error("Esta contra propuesta ya no está pendiente.")
        }
        db.collection("offers").document(offer.id).update("staffCounterStatus", decision).await()
        val staff = offer.staffCounterBy
        if (!staff.isNullOrBlank()) {
            val label = formatMoney(offer.staffCounterPrice ?: 0.0, offer.currency)
            notify(
                staff,
                "status_changed",
                if (decision == "Aceptada") "Contra propuesta aceptada" else "Contra propuesta rechazada",
                if (decision == "Aceptada") {
                    "${profile.name} aceptó $label por unidad. El viaje se asigna con ese precio."
                } else {
                    "${profile.name} no aceptó la contra propuesta. Su oferta original sigue pendiente."
                },
                offer.loadId,
            )
        }
    }

    suspend fun updateTripStatus(profile: CarrierProfile, load: FreightLoad, status: String) {
        val event = StatusEvent(
            id = UUID.randomUUID().toString(),
            status = status,
            changedBy = profile.uuid,
            changedByName = profile.name,
            changedAt = Date(),
            notes = "",
        )
        val history = (load.statusHistory + event).map { it.toMap() }
        db.collection("loads").document(load.id).update(
            mapOf(
                "status" to status,
                "statusHistory" to history,
            ),
        ).await()
    }

    suspend fun saveUnit(unit: FleetUnit) {
        db.collection("units").document(unit.id).set(unit.toWriteMap()).await()
    }

    suspend fun deleteUnit(id: String) {
        db.collection("units").document(id).delete().await()
    }

    suspend fun setUnitStatus(id: String, status: String) {
        db.collection("units").document(id).update("status", status).await()
    }

    suspend fun updateProfile(profile: CarrierProfile, name: String, phone: String) {
        val cleanName = name.trim()
        val cleanPhone = phone.trim()
        if (cleanName.isEmpty() || cleanName.length > 80) error("Escribe un nombre de hasta 80 caracteres.")
        if (cleanPhone.length > 30) error("El teléfono es demasiado largo.")
        val digits = cleanPhone.filter { it.isDigit() }
        val update = mutableMapOf<String, Any>(
            "name" to cleanName,
            "phone" to cleanPhone,
        )
        if (digits.length in 10..15) {
            update["phoneDigits"] = digits
        } else {
            update["phoneDigits"] = FieldValue.delete()
        }
        db.collection("users").document(profile.authUid).update(update).await()
    }

    suspend fun setFlag(profile: CarrierProfile, field: String, value: Boolean) {
        db.collection("users").document(profile.authUid).update(field, value).await()
    }

    suspend fun saveClientPreferences(
        profile: CarrierProfile,
        routes: List<RouteCoverage>,
        equipment: List<String>,
    ) {
        val clean = routes
            .filter { it.originState.isNotBlank() && it.destinationState.isNotBlank() && it.originState != it.destinationState }
            .take(12)
            .map { it.copy(equipmentTypes = emptyList()) }
        val gear = equipment.distinct().take(11)
        db.collection("users").document(profile.authUid).update(
            mapOf(
                "routes" to clean.map { it.toMap() },
                "coverageEquipmentTypes" to gear,
                "coverageStates" to emptyList<String>(),
                "coverageZones" to emptyList<String>(),
            ),
        ).await()
    }

    suspend fun claimRoute(profile: CarrierProfile, unit: FleetUnit) {
        val origin = (unit.currentLocation.ifBlank { unit.postedOriginState.orEmpty() }).take(40)
        val destination = (unit.coverageZones.firstOrNull() ?: unit.postedDestinationState.orEmpty()).take(40)
        if (origin.isBlank() || destination.isBlank()) error("Esa unidad no tiene ruta publicada.")
        val id = UUID.randomUUID().toString()
        db.collection("client_interests").document(id).set(
            mapOf(
                "id" to id,
                "clientId" to profile.uuid,
                "clientName" to profile.name.take(80),
                "unitId" to unit.id,
                "originState" to origin,
                "destinationState" to destination,
                "equipmentType" to unit.equipmentType.take(40),
                "status" to "interested",
                "createdAt" to Timestamp.now(),
            ),
        ).await()
    }

    suspend fun saveRoutes(profile: CarrierProfile, routes: List<RouteCoverage>) {
        db.collection("users").document(profile.authUid).update(
            mapOf(
                "routes" to routes.map { it.toMap() },
                "coverageStates" to emptyList<String>(),
                "coverageZones" to emptyList<String>(),
            ),
        ).await()
    }

    suspend fun markRead(id: String) {
        db.collection("notifications").document(id).update("isRead", true).await()
    }

    suspend fun markAllRead(notices: List<Notice>) {
        notices.filter { !it.isRead }.forEach { notice ->
            runCatching { markRead(notice.id) }
        }
    }

    suspend fun lookupOperator(phone: String): String? {
        val digits = phone.filter { it.isDigit() }
        if (digits.length !in 10..15) return null
        val snap = db.collection("users_by_phone").document(digits).get().await()
        if (!snap.exists()) return null
        val data = snap.data ?: return null
        val status = data["status"] as? String
        val role = data["role"] as? String
        val uuid = data["uuid"] as? String
        if (status != "approved" || role == "admin" || role == "client" || uuid.isNullOrBlank()) return null
        return uuid
    }

    suspend fun postAvailability(profile: CarrierProfile, equipment: String, count: Int, origin: String, destination: String) {
        if (profile.role !in Catalog.carrierRoles) error("Solo un transportista puede publicar disponibilidad.")
        if (count < 1) error("Indica al menos una unidad.")
        if (origin !in Catalog.mexicoStates && origin !in Catalog.usaStates) error("Elige el estado de origen.")
        if (destination !in Catalog.mexicoStates && destination !in Catalog.usaStates) error("Elige el estado de destino.")
        saveUnit(availabilityUnit(profile, equipment, count, origin, destination))
    }

    suspend fun saveTariff(profile: CarrierProfile, rows: List<TariffRow>) {
        if (profile.role !in Catalog.carrierRoles || profile.status != "approved") {
            error("Solo un transportista aprobado puede cargar su tarifario.")
        }
        val phone = tariffPhone(profile)
        if (profile.uuid.isBlank() || phone == null) {
            error("Tu perfil necesita teléfono y folio de transportista antes de guardar tarifas.")
        }
        val clean = rows.mapNotNull {
            sanitizeTariffRow(it.origin, it.destination, it.equipment, it.amount, it.currency, it.basis, it.notes, it.source)
        }.take(300)
        val source = if (clean.any { it.source == "archivo" }) "archivo" else "manual"
        db.collection("carrier_tariffs").document(profile.authUid).set(
            mapOf(
                "carrierUid" to profile.authUid,
                "carrierUuid" to profile.uuid,
                "phone" to phone,
                "label" to profile.name.trim().take(120).ifBlank { "Transportista" },
                "fileName" to "",
                "source" to source,
                "rowCount" to clean.size,
                "updatedAt" to Timestamp.now(),
                "rows" to clean.map { row ->
                    mapOf(
                        "origin" to row.origin,
                        "destination" to row.destination,
                        "equipment" to row.equipment,
                        "amount" to row.amount,
                        "currency" to row.currency,
                        "basis" to row.basis,
                        "notes" to row.notes,
                        "source" to row.source,
                    )
                },
            ),
        ).await()
    }

    suspend fun loadTariffs(profile: CarrierProfile): List<TariffBook> {
        return if (profile.role == "admin" || profile.role == "pricer") {
            val snap = db.collection("carrier_tariffs").get().await()
            snap.documents.mapNotNull { parseTariff(it.id, snapshotMap(it.data)) }
                .sortedBy { it.label.lowercase() }
        } else {
            val snap = db.collection("carrier_tariffs").document(profile.authUid).get().await()
            if (!snap.exists()) emptyList() else listOfNotNull(parseTariff(snap.id, snapshotMap(snap.data)))
        }
    }

    suspend fun publishClientLoad(profile: CarrierProfile, input: ClientPublish) {
        val issue = clientPublishError(profile, input) ?: run {
            val id = UUID.randomUUID().toString()
            val stamp = input.pickupDay.replace("-", "")
            val reference = "CC-$stamp-${(100..999).random()}"
            val document = clientLoadDocument(profile, input, id, reference)
                ?: error("La fecha de recolección no es válida.")
            db.collection("loads").document(id).set(document).await()
            null
        }
        if (issue != null) error(issue)
    }

    suspend fun approveCounter(profile: CarrierProfile, offer: FreightOffer) {
        if (profile.role != "admin") error("Solo un administrador puede aprobar la contra-oferta.")
        val offerSnap = db.collection("offers").document(offer.id).get().await()
        val offerData = offerSnap.data ?: return
        if (offerData["status"] != "PendienteAprobacion") return
        val loadId = offerData["loadId"] as? String ?: offer.loadId
        val loadSnap = db.collection("loads").document(loadId).get().await()
        val loadData = loadSnap.data ?: return
        val total = loadData["unitCount"].asInt(1)
        val confirmed = loadData["confirmedUnitCount"].asInt(0)
        val left = total - confirmed
        if (left <= 0) return
        val asked = offerData["availableUnitCount"].asInt(offer.availableUnitCount).coerceAtLeast(1)
        val taken = minOf(asked, left)
        val price = (offerData["proposedPrice"] as? Number)?.toDouble()
            ?: (offerData["amount"] as? Number)?.toDouble()
            ?: offer.amount
        val carriers = loadData["confirmedCarrierIds"].asStringList().toMutableList()
        val carrierId = offerData["carrierId"] as? String ?: offer.carrierId
        if (carrierId !in carriers) carriers += carrierId
        val nextConfirmed = confirmed + taken
        val full = nextConfirmed >= total
        val history = (loadData["statusHistory"].asHistoryMaps()).toMutableList()
        history += mapOf(
            "id" to UUID.randomUUID().toString(),
            "status" to if (full) "Asignado" else "Publicado",
            "changedBy" to profile.uuid,
            "changedByName" to profile.name.ifBlank { "Admin" },
            "changedAt" to Timestamp.now(),
            "notes" to if (full) {
                "Contra-oferta aprobada por administrador"
            } else {
                "Contra-oferta aprobada ($nextConfirmed/$total)"
            },
        )
        val loadUpdate = mutableMapOf<String, Any>(
            "assignedPriceSinIVA" to price,
            "confirmedCarrierIds" to carriers,
            "confirmedUnitCount" to nextConfirmed,
            "statusHistory" to history,
        )
        val unitId = offerData["unitId"] as? String
        val operatorId = offerData["operatorId"] as? String
        if (!unitId.isNullOrBlank()) loadUpdate["assignedUnitId"] = unitId
        if (!operatorId.isNullOrBlank()) loadUpdate["assignedOperatorId"] = operatorId
        if (full) {
            loadUpdate["status"] = "Asignado"
            loadUpdate["assignedCarrierId"] = carrierId
        }
        db.collection("loads").document(loadId).update(loadUpdate).await()
        val offerUpdate = mutableMapOf<String, Any>("status" to "Ganadora")
        if (taken < asked) offerUpdate["availableUnitCount"] = taken
        db.collection("offers").document(offer.id).update(offerUpdate).await()
        notify(
            carrierId,
            "load_assigned",
            "¡Propuesta aprobada!",
            if (taken < asked) {
                "Se aprobaron $taken de $asked unidades. Solo esas seguían disponibles."
            } else {
                "Tu contra-oferta para el viaje fue aprobada."
            },
            loadId,
        )
    }

    suspend fun rejectCounter(profile: CarrierProfile, offer: FreightOffer) {
        if (profile.role != "admin") error("Solo un administrador puede rechazar la contra-oferta.")
        val snap = db.collection("offers").document(offer.id).get().await()
        if (snap.getString("status") != "PendienteAprobacion") return
        db.collection("offers").document(offer.id).update("status", "Rechazada").await()
    }

    suspend fun setUserStatus(person: CarrierProfile, status: String, title: String? = null, body: String? = null) {
        db.collection("users").document(person.authUid).update("status", status).await()
        val digits = person.phoneDigits?.filter { it.isDigit() }?.takeIf { it.length in 10..15 }
        if (digits != null) {
            runCatching { db.collection("users_by_phone").document(digits).update("status", status).await() }
        }
        if (!title.isNullOrBlank() && !body.isNullOrBlank()) {
            notify(person.uuid, "registration_$status", title, body, null)
        }
    }

    private suspend fun notify(userId: String, type: String, title: String, body: String, loadId: String?) {
        val id = UUID.randomUUID().toString()
        val payload = mutableMapOf<String, Any>(
            "id" to id,
            "userId" to userId,
            "type" to type,
            "title" to title,
            "body" to body,
            "isRead" to false,
            "createdAt" to Timestamp.now(),
        )
        if (!loadId.isNullOrBlank()) payload["loadId"] = loadId
        db.collection("notifications").document(id).set(payload).await()
    }
}

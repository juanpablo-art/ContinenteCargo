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

    fun stop() {
        registrations.forEach { it.remove() }
        registrations.clear()
    }

    fun listen(
        profile: CarrierProfile,
        onLoads: (List<FreightLoad>) -> Unit,
        onOffers: (List<FreightOffer>) -> Unit,
        onUnits: (List<FleetUnit>) -> Unit,
        onNotices: (List<Notice>) -> Unit,
        onPasses: (Set<String>, Set<String>) -> Unit,
        onProfile: (CarrierProfile?) -> Unit,
        onError: (String) -> Unit,
    ) {
        stop()
        registrations += db.collection("loads").addSnapshotListener { snap, error ->
            if (error != null) {
                onError("No se pudieron cargar las cargas.")
                return@addSnapshotListener
            }
            onLoads(snap?.documents?.mapNotNull { parseLoad(it.id, snapshotMap(it.data)) }.orEmpty())
        }
        registrations += db.collection("offers").addSnapshotListener { snap, error ->
            if (error != null) {
                onError("No se pudieron cargar las ofertas.")
                return@addSnapshotListener
            }
            onOffers(snap?.documents?.mapNotNull { parseOffer(it.id, snapshotMap(it.data)) }.orEmpty())
        }
        registrations += db.collection("units").addSnapshotListener { snap, error ->
            if (error != null) {
                onError("No se pudieron cargar las unidades.")
                return@addSnapshotListener
            }
            onUnits(snap?.documents?.mapNotNull { parseUnit(it.id, snapshotMap(it.data)) }.orEmpty())
        }
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
        registrations += db.collection("users").document(profile.authUid)
            .addSnapshotListener { snap, _ ->
                if (snap == null || !snap.exists()) {
                    onProfile(null)
                } else {
                    onProfile(parseProfile(profile.authUid, snapshotMap(snap.data)))
                }
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

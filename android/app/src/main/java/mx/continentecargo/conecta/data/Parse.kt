package mx.continentecargo.conecta.data

import com.google.firebase.Timestamp
import java.text.Normalizer
import java.util.Date

fun normalizeEquipment(raw: String): String {
    val replaced = raw
        .replace("\u043e", "o").replace("\u041e", "o")
        .replace("\u0440", "p").replace("\u0420", "p")
        .replace("\u0442", "t").replace("\u0422", "t")
        .replace("\u043d", "n").replace("\u041d", "n")
    val folded = Normalizer.normalize(replaced, Normalizer.Form.NFD)
        .replace(Regex("\\p{M}+"), "")
        .lowercase()
    return if (folded == "torton" || folded == "topton") "Torton" else raw
}

fun Any?.asStringList(): List<String> =
    (this as? List<*>)?.mapNotNull { it as? String } ?: emptyList()

fun Any?.asDouble(default: Double = 0.0): Double = when (this) {
    is Double -> this
    is Float -> this.toDouble()
    is Int -> this.toDouble()
    is Long -> this.toDouble()
    is Number -> this.toDouble()
    is String -> this.toDoubleOrNull() ?: default
    else -> default
}

fun Any?.asInt(default: Int = 0): Int = when (this) {
    is Int -> this
    is Long -> this.toInt()
    is Double -> this.toInt()
    is Float -> this.toInt()
    is Number -> this.toInt()
    else -> default
}

fun Any?.asBool(default: Boolean = false): Boolean = this as? Boolean ?: default

fun Any?.asDate(): Date = when (this) {
    is Timestamp -> this.toDate()
    is Date -> this
    is Number -> {
        val raw = this.toLong()
        if (raw > 100_000_000_000L) Date(raw) else Date(raw * 1000)
    }
    is String -> runCatching { Date.from(java.time.Instant.parse(this)) }.getOrDefault(Date())
    else -> Date()
}

private fun Map<String, Any?>.str(key: String): String? = this[key] as? String

fun parseProfile(authUid: String, data: Map<String, Any?>): CarrierProfile? {
    val name = data.str("name") ?: return null
    val email = data.str("email") ?: return null
    val phone = data.str("phone") ?: return null
    val role = data.str("role") ?: return null
    val status = data.str("status") ?: return null
    return CarrierProfile(
        authUid = authUid,
        uuid = data.str("uuid") ?: authUid,
        name = name,
        email = email,
        phone = phone,
        phoneDigits = data.str("phoneDigits"),
        role = role,
        status = status,
        companyId = data.str("companyId"),
        canNegotiateRates = data["canNegotiateRates"].asBool(true),
        handlesLTL = data["handlesLTL"].asBool(),
        handlesHazmat = data["handlesHazmat"].asBool(),
        handlesLocal = data["handlesLocal"].asBool(),
        handlesIntraState = data["handlesIntraState"].asBool(),
        coversUSA = data["coversUSA"].asBool(),
        routes = parseRoutes(data["routes"]),
        coverageStates = data["coverageStates"].asStringList(),
        coverageZones = data["coverageZones"].asStringList(),
        coverageEquipmentTypes = data["coverageEquipmentTypes"].asStringList().map(::normalizeEquipment),
        coverageUSAStates = data["coverageUSAStates"].asStringList(),
        pricerId = data.str("pricerId")?.takeIf { it.isNotBlank() },
    )
}

fun parseRoutes(raw: Any?): List<RouteCoverage> {
    val rows = raw as? List<*> ?: return emptyList()
    return rows.mapNotNull { item ->
        val map = item as? Map<*, *> ?: return@mapNotNull null
        val origin = map["originState"] as? String ?: return@mapNotNull null
        val destination = map["destinationState"] as? String ?: return@mapNotNull null
        RouteCoverage(
            id = map["id"] as? String ?: java.util.UUID.randomUUID().toString(),
            originState = origin,
            destinationState = destination,
            bidirectional = (map["bidirectional"] as? Boolean) ?: true,
            equipmentTypes = map["equipmentTypes"].asStringList().map(::normalizeEquipment),
        )
    }
}

fun parseLoad(docId: String, data: Map<String, Any?>): FreightLoad? {
    val id = data.str("id") ?: docId
    val reference = data.str("reference") ?: return null
    val originCity = data.str("originCity") ?: return null
    val originState = data.str("originState") ?: return null
    val destinationCity = data.str("destinationCity") ?: return null
    val destinationState = data.str("destinationState") ?: return null
    val equipmentType = data.str("equipmentType") ?: return null
    val assignmentMode = data.str("assignmentMode") ?: return null
    val status = data.str("status") ?: return null
    val publishedBy = data.str("publishedBy") ?: return null
    val decrement = data["minBidDecrement"].asDouble()
    return FreightLoad(
        id = id,
        reference = reference,
        originCity = originCity,
        originState = originState,
        destinationCity = destinationCity,
        destinationState = destinationState,
        pickupDate = data["pickupDate"].asDate(),
        deliveryDate = data["deliveryDate"].asDate(),
        equipmentType = normalizeEquipment(equipmentType),
        unitCount = data["unitCount"].asInt(1).coerceAtLeast(1),
        confirmedUnitCount = data["confirmedUnitCount"].asInt(0),
        weightKg = data["weightKg"].asDouble(),
        merchandiseDescription = data.str("merchandiseDescription").orEmpty(),
        measurementsDescription = data.str("measurementsDescription").orEmpty(),
        specialRequirements = data["specialRequirements"].asStringList(),
        offeredPrice = data["offeredPrice"].asDouble(),
        currency = data.str("currency")?.ifBlank { null } ?: "MXN",
        includesVAT = data["includesVAT"].asBool(),
        maxAuthorizedPriceSinIVA = (data["maxAuthorizedPriceSinIVA"] as? Number)?.toDouble(),
        assignedPriceSinIVA = (data["assignedPriceSinIVA"] as? Number)?.toDouble(),
        includedConcepts = data.str("includedConcepts").orEmpty(),
        allowedExtraExpenses = data.str("allowedExtraExpenses").orEmpty(),
        assignmentMode = assignmentMode,
        deadline = data["deadline"].asDate(),
        minBidDecrement = if (decrement > 0) decrement else 100.0,
        observations = data.str("observations").orEmpty(),
        status = status,
        publishedBy = publishedBy,
        publishedAt = data["publishedAt"].asDate(),
        assignedCarrierId = data.str("assignedCarrierId"),
        assignedUnitId = data.str("assignedUnitId"),
        assignedOperatorId = data.str("assignedOperatorId"),
        unitETA = if (data["unitETA"] == null) null else data["unitETA"].asDate(),
        trackingUrl = data.str("trackingUrl").orEmpty(),
        statusHistory = parseHistory(data["statusHistory"]),
        clientContactName = data.str("clientContactName").orEmpty(),
        clientContactPhone = data.str("clientContactPhone").orEmpty(),
        exactPickupAddress = data.str("exactPickupAddress").orEmpty(),
        exactDeliveryAddress = data.str("exactDeliveryAddress").orEmpty(),
        confirmedCarrierIds = data["confirmedCarrierIds"].asStringList(),
        carta = parseCarta(data["cartaInstruccion"]),
    )
}

private fun parseHistory(raw: Any?): List<StatusEvent> {
    val rows = raw as? List<*> ?: return emptyList()
    return rows.mapNotNull { item ->
        val map = item as? Map<*, *> ?: return@mapNotNull null
        val status = map["status"] as? String ?: return@mapNotNull null
        val changedBy = map["changedBy"] as? String ?: return@mapNotNull null
        StatusEvent(
            id = map["id"] as? String ?: java.util.UUID.randomUUID().toString(),
            status = status,
            changedBy = changedBy,
            changedByName = map["changedByName"] as? String ?: "",
            changedAt = map["changedAt"].asDate(),
            notes = map["notes"] as? String ?: "",
        )
    }
}

private fun parseCarta(raw: Any?): CartaInstruccion? {
    val map = raw as? Map<*, *> ?: return null
    return CartaInstruccion(
        folio = map["folio"] as? String ?: "",
        recoleccion = map["instruccionesRecoleccion"] as? String ?: "",
        entrega = map["instruccionesEntrega"] as? String ?: "",
        contactoCarga = map["contactoCarga"] as? String ?: "",
        contactoDescarga = map["contactoDescarga"] as? String ?: "",
        observaciones = map["observaciones"] as? String ?: "",
        archivoNombre = map["archivoNombre"] as? String ?: "",
    )
}

fun parseOffer(docId: String, data: Map<String, Any?>): FreightOffer? {
    val id = data.str("id") ?: docId
    val loadId = data.str("loadId") ?: return null
    val carrierId = data.str("carrierId") ?: return null
    val carrierName = data.str("carrierName") ?: return null
    val status = data.str("status") ?: return null
    return FreightOffer(
        id = id,
        loadId = loadId,
        carrierId = carrierId,
        carrierName = carrierName,
        unitId = data.str("unitId"),
        operatorId = data.str("operatorId"),
        amount = data["amount"].asDouble(),
        currency = data.str("currency")?.ifBlank { null } ?: "MXN",
        isAvailabilityOnly = data["isAvailabilityOnly"].asBool(),
        proposedPrice = (data["proposedPrice"] as? Number)?.toDouble(),
        availableUnitCount = data["availableUnitCount"].asInt(1).coerceAtLeast(1),
        status = status,
        submittedAt = data["submittedAt"].asDate(),
        notes = data.str("notes").orEmpty(),
        staffCounterPrice = (data["staffCounterPrice"] as? Number)?.toDouble(),
        staffCounterByName = data.str("staffCounterByName"),
        staffCounterBy = data.str("staffCounterBy"),
        staffCounterStatus = data.str("staffCounterStatus"),
    )
}

fun parseUnit(docId: String, data: Map<String, Any?>): FleetUnit? {
    val id = data.str("id") ?: docId
    val ownerId = data.str("ownerId") ?: return null
    val equipment = data.str("equipmentType") ?: return null
    return FleetUnit(
        id = id,
        ownerId = ownerId,
        equipmentType = normalizeEquipment(equipment),
        plates = data.str("plates").orEmpty(),
        trailerNumber = data.str("trailerNumber").orEmpty(),
        currentLocation = data.str("currentLocation").orEmpty(),
        operatorName = data.str("operatorName").orEmpty(),
        scac = data.str("scac").orEmpty(),
        caat = data.str("caat").orEmpty(),
        availableFrom = data["availableFrom"].asDate(),
        coverageZones = data["coverageZones"].asStringList(),
        status = data.str("status")?.ifBlank { null } ?: "Disponible",
        operatorId = data.str("operatorId"),
        notes = data.str("notes").orEmpty(),
        postedOriginState = data.str("postedOriginState"),
        postedDestinationState = data.str("postedDestinationState"),
    )
}

fun parseNotice(docId: String, data: Map<String, Any?>): Notice? {
    val id = data.str("id") ?: docId
    val userId = data.str("userId") ?: return null
    val type = data.str("type") ?: return null
    val title = data.str("title") ?: return null
    val body = data.str("body") ?: return null
    return Notice(
        id = id,
        userId = userId,
        type = type,
        title = title,
        body = body,
        loadId = data.str("loadId"),
        isRead = data["isRead"].asBool(),
        createdAt = data["createdAt"].asDate(),
    )
}

@Suppress("UNCHECKED_CAST")
fun snapshotMap(data: Map<String, Any>?): Map<String, Any?> = data ?: emptyMap()

fun Any?.asHistoryMaps(): List<Map<String, Any>> {
    val rows = this as? List<*> ?: return emptyList()
    return rows.mapNotNull { item ->
        val map = item as? Map<*, *> ?: return@mapNotNull null
        map.entries.mapNotNull { (key, value) ->
            val name = key as? String ?: return@mapNotNull null
            if (value == null) null else name to value
        }.toMap()
    }
}

fun parseTariff(id: String, data: Map<String, Any?>): TariffBook {
    val rows = (data["rows"] as? List<*>).orEmpty().mapNotNull { item ->
        val map = item as? Map<*, *> ?: return@mapNotNull null
        sanitizeTariffRow(
            origin = map["origin"] as? String ?: "",
            destination = map["destination"] as? String ?: "",
            equipment = map["equipment"] as? String ?: "",
            amount = map["amount"].asDouble(),
            currency = map["currency"] as? String ?: "MXN",
            basis = map["basis"] as? String ?: "otro",
            notes = map["notes"] as? String ?: "",
            source = map["source"] as? String ?: "manual",
        )
    }
    return TariffBook(
        id = id,
        label = (data["label"] as? String)?.takeIf { it.isNotBlank() } ?: "Transportista",
        phone = data["phone"] as? String ?: "",
        carrierUuid = data["carrierUuid"] as? String ?: "",
        fileName = data["fileName"] as? String ?: "",
        rows = rows,
    )
}

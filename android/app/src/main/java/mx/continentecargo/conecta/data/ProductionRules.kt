package mx.continentecargo.conecta.data

import com.google.firebase.Timestamp
import java.time.LocalDate
import java.time.ZoneId
import java.util.Date
import java.util.UUID

private val monterrey: ZoneId = ZoneId.of("America/Monterrey")

data class TariffRow(
    val origin: String,
    val destination: String,
    val equipment: String,
    val amount: Double,
    val currency: String,
    val basis: String,
    val notes: String,
    val source: String,
)

data class TariffBook(
    val id: String,
    val label: String,
    val phone: String,
    val carrierUuid: String,
    val fileName: String,
    val rows: List<TariffRow>,
)

data class ClientPublish(
    val originCity: String,
    val originState: String,
    val destinationCity: String,
    val destinationState: String,
    val pickupDay: String,
    val equipment: String,
    val merchandise: String,
    val currency: String,
    val ltl: Boolean,
    val marketUsa: Boolean,
)

data class PayLine(
    val id: String,
    val invoice: String,
    val shipment: String,
    val total: String,
    val status: String,
    val paid: String,
    val folio: String,
)

data class PaySupplier(
    val id: String,
    val name: String,
)

data class PaySnapshot(
    val suppliers: List<PaySupplier> = emptyList(),
    val accountTitle: String? = null,
    val accountLine: String? = null,
    val cards: List<Pair<String, String>> = emptyList(),
    val payments: List<PayLine> = emptyList(),
    val error: String? = null,
    val portalError: String? = null,
    val needsRfc: Boolean = false,
)

object TariffBasis {
    val options = listOf(
        "viaje" to "Por viaje",
        "km" to "Por kilómetro",
        "milla" to "Por milla",
        "tonelada" to "Por tonelada",
        "otro" to "Otro",
    )

    fun label(key: String): String = options.firstOrNull { it.first == key }?.second ?: "Otro"
}

fun payStatusLabel(status: String): String = when (status) {
    "pending" -> "Pendiente"
    "scheduled" -> "Programado"
    "partially_paid" -> "Pago parcial"
    "paid" -> "Pagado"
    else -> status.ifBlank { "—" }
}

fun tariffPhone(profile: CarrierProfile): String? {
    val stored = profile.phoneDigits?.filter { it.isDigit() }.orEmpty()
    if (stored.length in 10..15) return stored
    val raw = profile.phone.filter { it.isDigit() }
    if (profile.phone.all { it.isDigit() } && raw.length in 10..15) return raw
    return null
}

fun sanitizeTariffRow(
    origin: String,
    destination: String,
    equipment: String,
    amount: Double,
    currency: String,
    basis: String,
    notes: String,
    source: String,
): TariffRow? {
    if (!amount.isFinite() || amount <= 0.0 || amount > 100_000_000.0) return null
    val from = origin.replace(Regex("\\s+"), " ").trim().take(80)
    val to = destination.replace(Regex("\\s+"), " ").trim().take(80)
    if (from.isEmpty() || to.isEmpty()) return null
    val cleanBasis = if (TariffBasis.options.any { it.first == basis }) basis else "otro"
    val cleanSource = if (source == "archivo") "archivo" else "manual"
    return TariffRow(
        origin = from,
        destination = to,
        equipment = equipment.replace(Regex("\\s+"), " ").trim().take(80),
        amount = kotlin.math.round(amount * 100.0) / 100.0,
        currency = if (currency == "USD") "USD" else "MXN",
        basis = cleanBasis,
        notes = notes.replace(Regex("\\s+"), " ").trim().take(240),
        source = cleanSource,
    )
}

fun availabilityUnit(
    profile: CarrierProfile,
    equipment: String,
    count: Int,
    origin: String,
    destination: String,
    id: String = UUID.randomUUID().toString(),
    availableFrom: Date = Date(),
): FleetUnit = FleetUnit(
    id = id,
    ownerId = profile.companyId ?: profile.uuid,
    equipmentType = equipment,
    plates = "",
    trailerNumber = count.coerceAtLeast(1).toString(),
    currentLocation = origin,
    operatorName = "",
    scac = "",
    caat = "",
    availableFrom = availableFrom,
    coverageZones = listOf(destination),
    status = "Disponible",
    operatorId = null,
    notes = "availability_post",
    postedOriginState = origin,
    postedDestinationState = destination,
)

fun clientPublishError(profile: CarrierProfile, input: ClientPublish): String? {
    if (profile.role != "client" || profile.status != "approved") return "Tu cuenta está en revisión."
    if (input.originCity.isBlank() || input.destinationCity.isBlank() || input.pickupDay.isBlank() || input.merchandise.isBlank()) {
        return "Completa origen, destino, fecha, equipo y qué se mueve."
    }
    val places = if (input.marketUsa) Catalog.usaStates else Catalog.mexicoStates
    if (input.originState !in places || input.destinationState !in places || input.equipment !in Catalog.equipment) {
        return "Elige estado y equipo de la lista."
    }
    if (pickupMoment(input.pickupDay) == null) return "La fecha de recolección no es válida."
    return null
}

fun pickupMoment(day: String): Date? {
    val date = runCatching { LocalDate.parse(day.trim()) }.getOrNull() ?: return null
    return Date.from(date.atTime(8, 0).atZone(monterrey).toInstant())
}

fun clientLoadDocument(
    profile: CarrierProfile,
    input: ClientPublish,
    id: String,
    reference: String,
): Map<String, Any>? {
    if (clientPublishError(profile, input) != null) return null
    val pickup = pickupMoment(input.pickupDay) ?: return null
    val pickupDay = pickup.toInstant().atZone(monterrey).toLocalDate()
    val delivery = Date.from(pickupDay.plusDays(1).atTime(18, 0).atZone(monterrey).toInstant())
    val deadline = Date.from(pickupDay.plusDays(2).atTime(18, 0).atZone(monterrey).toInstant())
    val history = mapOf(
        "id" to UUID.randomUUID().toString(),
        "status" to "Publicado",
        "changedBy" to profile.uuid,
        "changedByName" to profile.name,
        "changedAt" to Timestamp.now(),
        "notes" to "",
    )
    return mapOf(
        "id" to id,
        "reference" to reference,
        "originCity" to input.originCity.trim(),
        "originState" to input.originState,
        "destinationCity" to input.destinationCity.trim(),
        "destinationState" to input.destinationState,
        "pickupDate" to Timestamp(pickup),
        "deliveryDate" to Timestamp(delivery),
        "equipmentType" to normalizeEquipment(input.equipment),
        "unitCount" to 1,
        "confirmedUnitCount" to 0,
        "weightKg" to 0.0,
        "merchandiseDescription" to input.merchandise.trim().take(1000),
        "measurementsDescription" to "",
        "specialRequirements" to emptyList<String>(),
        "offeredPrice" to 0.0,
        "currency" to if (input.currency == "USD") "USD" else "MXN",
        "includesVAT" to false,
        "includedConcepts" to "",
        "allowedExtraExpenses" to "",
        "assignmentMode" to if (input.ltl) "Consolidada LTL" else "Subasta Inversa",
        "deadline" to Timestamp(deadline),
        "minBidDecrement" to 100.0,
        "observations" to "",
        "status" to "Publicado",
        "publishedBy" to profile.uuid,
        "publishedAt" to Timestamp.now(),
        "trackingUrl" to "",
        "statusHistory" to listOf(history),
        "clientContactName" to profile.name.trim().take(80),
        "clientContactPhone" to profile.phone.trim().take(30),
        "exactPickupAddress" to "",
        "exactDeliveryAddress" to "",
        "notificationChannels" to mapOf(
            "inApp" to true,
            "email" to true,
            "whatsapp" to true,
            "aiCall" to false,
        ),
        "confirmedCarrierIds" to emptyList<String>(),
    )
}

fun paymentCarriers(people: List<CarrierProfile>): List<CarrierProfile> =
    people
        .filter { it.role in Catalog.carrierRoles && it.status != "suspended" }
        .sortedBy { it.name.lowercase() }

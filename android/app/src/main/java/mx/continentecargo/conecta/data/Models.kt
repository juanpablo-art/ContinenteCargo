package mx.continentecargo.conecta.data

import com.google.firebase.Timestamp
import java.util.Date
import java.util.UUID

data class RouteCoverage(
    val id: String,
    val originState: String,
    val destinationState: String,
    val bidirectional: Boolean,
    val equipmentTypes: List<String>,
) {
    fun toMap(): Map<String, Any> = mapOf(
        "id" to id,
        "originState" to originState,
        "destinationState" to destinationState,
        "bidirectional" to bidirectional,
        "equipmentTypes" to equipmentTypes,
    )
}

data class CarrierProfile(
    val authUid: String,
    val uuid: String,
    val name: String,
    val email: String,
    val phone: String,
    val phoneDigits: String?,
    val role: String,
    val status: String,
    val companyId: String?,
    val canNegotiateRates: Boolean,
    val handlesLTL: Boolean,
    val handlesHazmat: Boolean,
    val handlesLocal: Boolean,
    val handlesIntraState: Boolean,
    val coversUSA: Boolean,
    val routes: List<RouteCoverage>,
    val coverageStates: List<String>,
    val coverageZones: List<String>,
    val coverageEquipmentTypes: List<String>,
    val coverageUSAStates: List<String>,
)

data class StatusEvent(
    val id: String,
    val status: String,
    val changedBy: String,
    val changedByName: String,
    val changedAt: Date,
    val notes: String,
) {
    fun toMap(): Map<String, Any> = mapOf(
        "id" to id,
        "status" to status,
        "changedBy" to changedBy,
        "changedByName" to changedByName,
        "changedAt" to Timestamp(changedAt),
        "notes" to notes,
    )
}

data class CartaInstruccion(
    val folio: String,
    val recoleccion: String,
    val entrega: String,
    val contactoCarga: String,
    val contactoDescarga: String,
    val observaciones: String,
    val archivoNombre: String,
)

data class FreightLoad(
    val id: String,
    val reference: String,
    val originCity: String,
    val originState: String,
    val destinationCity: String,
    val destinationState: String,
    val pickupDate: Date,
    val deliveryDate: Date,
    val equipmentType: String,
    val unitCount: Int,
    val confirmedUnitCount: Int,
    val weightKg: Double,
    val merchandiseDescription: String,
    val measurementsDescription: String,
    val specialRequirements: List<String>,
    val offeredPrice: Double,
    val currency: String,
    val includesVAT: Boolean,
    val maxAuthorizedPriceSinIVA: Double?,
    val assignedPriceSinIVA: Double?,
    val includedConcepts: String,
    val allowedExtraExpenses: String,
    val assignmentMode: String,
    val deadline: Date,
    val minBidDecrement: Double,
    val observations: String,
    val status: String,
    val publishedBy: String,
    val publishedAt: Date,
    val assignedCarrierId: String?,
    val assignedUnitId: String?,
    val assignedOperatorId: String?,
    val unitETA: Date?,
    val trackingUrl: String,
    val statusHistory: List<StatusEvent>,
    val clientContactName: String,
    val clientContactPhone: String,
    val exactPickupAddress: String,
    val exactDeliveryAddress: String,
    val confirmedCarrierIds: List<String>,
    val carta: CartaInstruccion?,
) {
    val routeLabel: String get() = "$originCity → $destinationCity"
    val placesLeft: Int get() = (unitCount - confirmedUnitCount).coerceAtLeast(0)
}

data class FreightOffer(
    val id: String,
    val loadId: String,
    val carrierId: String,
    val carrierName: String,
    val unitId: String?,
    val operatorId: String?,
    val amount: Double,
    val currency: String,
    val isAvailabilityOnly: Boolean,
    val proposedPrice: Double?,
    val availableUnitCount: Int,
    val status: String,
    val submittedAt: Date,
    val notes: String,
    val staffCounterPrice: Double?,
    val staffCounterByName: String?,
    val staffCounterBy: String?,
    val staffCounterStatus: String?,
) {
    fun toWriteMap(): Map<String, Any> {
        val map = mutableMapOf<String, Any>(
            "id" to id,
            "loadId" to loadId,
            "carrierId" to carrierId,
            "carrierName" to carrierName,
            "amount" to amount,
            "currency" to currency,
            "isAvailabilityOnly" to isAvailabilityOnly,
            "availableUnitCount" to availableUnitCount,
            "status" to status,
            "submittedAt" to Timestamp(submittedAt),
            "notes" to notes,
        )
        if (unitId != null) map["unitId"] = unitId
        if (operatorId != null) map["operatorId"] = operatorId
        if (proposedPrice != null) map["proposedPrice"] = proposedPrice
        return map
    }
}

data class FleetUnit(
    val id: String,
    val ownerId: String,
    val equipmentType: String,
    val plates: String,
    val trailerNumber: String,
    val currentLocation: String,
    val operatorName: String,
    val scac: String,
    val caat: String,
    val availableFrom: Date,
    val coverageZones: List<String>,
    val status: String,
    val operatorId: String?,
    val notes: String,
) {
    fun toWriteMap(): Map<String, Any> {
        val map = mutableMapOf<String, Any>(
            "id" to id,
            "ownerId" to ownerId,
            "equipmentType" to normalizeEquipment(equipmentType),
            "plates" to plates,
            "trailerNumber" to trailerNumber,
            "currentLocation" to currentLocation,
            "operatorName" to operatorName,
            "scac" to scac,
            "caat" to caat,
            "availableFrom" to Timestamp(availableFrom),
            "coverageZones" to coverageZones,
            "status" to status,
            "notes" to notes,
        )
        if (!operatorId.isNullOrBlank()) map["operatorId"] = operatorId
        return map
    }

    companion object {
        fun draft(ownerId: String): FleetUnit = FleetUnit(
            id = UUID.randomUUID().toString(),
            ownerId = ownerId,
            equipmentType = Catalog.equipment.first(),
            plates = "",
            trailerNumber = "",
            currentLocation = "",
            operatorName = "",
            scac = "",
            caat = "",
            availableFrom = Date(),
            coverageZones = emptyList(),
            status = "Disponible",
            operatorId = null,
            notes = "",
        )
    }
}

data class Notice(
    val id: String,
    val userId: String,
    val type: String,
    val title: String,
    val body: String,
    val loadId: String?,
    val isRead: Boolean,
    val createdAt: Date,
)

data class RegisterInput(
    val name: String,
    val companyName: String,
    val phone: String,
    val email: String,
    val password: String,
    val role: String,
    val equipment: List<String>,
    val states: List<String>,
    val handlesLtl: Boolean,
    val handlesHazmat: Boolean,
    val handlesLocal: Boolean,
    val handlesIntraState: Boolean,
    val coversUsa: Boolean,
    val usaStates: List<String>,
    val rfc: String,
)

sealed class ProfileRead {
    data class Found(val profile: CarrierProfile) : ProfileRead()
    data object Missing : ProfileRead()
    data class Failed(val error: Exception) : ProfileRead()
}

sealed class Gate {
    data object Allow : Gate()
    data class Deny(val message: String) : Gate()
}

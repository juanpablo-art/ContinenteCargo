package mx.continentecargo.conecta.data

import java.util.Date

private val usa = Catalog.usaStates.toSet()

private fun routeMatches(
    route: RouteCoverage,
    originState: String,
    destinationState: String,
    equipment: String,
): Boolean {
    val direct = route.originState == originState && route.destinationState == destinationState
    val reverse = route.bidirectional && route.originState == destinationState && route.destinationState == originState
    if (!direct && !reverse) return false
    return route.equipmentTypes.isEmpty() || equipment in route.equipmentTypes
}

fun coversLoad(profile: CarrierProfile, load: FreightLoad): Boolean = covers(
    profile,
    load.originCity,
    load.originState,
    load.destinationCity,
    load.destinationState,
    load.equipmentType,
)

fun covers(
    profile: CarrierProfile,
    originCity: String,
    originState: String,
    destinationCity: String,
    destinationState: String,
    equipment: String,
): Boolean {
    val originUsa = originState in usa
    val destinationUsa = destinationState in usa
    if (originUsa || destinationUsa) {
        if (!profile.coversUSA) return false
        if (originUsa && destinationUsa) {
            if (profile.coverageUSAStates.isEmpty()) return true
            return originState in profile.coverageUSAStates && destinationState in profile.coverageUSAStates
        }
        val usaSide = if (originUsa) originState else destinationState
        if (profile.coverageUSAStates.isNotEmpty() && usaSide !in profile.coverageUSAStates) return false
        return if (profile.routes.isNotEmpty()) {
            profile.routes.any { routeMatches(it, originState, destinationState, equipment) }
        } else {
            true
        }
    }
    if (profile.routes.isNotEmpty()) {
        return profile.routes.any { routeMatches(it, originState, destinationState, equipment) }
    }
    if (originState == destinationState) {
        val sameCity = originCity.isNotBlank() &&
            destinationCity.isNotBlank() &&
            originCity.equals(destinationCity, ignoreCase = true)
        return if (sameCity) profile.handlesLocal else profile.handlesIntraState
    }
    if (profile.coverageStates.isNotEmpty()) {
        if (originState !in profile.coverageStates || destinationState !in profile.coverageStates) return false
        return profile.coverageEquipmentTypes.isEmpty() || equipment in profile.coverageEquipmentTypes
    }
    if (profile.coverageZones.isNotEmpty()) {
        val originZone = Catalog.zoneOf(originState)
        val destinationZone = Catalog.zoneOf(destinationState)
        val originHit = originZone != null && originZone in profile.coverageZones
        val destinationHit = destinationZone != null && destinationZone in profile.coverageZones
        if (!originHit && !destinationHit) return false
        return profile.coverageEquipmentTypes.isEmpty() || equipment in profile.coverageEquipmentTypes
    }
    return true
}

fun isFull(load: FreightLoad): Boolean = load.unitCount > 0 && load.confirmedUnitCount >= load.unitCount

fun visibleLoads(
    profile: CarrierProfile?,
    loads: List<FreightLoad>,
    passedRoutes: Set<String>,
    passedLoadIds: Set<String>,
): List<FreightLoad> {
    profile ?: return emptyList()
    return loads.mapNotNull { load ->
        val mine = profile.uuid in load.confirmedCarrierIds || load.assignedCarrierId == profile.uuid
        if (mine) return@mapNotNull load
        if (load.status != "Publicado" || isFull(load)) return@mapNotNull null
        val key = "${load.originState}|${load.destinationState}|${load.equipmentType}"
        if (key in passedRoutes || load.id in passedLoadIds) return@mapNotNull null
        val ok = if (load.assignmentMode == "Consolidada LTL") {
            profile.handlesLTL && Date().before(load.deadline)
        } else {
            coversLoad(profile, load)
        }
        if (ok) load else null
    }.sortedBy { it.deadline.time }
}

fun myOffers(profile: CarrierProfile?, offers: List<FreightOffer>): List<FreightOffer> {
    profile ?: return emptyList()
    return offers
        .filter { it.carrierId == profile.uuid && it.status in Catalog.openOfferStatuses }
        .sortedByDescending { it.submittedAt.time }
}

fun myTrips(
    profile: CarrierProfile?,
    loads: List<FreightLoad>,
    offers: List<FreightOffer>,
): List<FreightLoad> {
    profile ?: return emptyList()
    val won = offers
        .filter { it.carrierId == profile.uuid && it.status == "Ganadora" }
        .map { it.loadId }
        .toSet()
    return loads
        .filter {
            it.assignedCarrierId == profile.uuid ||
                it.assignedOperatorId == profile.uuid ||
                profile.uuid in it.confirmedCarrierIds ||
                it.id in won
        }
        .sortedWith(compareBy<FreightLoad> { it.status == "Entregado" || it.status == "Cancelado" }.thenBy { it.pickupDate.time })
}

fun myUnits(profile: CarrierProfile?, units: List<FleetUnit>): List<FleetUnit> {
    profile ?: return emptyList()
    return units.filter { unit ->
        unit.notes != "availability_post" &&
            (unit.ownerId == profile.uuid || (profile.companyId != null && unit.ownerId == profile.companyId))
    }
}

fun eligibleUnits(profile: CarrierProfile?, units: List<FleetUnit>, load: FreightLoad): List<FleetUnit> =
    myUnits(profile, units).filter { unit ->
        unit.status == "Disponible" &&
            !unit.availableFrom.after(load.pickupDate) &&
            unit.equipmentType == load.equipmentType
    }

fun canSeePrivate(profile: CarrierProfile?, load: FreightLoad): Boolean {
    profile ?: return false
    return load.assignedCarrierId == profile.uuid || profile.uuid in load.confirmedCarrierIds
}

fun needsCounterOffer(load: FreightLoad, price: Double): Boolean {
    if (price <= load.offeredPrice) return false
    val max = load.maxAuthorizedPriceSinIVA
    return if (max != null) price > max else true
}

fun gate(profile: CarrierProfile?): Gate {
    if (profile == null) {
        return Gate.Deny("Usuario autenticado pero sin perfil. Contacta al administrador.")
    }
    if (profile.role !in Catalog.carrierRoles) {
        return Gate.Deny("Esta aplicación es para transportistas. Entra con tu cuenta de línea u operador independiente.")
    }
    if (profile.status == "suspended") {
        return Gate.Deny("Tu cuenta está bloqueada. Ya no puedes operar ni recibir avisos.")
    }
    if (profile.status != "approved") {
        return Gate.Deny("Tu cuenta está pendiente de aprobación. Te notificaremos cuando sea revisada.")
    }
    return Gate.Allow
}

fun actionMessage(code: String, decrementLabel: String? = null): String = when (code) {
    "success" -> "¡Participación confirmada!"
    "pendingApproval" -> "Tu contra-oferta requiere aprobación del administrador."
    "alreadyAssigned" -> "Esta carga ya fue tomada o está completa."
    "notEnoughUnits", "notEnough" -> "Ya no quedan unidades disponibles."
    "deadlinePassed" -> "El plazo para participar ya cerró."
    "notApproved" -> "Tu cuenta aún no está aprobada."
    "noUnit" -> "Selecciona una unidad disponible válida."
    "amountRequired" -> "Escribe un precio mayor a cero."
    "decrementTooSmall" -> decrementLabel?.let { "Hay que bajar al menos $it de la mejor oferta." }
        ?: "Tu oferta debe bajar al menos el decremento mínimo."
    "closed" -> "Esta carga ya no está disponible."
    "quoteRejected" -> "No se pudo enviar la cotización."
    else -> "No se pudo completar. Intenta de nuevo."
}

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
    val fleet = units.filter { it.notes != "availability_post" }
    if (profile.role == "admin") return fleet
    return fleet.filter { unit ->
        unit.ownerId == profile.uuid || (profile.companyId != null && unit.ownerId == profile.companyId)
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
    if (profile.role == "admin" || profile.role == "pricer") return true
    return load.assignedCarrierId == profile.uuid || profile.uuid in load.confirmedCarrierIds
}

fun needsCounterOffer(load: FreightLoad, price: Double): Boolean {
    if (price <= load.offeredPrice) return false
    val max = load.maxAuthorizedPriceSinIVA
    return if (max != null) price > max else true
}

private val pricerSelectionIds = setOf(
    "033cdbf4-e582-4989-9c46-9b2c1fdc2f82",
    "d3fe5bc5-a742-4d39-87ca-b5debd4d54e3",
    "9bb57c62-e618-4327-9b96-ab56041168b7",
    "600c90fc-55a8-449d-aec8-443cafa6f754",
    "e3665e48-db1f-45bd-9464-276fcac0be93",
    "0ac6a641-a03f-4f1e-b88f-fa1acd5fad87",
    "0035c5e5-5764-4023-87e2-0d6362e8de3d",
)

private val pricerSelectionEmails = setOf(
    "delaorcasa@outlook.com",
    "anaid.nava@irisaleados.com.mx",
    "gabrielloyola291@gmail.com",
    "transportestramuve@gmail.com",
    "j.gonzalez@progra.mx",
    "presidencia.ayc.transportes@gmail.com",
    "monterrey@wolfast.mx",
)

fun needsPricerSelection(profile: CarrierProfile): Boolean {
    val mail = profile.email.trim().lowercase()
    if (profile.uuid !in pricerSelectionIds && mail !in pricerSelectionEmails) return false
    return profile.pricerId.isNullOrBlank()
}

fun gate(profile: CarrierProfile?): Gate {
    if (profile == null) {
        return Gate.Deny("Usuario autenticado pero sin perfil. Contacta al administrador.")
    }
    if (needsPricerSelection(profile)) {
        return Gate.Deny("Contacta a Continente Cargo para selección de pricer.")
    }
    if (profile.role != "admin" && profile.status == "suspended") {
        return Gate.Deny("Tu cuenta está bloqueada. Ya no puedes operar ni recibir avisos.")
    }
    if (profile.role == "client" && profile.status == "pending_approval") {
        return Gate.Deny("Tu cuenta está en espera de aceptación. Un super administrador tiene que aceptarla para que puedas entrar.")
    }
    if (profile.role == "client" && profile.status != "approved") {
        return Gate.Deny("Tu solicitud de cliente no fue aceptada.")
    }
    if (profile.role != "admin" && profile.status != "approved") {
        return Gate.Deny("Tu cuenta está pendiente de aprobación. Te notificaremos cuando sea revisada.")
    }
    if (profile.role !in Catalog.appRoles) {
        return Gate.Deny("Esta cuenta no tiene acceso en la aplicación.")
    }
    return Gate.Allow
}

fun openLoads(loads: List<FreightLoad>): List<FreightLoad> =
    loads.filter { it.status == "Publicado" && !isFull(it) }.sortedBy { it.publishedAt.time }

fun loadsForPricer(
    profile: CarrierProfile?,
    loads: List<FreightLoad>,
    people: List<CarrierProfile>,
): List<FreightLoad> {
    profile ?: return emptyList()
    val ids = people.filter { it.pricerId == profile.uuid }.map { it.uuid }.toSet()
    return loads.filter { load ->
        (load.assignedCarrierId != null && load.assignedCarrierId in ids) ||
            load.confirmedCarrierIds.any { it in ids }
    }
}

fun clientLoads(profile: CarrierProfile?, loads: List<FreightLoad>): List<FreightLoad> {
    profile ?: return emptyList()
    return loads
        .filter { it.publishedBy == profile.uuid && it.status.isNotBlank() }
        .sortedByDescending { it.publishedAt.time }
}

fun clientOpportunities(profile: CarrierProfile?, loads: List<FreightLoad>): List<FreightLoad> {
    profile ?: return emptyList()
    if (profile.routes.isEmpty() || profile.coverageEquipmentTypes.isEmpty()) return emptyList()
    return loads.filter { load ->
        load.status == "Publicado" &&
            load.publishedBy != profile.uuid &&
            load.equipmentType in profile.coverageEquipmentTypes &&
            profile.routes.any { routeFits(it, load) }
    }
}

fun pendingCarriers(people: List<CarrierProfile>): List<CarrierProfile> =
    people
        .filter { it.status == "pending_approval" && it.role != "admin" && it.role != "pricer" && it.role != "client" }
        .sortedBy { it.name.lowercase() }

fun directoryFor(profile: CarrierProfile?, people: List<CarrierProfile>): List<CarrierProfile> {
    profile ?: return emptyList()
    val rows = when (profile.role) {
        "admin" -> people.filter { it.role in Catalog.carrierRoles || it.role == "client" }
        "pricer" -> people.filter { it.pricerId == profile.uuid && it.role in Catalog.carrierRoles }
        else -> emptyList()
    }
    return rows.sortedBy { it.name.lowercase() }
}

fun approvedPricers(people: List<CarrierProfile>): List<CarrierProfile> =
    people.filter { it.role == "pricer" && it.status == "approved" }.sortedBy { it.name.lowercase() }

fun availablePosts(units: List<FleetUnit>): List<FleetUnit> =
    units.filter { it.notes == "availability_post" && it.status == "Disponible" }

private fun routeFits(route: RouteCoverage, load: FreightLoad): Boolean {
    val direct = route.originState == load.originState && route.destinationState == load.destinationState
    val reverse = route.bidirectional && route.originState == load.destinationState && route.destinationState == load.originState
    return direct || reverse
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

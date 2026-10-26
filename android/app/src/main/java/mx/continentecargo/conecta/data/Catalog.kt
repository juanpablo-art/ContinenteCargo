package mx.continentecargo.conecta.data

object Catalog {
    val equipment = listOf(
        "1.5",
        "3.5",
        "Sprinter Van",
        "Caja Seca 48'",
        "Caja Seca 53'",
        "Plataforma",
        "Refrigerado",
        "Rabón",
        "Torton",
        "Sencillo Portacontenedor",
        "Full Portacontenedor",
    )

    val assignmentModes = listOf(
        "Tarifa Fija",
        "Subasta Inversa",
        "Confirmación Manual",
        "Consolidada LTL",
    )

    val tripSteps = listOf(
        "Asignado",
        "En camino a recolección",
        "En origen",
        "Cargado",
        "En tránsito",
        "Entregado",
    )

    val unitStatuses = listOf(
        "Disponible",
        "Reservada",
        "En viaje",
        "Fuera de servicio",
    )

    val mexicoStates = listOf(
        "Aguascalientes", "B.C.", "B.C.S.", "Campeche", "Chiapas", "Chihuahua",
        "Coahuila", "Colima", "CDMX", "Durango", "Estado de México", "Guanajuato",
        "Guerrero", "Hidalgo", "Jalisco", "Michoacán", "Morelos", "Nayarit",
        "N.L.", "Oaxaca", "Puebla", "Querétaro", "Quintana Roo", "S.L.P.",
        "Sinaloa", "Sonora", "Tabasco", "Tamaulipas", "Tlaxcala", "Veracruz",
        "Yucatán", "Zacatecas",
    )

    val usaStates = listOf(
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL", "GA", "HI",
        "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN",
        "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH",
        "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA",
        "WV", "WI", "WY",
    )

    val zones = listOf(
        Zone("Noroeste", listOf("B.C.", "B.C.S.", "Sonora", "Sinaloa", "Nayarit")),
        Zone("Norte", listOf("Chihuahua", "Coahuila", "Durango", "N.L.", "Tamaulipas", "Zacatecas")),
        Zone("Bajío", listOf("Aguascalientes", "Guanajuato", "Querétaro", "S.L.P.")),
        Zone("Centro Occidente", listOf("Jalisco", "Colima", "Michoacán")),
        Zone("Centro", listOf("CDMX", "Estado de México", "Hidalgo", "Morelos", "Puebla", "Tlaxcala")),
        Zone("Sur", listOf("Guerrero", "Oaxaca", "Veracruz")),
        Zone("Sureste", listOf("Campeche", "Chiapas", "Quintana Roo", "Tabasco", "Yucatán")),
    )

    val genericEmailDomains = setOf(
        "gmail.com", "googlemail.com", "hotmail.com", "hotmail.com.mx",
        "outlook.com", "outlook.com.mx", "live.com", "live.com.mx",
        "yahoo.com", "yahoo.com.mx", "icloud.com", "me.com", "msn.com",
        "proton.me", "protonmail.com",
    )

    val carrierRoles = setOf("carrier", "independent_operator")

    val appRoles = setOf("admin", "pricer", "client", "carrier", "independent_operator")

    val openOfferStatuses = setOf("Activa", "Ganando", "Superada", "PendienteAprobacion")

    fun zoneOf(state: String): String? = zones.firstOrNull { state in it.states }?.id

    fun roleLabel(role: String): String = when (role) {
        "carrier" -> "Línea transportista"
        "independent_operator" -> "Operador independiente"
        "admin" -> "Administrador"
        "pricer" -> "Pricer"
        "client" -> "Cliente"
        "altas" -> "Control de altas"
        else -> role
    }

    fun statusLabel(status: String): String = when (status) {
        "approved" -> "Aprobado"
        "pending_approval" -> "Pendiente"
        "suspended" -> "Bloqueado"
        "rejected" -> "Rechazado"
        else -> status
    }
}

data class Zone(val id: String, val states: List<String>)

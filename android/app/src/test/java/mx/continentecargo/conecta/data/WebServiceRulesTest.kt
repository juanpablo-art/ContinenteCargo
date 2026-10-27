package mx.continentecargo.conecta.data

import mx.continentecargo.conecta.carrier
import mx.continentecargo.conecta.load
import mx.continentecargo.conecta.offer
import mx.continentecargo.conecta.unit
import mx.continentecargo.conecta.data.RouteCoverage
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Date

/**
 * Service rules copied from the public Continente Conecta web bundle:
 * coverage matcher, carrier home filter, offers, trips, units, and login gate.
 */
class WebServiceRulesTest {

    @Test
    fun carrierSeesPublishedLoadInsideCoverageAndEquipment() {
        val me = carrier()
        val matching = load()
        val otherEquipment = load(id = "other", equipmentType = "Refrigerado")
        val otherState = load(id = "far", originState = "Chiapas", destinationState = "Yucatán")

        val visible = visibleLoads(me, listOf(matching, otherEquipment, otherState), emptySet(), emptySet())

        assertEquals(listOf("load-1"), visible.map { it.id })
    }

    @Test
    fun passedRouteAndPassedLoadAreHiddenUnlessAlreadyMine() {
        val me = carrier()
        val open = load()
        val mine = load(id = "mine", status = "Asignado", assignedCarrierId = me.uuid, originState = "Chiapas", destinationState = "Yucatán")
        val key = "N.L.|Jalisco|Caja Seca 53'"

        val visible = visibleLoads(me, listOf(open, mine), setOf(key), setOf("load-1"))

        assertEquals(listOf("mine"), visible.map { it.id })
    }

    @Test
    fun fullPublishedLoadIsHiddenAndLtlRequiresTheFlag() {
        val me = carrier(handlesLTL = false)
        val full = load(unitCount = 2, confirmedUnitCount = 2)
        val ltl = load(id = "ltl", assignmentMode = "Consolidada LTL", equipmentType = "Rabón", originState = "Chiapas", destinationState = "Yucatán")

        assertTrue(visibleLoads(me, listOf(full, ltl), emptySet(), emptySet()).isEmpty())
        assertEquals(
            listOf("ltl"),
            visibleLoads(me.copy(handlesLTL = true), listOf(ltl), emptySet(), emptySet()).map { it.id },
        )
    }

    @Test
    fun sameStateLoadUsesLocalOrIntrastateLikeTheWeb() {
        val local = carrier(
            handlesLocal = true,
            handlesIntraState = false,
            routes = emptyList(),
            coverageStates = emptyList(),
        )
        assertTrue(covers(local, "Monterrey", "N.L.", "Monterrey", "N.L.", "Caja Seca 53'"))
        assertFalse(covers(local, "Monterrey", "N.L.", "Apodaca", "N.L.", "Caja Seca 53'"))
        assertTrue(
            covers(
                local.copy(handlesLocal = false, handlesIntraState = true),
                "Monterrey",
                "N.L.",
                "Apodaca",
                "N.L.",
                "Caja Seca 53'",
            ),
        )
    }

    @Test
    fun routeBeatsStateCoverageAndRespectsEquipment() {
        val me = carrier(
            coverageStates = listOf("N.L.", "Jalisco"),
            routes = listOf(
                RouteCoverage("r1", "N.L.", "CDMX", bidirectional = true, equipmentTypes = listOf("Caja Seca 53'")),
            ),
        )
        assertTrue(covers(me, "Monterrey", "N.L.", "Ciudad de México", "CDMX", "Caja Seca 53'"))
        assertTrue(covers(me, "Ciudad de México", "CDMX", "Monterrey", "N.L.", "Caja Seca 53'"))
        assertFalse(covers(me, "Monterrey", "N.L.", "Ciudad de México", "CDMX", "Refrigerado"))
        assertFalse(covers(me, "Monterrey", "N.L.", "Guadalajara", "Jalisco", "Caja Seca 53'"))
    }

    @Test
    fun usaCoverageMatchesTheWebBranches() {
        val closed = carrier(coversUSA = false, coverageStates = emptyList())
        assertFalse(covers(closed, "Laredo", "TX", "Dallas", "TX", "Caja Seca 53'"))

        val open = closed.copy(coversUSA = true)
        assertTrue(covers(open, "Laredo", "TX", "Dallas", "TX", "Caja Seca 53'"))
        assertFalse(covers(open.copy(coverageUSAStates = listOf("TX")), "Dallas", "TX", "Los Angeles", "CA", "Caja Seca 53'"))
    }

    @Test
    fun offersTripsAndUnitsFollowTheCarrierQueries() {
        val me = carrier()
        val offers = listOf(
            offer(status = "Activa"),
            offer(id = "won", status = "Ganadora", loadId = "won-load"),
            offer(id = "lost", status = "Perdida"),
            offer(id = "other", carrierId = "someone-else", status = "Activa"),
        )
        assertEquals(listOf("offer-1"), myOffers(me, offers).map { it.id })

        val trips = myTrips(
            me,
            listOf(
                load(id = "assigned", status = "Asignado", assignedCarrierId = me.uuid),
                load(id = "won-load", status = "Asignado"),
                load(id = "stranger", status = "Asignado", assignedCarrierId = "other"),
            ),
            offers,
        )
        assertEquals(setOf("assigned", "won-load"), trips.map { it.id }.toSet())

        val fleet = myUnits(
            me,
            listOf(
                unit(),
                unit(id = "post", notes = "availability_post"),
                unit(id = "company", ownerId = "company-1"),
                unit(id = "foreign", ownerId = "other"),
            ),
        )
        assertEquals(setOf("unit-1", "company"), fleet.map { it.id }.toSet())
    }

    @Test
    fun privateAddressAppearsOnlyAfterTheCarrierIsOnTheLoad() {
        val me = carrier()
        val open = load()
        assertFalse(canSeePrivate(me, open))
        assertTrue(canSeePrivate(me, open.copy(confirmedCarrierIds = listOf(me.uuid))))
        assertTrue(canSeePrivate(me, open.copy(assignedCarrierId = me.uuid)))
        assertTrue(canSeePrivate(carrier(role = "admin"), open))
        assertTrue(canSeePrivate(carrier(role = "pricer"), open))
        assertFalse(canSeePrivate(carrier(role = "client", uuid = "client-9"), open))
    }

    @Test
    fun fixedPriceAboveTheAuthorizedMaxNeedsStaffApproval() {
        val published = load(offeredPrice = 18000.0, maxAuthorizedPriceSinIVA = 20000.0)
        assertFalse(needsCounterOffer(published, 18000.0))
        assertFalse(needsCounterOffer(published, 19000.0))
        assertTrue(needsCounterOffer(published, 21000.0))
        assertTrue(needsCounterOffer(published.copy(maxAuthorizedPriceSinIVA = null), 18001.0))
    }

    @Test
    fun eligibleUnitMustBeAvailableBeforePickupAndMatchEquipment() {
        val me = carrier()
        val freight = load(pickupDate = Date(1_700_000_000_000L))
        val units = listOf(
            unit(),
            unit(id = "late", availableFrom = Date(1_800_000_000_000L)),
            unit(id = "cold", equipmentType = "Refrigerado"),
            unit(id = "busy", status = "En viaje"),
        )
        assertEquals(listOf("unit-1"), eligibleUnits(me, units, freight).map { it.id })
    }

    @Test
    fun loginGateMatchesTheWebRoleMessages() {
        assertEquals(Gate.Allow, gate(carrier()))
        assertEquals(Gate.Allow, gate(carrier(role = "independent_operator")))
        assertEquals(Gate.Allow, gate(carrier(role = "admin", status = "pending_approval")))
        assertEquals(Gate.Allow, gate(carrier(role = "admin", status = "suspended")))
        assertEquals(Gate.Allow, gate(carrier(role = "pricer")))
        assertEquals(Gate.Allow, gate(carrier(role = "client")))
        assertTrue((gate(null) as Gate.Deny).message.contains("sin perfil"))
        assertTrue((gate(carrier(status = "suspended")) as Gate.Deny).message.contains("bloqueada"))
        assertTrue((gate(carrier(status = "pending_approval")) as Gate.Deny).message.contains("pendiente de aprobación"))
        assertTrue((gate(carrier(role = "pricer", status = "pending_approval")) as Gate.Deny).message.contains("pendiente de aprobación"))
        assertTrue(
            (gate(carrier(role = "client", status = "pending_approval")) as Gate.Deny).message.contains("espera de aceptación"),
        )
        assertTrue((gate(carrier(role = "client", status = "rejected")) as Gate.Deny).message.contains("no fue aceptada"))
        assertTrue((gate(carrier(role = "altas")) as Gate.Deny).message.contains("no tiene acceso"))
        val waiting = carrier(uuid = "033cdbf4-e582-4989-9c46-9b2c1fdc2f82", pricerId = null)
        assertTrue((gate(waiting) as Gate.Deny).message.contains("selección de pricer"))
        assertEquals(Gate.Allow, gate(waiting.copy(pricerId = "pricer-1")))
    }

    @Test
    fun eachRoleSeesTheSameLoadSlicesAsTheWeb() {
        val pricer = carrier(role = "pricer", uuid = "pricer-1")
        val line = carrier(uuid = "line-1", pricerId = "pricer-1")
        val client = carrier(
            role = "client",
            uuid = "client-1",
            routes = listOf(
                RouteCoverage("r1", "N.L.", "Jalisco", bidirectional = true, equipmentTypes = emptyList()),
            ),
            coverageEquipmentTypes = listOf("Caja Seca 53'"),
        )
        val loads = listOf(
            load(id = "open"),
            load(id = "taken", status = "Asignado", assignedCarrierId = "line-1"),
            load(id = "full", confirmedUnitCount = 1),
            load(id = "mine", publishedBy = "client-1", originState = "Sonora", destinationState = "Chihuahua"),
        )
        assertEquals(listOf("taken"), loadsForPricer(pricer, loads, listOf(line)).map { it.id })
        assertEquals(listOf("open", "mine"), openLoads(loads).map { it.id })
        assertEquals(listOf("mine"), clientLoads(client, loads).map { it.id })
        assertEquals(listOf("open", "full"), clientOpportunities(client, loads).map { it.id })
        assertTrue(clientOpportunities(client.copy(routes = emptyList()), loads).isEmpty())
        assertEquals(listOf(line.uuid), directoryFor(pricer, listOf(line, carrier(uuid = "other"))).map { it.uuid })
        assertEquals(listOf("line-1"), pendingCarriers(listOf(line.copy(status = "pending_approval"), client)).map { it.uuid })
        val fleet = myUnits(carrier(role = "admin"), listOf(unit(), unit(id = "post", notes = "availability_post")))
        assertEquals(listOf("unit-1"), fleet.map { it.id })
    }

    @Test
    fun phoneEmailAndMoneyFollowTheMexicanWebRules() {
        assertNull(phoneProblem("81 1234 5678"))
        assertEquals("8112345678", phoneDigits("+52 81 1234 5678"))
        assertEquals("Se requieren 10 dígitos.", phoneProblem("123"))
        assertTrue(emailValid("linea@norte.mx"))
        assertFalse(emailValid("linea@norte"))
        assertTrue(domainValid("norte.mx"))
        assertFalse(domainValid("gmail"))
        assertTrue("gmail.com" in Catalog.genericEmailDomains)
        assertTrue(formatMoney(18000.0).contains("18"))
        assertEquals("Más IVA", vatLabel(false))
        assertEquals("IVA incluido", vatLabel(true))
    }

    @Test
    fun catalogMatchesTheWebLists() {
        assertEquals(
            listOf("Tarifa Fija", "Subasta Inversa", "Confirmación Manual", "Consolidada LTL"),
            Catalog.assignmentModes,
        )
        assertEquals(
            listOf("Asignado", "En camino a recolección", "En origen", "Cargado", "En tránsito", "Entregado"),
            Catalog.tripSteps,
        )
        assertTrue("Caja Seca 53'" in Catalog.equipment)
        assertEquals("Norte", Catalog.zoneOf("N.L."))
        assertEquals("Línea transportista", Catalog.roleLabel("carrier"))
        assertEquals("Operador independiente", Catalog.roleLabel("independent_operator"))
    }

    @Test
    fun webDocumentsKeepRequiredLoadOfferAndNoticeFields() {
        val parsed = parseLoad(
            "doc-1",
            mapOf(
                "reference" to "CC-9",
                "originCity" to "Monterrey",
                "originState" to "N.L.",
                "destinationCity" to "Guadalajara",
                "destinationState" to "Jalisco",
                "equipmentType" to "torton",
                "assignmentMode" to "Subasta Inversa",
                "status" to "Publicado",
                "publishedBy" to "staff",
                "offeredPrice" to 15000,
                "currency" to "MXN",
                "minBidDecrement" to 0,
            ),
        )
        assertEquals("doc-1", parsed?.id)
        assertEquals("Torton", parsed?.equipmentType)
        assertEquals(100.0, parsed?.minBidDecrement)
        assertEquals(null, parseLoad("x", mapOf("reference" to "CC-9")))

        val bid = parseOffer(
            "bid-1",
            mapOf(
                "loadId" to "doc-1",
                "carrierId" to "carrier-1",
                "carrierName" to "Línea Norte",
                "status" to "Ganando",
                "amount" to 14000,
                "staffCounterPrice" to 13500,
                "staffCounterStatus" to "PendienteTransportista",
            ),
        )
        assertEquals("Ganando", bid?.status)
        assertEquals(13500.0, bid?.staffCounterPrice)
        assertEquals("PendienteTransportista", bid?.staffCounterStatus)

        val notice = parseNotice(
            "note-1",
            mapOf(
                "userId" to "carrier-1",
                "type" to "new_load",
                "title" to "Nueva carga en tu ruta",
                "body" to "Monterrey → Guadalajara",
                "isRead" to false,
            ),
        )
        assertEquals("note-1", notice?.id)
        assertFalse(notice!!.isRead)
    }

    @Test
    fun actionCopyMatchesTheWebLoadResponses() {
        assertEquals("¡Participación confirmada!", actionMessage("success"))
        assertEquals("Tu contra-oferta requiere aprobación del administrador.", actionMessage("pendingApproval"))
        assertEquals("El plazo para participar ya cerró.", actionMessage("deadlinePassed"))
        assertTrue(actionMessage("decrementTooSmall", "$100").contains("100"))
    }
}

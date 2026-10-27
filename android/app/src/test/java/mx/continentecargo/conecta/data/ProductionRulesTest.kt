package mx.continentecargo.conecta.data

import mx.continentecargo.conecta.carrier
import mx.continentecargo.conecta.unit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ProductionRulesTest {
    @Test
    fun tariffRowsFollowTheWebSanitizer() {
        assertNull(sanitizeTariffRow("", "Jalisco", "Caja Seca 53'", 1000.0, "MXN", "viaje", "", "manual"))
        assertNull(sanitizeTariffRow("N.L.", "Jalisco", "Caja Seca 53'", 0.0, "MXN", "viaje", "", "manual"))
        val row = sanitizeTariffRow(" N.L. ", "Jalisco", "Caja Seca 53'", 18500.5, "USD", "km", "  incluida ", "manual")
        assertEquals("N.L.", row?.origin)
        assertEquals(18500.5, row?.amount)
        assertEquals("USD", row?.currency)
        assertEquals("Por kilómetro", TariffBasis.label(row!!.basis))
        assertEquals("incluida", row.notes)
    }

    @Test
    fun availabilityPostUsesTheCompanyAndTheRouteStates() {
        val me = carrier(companyId = "company-9")
        val post = availabilityUnit(me, "Caja Seca 53'", 2, "N.L.", "CDMX", id = "post-1")
        assertEquals("company-9", post.ownerId)
        assertEquals("availability_post", post.notes)
        assertEquals("2", post.trailerNumber)
        assertEquals("N.L.", post.currentLocation)
        assertEquals(listOf("CDMX"), post.coverageZones)
        assertEquals(listOf("post-1"), myAvailability(me, listOf(post, unit())).map { it.id })
    }

    @Test
    fun clientPublishMatchesTheWebLoadDocument() {
        val client = carrier(role = "client", uuid = "client-1", name = "Ana")
        val input = ClientPublish(
            originCity = "Monterrey",
            originState = "N.L.",
            destinationCity = "Guadalajara",
            destinationState = "Jalisco",
            pickupDay = "2026-11-02",
            equipment = "Caja Seca 53'",
            merchandise = "Tarima",
            currency = "MXN",
            ltl = false,
            marketUsa = false,
        )
        assertNull(clientPublishError(client, input))
        assertEquals(
            "Completa origen, destino, fecha, equipo y qué se mueve.",
            clientPublishError(client, input.copy(merchandise = " ")),
        )
        assertEquals("Tu cuenta está en revisión.", clientPublishError(client.copy(status = "pending_approval"), input))
        val document = clientLoadDocument(client, input, "load-9", "CC-20261102-321")!!
        assertEquals("CC-20261102-321", document["reference"])
        assertEquals("Subasta Inversa", document["assignmentMode"])
        assertEquals(0.0, document["offeredPrice"])
        assertEquals("client-1", document["publishedBy"])
        assertEquals("Publicado", document["status"])
        assertEquals("Ana", document["clientContactName"])
        val ltl = clientLoadDocument(client, input.copy(ltl = true), "load-10", "CC-20261102-322")!!
        assertEquals("Consolidada LTL", ltl["assignmentMode"])
    }

    @Test
    fun paymentStatusLabelsMatchThePortal() {
        assertEquals("Pendiente", payStatusLabel("pending"))
        assertEquals("Programado", payStatusLabel("scheduled"))
        assertEquals("Pago parcial", payStatusLabel("partially_paid"))
        assertEquals("Pagado", payStatusLabel("paid"))
        assertEquals(
            listOf("line-1"),
            paymentCarriers(
                listOf(
                    carrier(uuid = "line-1"),
                    carrier(uuid = "blocked", status = "suspended"),
                    carrier(uuid = "admin", role = "admin"),
                ),
            ).map { it.uuid },
        )
    }
}

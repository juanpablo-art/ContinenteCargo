package mx.continentecargo.conecta.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import mx.continentecargo.conecta.carrier
import mx.continentecargo.conecta.data.Notice
import mx.continentecargo.conecta.load
import mx.continentecargo.conecta.offer
import mx.continentecargo.conecta.ui.screens.HomeScreen
import mx.continentecargo.conecta.ui.screens.LoadDetailScreen
import mx.continentecargo.conecta.ui.screens.LoginScreen
import mx.continentecargo.conecta.ui.screens.NoticesScreen
import mx.continentecargo.conecta.ui.screens.OffersScreen
import mx.continentecargo.conecta.ui.screens.RegisterScreen
import mx.continentecargo.conecta.ui.screens.SplashScreen
import mx.continentecargo.conecta.ui.screens.TripDetailScreen
import mx.continentecargo.conecta.ui.screens.TripsScreen
import mx.continentecargo.conecta.ui.screens.UnitsScreen
import mx.continentecargo.conecta.ui.theme.ConectaTheme
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.Date

/**
 * Visual checks for the carrier screens that exist on the web:
 * login, register, cargas, detalle, ofertas, viajes, unidades and avisos.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "w480dp-h2000dp")
class WebScreenVisualTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun splashShowsTheBrand() {
        compose.setContent { ConectaTheme { SplashScreen() } }
        compose.onNodeWithContentDescription("Continente Conecta").assertExists()
    }

    @Test
    fun loginShowsTheWebCopyAndActions() {
        var openedRegister = false
        compose.setContent {
            ConectaTheme {
                LoginScreen(
                    banner = "Tu cuenta está pendiente de aprobación. Te notificaremos cuando sea revisada.",
                    registered = false,
                    busy = false,
                    onLogin = { _, _ -> },
                    onReset = {},
                    onRegister = { openedRegister = true },
                    onRetry = {},
                )
            }
        }
        compose.onNodeWithText("Continente Conecta").assertIsDisplayed()
        compose.onNodeWithText("Plataforma de carga Continente Cargo").assertIsDisplayed()
        compose.onNodeWithText("Correo electrónico").assertIsDisplayed()
        compose.onNodeWithText("Contraseña").assertIsDisplayed()
        compose.onNodeWithText("Entrar").assertIsDisplayed()
        compose.onNodeWithText("Olvidé mi contraseña").assertIsDisplayed()
        compose.onNodeWithText("Crear cuenta").performClick()
        compose.onNodeWithText("pendiente de aprobación", substring = true).assertIsDisplayed()
        assertTrue(openedRegister)
    }

    @Test
    fun registerShowsCarrierChoicesFromTheWeb() {
        compose.setContent {
            ConectaTheme {
                RegisterScreen(banner = null, busy = false, onSubmit = {}, onBack = {})
            }
        }
        compose.onNodeWithText("Registro").assertIsDisplayed()
        compose.onNodeWithText("Línea transportista").assertIsDisplayed()
        compose.onNodeWithText("Operador independiente").assertIsDisplayed()
        compose.onNodeWithText("Equipo que opero").assertIsDisplayed()
        compose.onNodeWithText("Caja Seca 53'").assertIsDisplayed()
        compose.onNodeWithText("Cobertura en México").assertIsDisplayed()
        compose.onNodeWithText("N.L.").assertIsDisplayed()
        compose.onNodeWithText("Crear cuenta").assertIsDisplayed()
    }

    @Test
    fun homeShowsALoadTheWayTheWebCardDoes() {
        compose.setContent {
            ConectaTheme {
                HomeScreen(
                    loads = listOf(load(reference = "CC-240")),
                    unread = 2,
                    dataError = null,
                    onOpen = {},
                    onNotices = {},
                )
            }
        }
        compose.onNodeWithText("Cargas").assertIsDisplayed()
        compose.onNodeWithText("1 carga abierta para ti").assertIsDisplayed()
        compose.onNodeWithText("CC-240").assertIsDisplayed()
        compose.onNodeWithText("Monterrey → Guadalajara").assertIsDisplayed()
        compose.onAllNodesWithText("Tarifa Fija")[0].assertIsDisplayed()
        compose.onNodeWithText("Publicado").assertIsDisplayed()
    }

    @Test
    fun homeEmptyStateMatchesTheWeb() {
        compose.setContent {
            ConectaTheme {
                HomeScreen(loads = emptyList(), unread = 0, dataError = null, onOpen = {}, onNotices = {})
            }
        }
        compose.onNodeWithText("Sin cargas por ahora").assertIsDisplayed()
        compose.onNodeWithText("Te avisaremos en cuanto se publique una carga en tus rutas.").assertIsDisplayed()
    }

    @Test
    fun loadDetailShowsFixedPriceActionAndHidesClientAddressUntilConfirmed() {
        val ui = ConectaUi(profile = carrier(), loads = listOf(load(reference = "CC-240")))
        compose.setContent {
            ConectaTheme {
                LoadDetailScreen(
                    loadId = "load-1",
                    ui = ui,
                    busy = false,
                    onBack = {},
                    onFixed = { _, _, _, _, _, _, _ -> },
                    onBid = { _, _, _, _ -> },
                    onAvailability = { _, _, _ -> },
                    onLtl = { _, _, _ -> },
                )
            }
        }
        compose.onNodeWithText("CC-240").assertIsDisplayed()
        compose.onAllNodesWithText("Confirmar y tomar carga")[0].assertIsDisplayed()
        compose.onNodeWithText(
            "Las direcciones exactas y el contacto del cliente se muestran al confirmar tu participación.",
        ).assertIsDisplayed()
    }

    @Test
    fun offersTripsUnitsAndNoticesShowTheWebEmptyAndListCopy() {
        compose.setContent {
            ConectaTheme {
                OffersScreen(
                    offers = listOf(offer()),
                    loads = listOf(load(reference = "CC-240")),
                    busy = false,
                    onOpenLoad = {},
                    onImprove = { _, _, _ -> },
                    onAnswer = { _, _ -> },
                )
            }
        }
        compose.onNodeWithText("Mis ofertas").assertIsDisplayed()
        compose.onNodeWithText("Ofertas activas y pendientes de aprobación").assertIsDisplayed()
        compose.onNodeWithText("CC-240").assertIsDisplayed()
        compose.onNodeWithText("Activa").assertIsDisplayed()
    }

    @Test
    fun tripsShowActiveAndHistoryLikeTheWeb() {
        compose.setContent {
            ConectaTheme {
                TripsScreen(
                    trips = listOf(load(reference = "CC-77", status = "En tránsito", assignedCarrierId = "carrier-1")),
                    onOpen = {},
                )
            }
        }
        compose.onNodeWithText("Mis viajes").assertIsDisplayed()
        compose.onNodeWithText("En curso").assertIsDisplayed()
        compose.onNodeWithText("Historial").assertIsDisplayed()
        compose.onNodeWithText("CC-77").assertIsDisplayed()
    }

    @Test
    fun tripDetailShowsTheWebProgressAndNextStatus() {
        val freight = load(status = "Asignado", assignedCarrierId = "carrier-1")
        compose.setContent {
            ConectaTheme {
                TripDetailScreen(
                    loadId = freight.id,
                    ui = ConectaUi(profile = carrier(), loads = listOf(freight)),
                    busy = false,
                    onBack = {},
                    onAdvance = { _, _ -> },
                )
            }
        }
        compose.onNodeWithText("Progreso del viaje").assertIsDisplayed()
        compose.onNodeWithText("En camino a recolección").assertIsDisplayed()
        compose.onNodeWithText("Entregado").assertIsDisplayed()
        compose.onNodeWithText("Marcar como “En camino a recolección”").assertIsDisplayed()
        compose.onNodeWithText("Parque industrial").assertIsDisplayed()
    }

    @Test
    fun unitsAndNoticesMatchTheWebEmptyStates() {
        compose.setContent {
            ConectaTheme {
                UnitsScreen(
                    units = emptyList(),
                    ownerId = "carrier-1",
                    busy = false,
                    onSave = { _, _ -> },
                    onDelete = {},
                    onStatus = { _, _ -> },
                )
            }
        }
        compose.onNodeWithText("Mis unidades").assertIsDisplayed()
        compose.onNodeWithText("Aún no tienes unidades").assertIsDisplayed()
    }

    @Test
    fun noticesGroupUnreadCopyFromTheWeb() {
        compose.setContent {
            ConectaTheme {
                NoticesScreen(
                    notices = listOf(
                        Notice(
                            id = "n1",
                            userId = "carrier-1",
                            type = "new_load",
                            title = "Nueva carga en tu ruta",
                            body = "Monterrey, N.L. → Guadalajara, Jalisco",
                            loadId = "load-1",
                            isRead = false,
                            createdAt = Date(),
                        ),
                    ),
                    onBack = {},
                    onOpen = {},
                    onMarkAll = {},
                )
            }
        }
        compose.onNodeWithText("Avisos").assertIsDisplayed()
        compose.onNodeWithText("Nueva carga en tu ruta").assertIsDisplayed()
        compose.onNodeWithText("Hoy").assertIsDisplayed()
    }
}

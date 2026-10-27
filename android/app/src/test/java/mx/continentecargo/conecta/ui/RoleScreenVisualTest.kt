package mx.continentecargo.conecta.ui

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import org.junit.Assert.assertTrue
import mx.continentecargo.conecta.carrier
import mx.continentecargo.conecta.load
import mx.continentecargo.conecta.ui.screens.AdminHomeScreen
import mx.continentecargo.conecta.ui.screens.ClientHomeScreen
import mx.continentecargo.conecta.ui.screens.DirectoryScreen
import mx.continentecargo.conecta.ui.screens.LoadDetailScreen
import mx.continentecargo.conecta.ui.screens.PricerLoadsScreen
import mx.continentecargo.conecta.ui.theme.ConectaTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "w480dp-h2000dp")
class RoleScreenVisualTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun adminHomeShowsTheOperationPanel() {
        compose.setContent {
            ConectaTheme {
                AdminHomeScreen(
                    name = "Edgardo",
                    loads = listOf(load(reference = "CC-240")),
                    offers = emptyList(),
                    people = listOf(carrier(name = "Línea Norte", status = "pending_approval")),
                    unread = 0,
                    onOpenLoads = {},
                    onOpenDirectory = {},
                    onNotices = {},
                )
            }
        }
        compose.onNodeWithText("Panel de operación").assertIsDisplayed()
        compose.onNodeWithText("Hola, Edgardo").assertIsDisplayed()
        compose.onNodeWithText("Cargas publicadas").assertIsDisplayed()
        compose.onNodeWithText("Línea Norte").assertIsDisplayed()
    }

    @Test
    fun clientHomeShowsHistoryAndOpportunities() {
        val profile = carrier(role = "client", uuid = "client-1", name = "Ana")
        compose.setContent {
            ConectaTheme {
                ClientHomeScreen(
                    name = "Ana",
                    loads = listOf(load(reference = "CC-9", publishedBy = "client-1")),
                    profile = profile,
                    units = emptyList(),
                    unread = 0,
                    onHistory = {},
                    onOpportunities = {},
                    onNotices = {},
                )
            }
        }
        compose.onNodeWithText("Hola, Ana").assertIsDisplayed()
        compose.onNodeWithText("Historial de cargas").assertIsDisplayed()
        compose.onNodeWithText("Oportunidades").assertIsDisplayed()
        compose.onNodeWithText("1 en historial · 1 abierta · 0 entregadas").assertIsDisplayed()
    }

    @Test
    fun pricerBoardSeparatesOpenLoadsFromThePortfolio() {
        compose.setContent {
            ConectaTheme {
                PricerLoadsScreen(
                    open = listOf(load(reference = "CC-1")),
                    portfolio = emptyList(),
                    onOpen = {},
                )
            }
        }
        compose.onNodeWithText("Por cubrir").assertIsDisplayed()
        compose.onNodeWithText("Cartera").assertIsDisplayed()
        compose.onNodeWithText("CC-1").assertIsDisplayed()
        compose.onNodeWithText("1 carga publicada todavía sin transportista").assertIsDisplayed()
    }

    @Test
    fun directoryShowsCarrierStatusTheWayTheWebDoes() {
        compose.setContent {
            ConectaTheme {
                DirectoryScreen(
                    title = "Transportistas",
                    people = listOf(carrier(name = "Línea Norte", status = "pending_approval")),
                    emptyTitle = "Sin registros",
                    emptySubtitle = "Los transportistas y clientes aparecen aquí.",
                )
            }
        }
        compose.onNodeWithText("Transportistas").assertIsDisplayed()
        compose.onNodeWithText("Línea Norte").assertIsDisplayed()
        compose.onNodeWithText("Línea transportista", substring = true).assertIsDisplayed()
    }

    @Test
    fun staffLoadDetailShowsOffersAndHidesTheCarrierTakeButton() {
        val ui = ConectaUi(
            profile = carrier(role = "admin"),
            loads = listOf(load(reference = "CC-240")),
            offers = listOf(mx.continentecargo.conecta.offer()),
        )
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
        compose.onNodeWithText("Ofertas").assertIsDisplayed()
        compose.onNodeWithText("Línea Norte", substring = true).assertIsDisplayed()
        compose.onNodeWithText("Activa", substring = true).assertIsDisplayed()
        compose.onNodeWithText("Parque industrial").assertIsDisplayed()
        assertTrue(compose.onAllNodesWithText("Confirmar y tomar carga").fetchSemanticsNodes().isEmpty())
    }
}

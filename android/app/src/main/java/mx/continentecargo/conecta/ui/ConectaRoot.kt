package mx.continentecargo.conecta.ui

import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.LocalShipping
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Route
import androidx.compose.material.icons.outlined.Sell
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import mx.continentecargo.conecta.data.myOffers
import mx.continentecargo.conecta.data.myTrips
import mx.continentecargo.conecta.data.myUnits
import mx.continentecargo.conecta.data.visibleLoads
import mx.continentecargo.conecta.ui.screens.HomeScreen
import mx.continentecargo.conecta.ui.screens.LoadDetailScreen
import mx.continentecargo.conecta.ui.screens.LoginScreen
import mx.continentecargo.conecta.ui.screens.NoticesScreen
import mx.continentecargo.conecta.ui.screens.OffersScreen
import mx.continentecargo.conecta.ui.screens.ProfileScreen
import mx.continentecargo.conecta.ui.screens.RegisterScreen
import mx.continentecargo.conecta.ui.screens.SplashScreen
import mx.continentecargo.conecta.ui.screens.TripDetailScreen
import mx.continentecargo.conecta.ui.screens.TripsScreen
import mx.continentecargo.conecta.ui.screens.UnitsScreen
import mx.continentecargo.conecta.ui.theme.BrandSoft
import mx.continentecargo.conecta.ui.theme.Canvas
import mx.continentecargo.conecta.ui.theme.Muted
import mx.continentecargo.conecta.ui.theme.NavyDeep

private data class Tab(val route: String, val label: String, val icon: ImageVector)

private val tabs = listOf(
    Tab("home", "Cargas", Icons.Outlined.Home),
    Tab("offers", "Ofertas", Icons.Outlined.Sell),
    Tab("trips", "Viajes", Icons.Outlined.Route),
    Tab("units", "Unidades", Icons.Outlined.LocalShipping),
    Tab("profile", "Perfil", Icons.Outlined.Person),
)

@Composable
fun ConectaRoot(vm: ConectaViewModel) {
    val ui by vm.ui.collectAsStateWithLifecycle()
    if (ui.booting) {
        SplashScreen()
        return
    }
    val nav = rememberNavController()
    val snackbar = remember { SnackbarHostState() }
    val signedIn = ui.profile != null
    LaunchedEffect(ui.toast) {
        val message = ui.toast ?: return@LaunchedEffect
        snackbar.showSnackbar(message)
        vm.clearToast()
    }
    LaunchedEffect(signedIn) {
        val target = if (signedIn) "home" else "login"
        nav.navigate(target) {
            popUpTo(nav.graph.findStartDestination().id) { inclusive = true }
            launchSingleTop = true
        }
    }
    LaunchedEffect(ui.registered) {
        if (ui.registered) {
            nav.popBackStack("login", inclusive = false)
        }
    }
    val backStack by nav.currentBackStackEntryAsState()
    val route = backStack?.destination?.route
    val showBar = tabs.any { it.route == route }
    val loads = visibleLoads(ui.profile, ui.loads, ui.passedRoutes, ui.passedLoadIds)
    val offers = myOffers(ui.profile, ui.offers)
    val trips = myTrips(ui.profile, ui.loads, ui.offers)
    val units = myUnits(ui.profile, ui.units)
    Scaffold(
        containerColor = Canvas,
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        snackbarHost = { SnackbarHost(snackbar) },
        bottomBar = {
            if (showBar) {
                NavigationBar(containerColor = Color.White) {
                    tabs.forEach { tab ->
                        NavigationBarItem(
                            selected = route == tab.route,
                            onClick = {
                                nav.navigate(tab.route) {
                                    popUpTo(nav.graph.findStartDestination().id) { saveState = true }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = { Icon(tab.icon, contentDescription = tab.label) },
                            label = { Text(tab.label) },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = NavyDeep,
                                selectedTextColor = NavyDeep,
                                indicatorColor = BrandSoft,
                                unselectedIconColor = Muted,
                                unselectedTextColor = Muted,
                            ),
                        )
                    }
                }
            }
        },
    ) { padding ->
        NavHost(
            navController = nav,
            startDestination = if (signedIn) "home" else "login",
            modifier = Modifier.padding(padding),
        ) {
            composable("login") {
                LoginScreen(
                    banner = ui.banner,
                    registered = ui.registered,
                    busy = ui.busy,
                    onLogin = vm::login,
                    onReset = vm::sendReset,
                    onRegister = { nav.navigate("register") },
                    onRetry = vm::retry,
                )
            }
            composable("register") {
                RegisterScreen(
                    banner = ui.banner,
                    busy = ui.busy,
                    onSubmit = vm::register,
                    onBack = { nav.popBackStack() },
                )
            }
            composable("home") {
                HomeScreen(
                    loads = loads,
                    unread = ui.notices.count { !it.isRead },
                    dataError = ui.dataError,
                    onOpen = { nav.navigate("load/${it.id}") },
                    onNotices = { nav.navigate("notices") },
                )
            }
            composable("offers") {
                OffersScreen(
                    offers = offers,
                    loads = ui.loads,
                    busy = ui.busy,
                    onOpenLoad = { nav.navigate("load/$it") },
                    onImprove = vm::improveOffer,
                    onAnswer = vm::answerCounter,
                )
            }
            composable("trips") {
                TripsScreen(trips = trips, onOpen = { nav.navigate("trip/${it.id}") })
            }
            composable("units") {
                UnitsScreen(
                    units = units,
                    ownerId = ui.profile?.uuid.orEmpty(),
                    busy = ui.busy,
                    onSave = vm::saveUnit,
                    onDelete = vm::deleteUnit,
                    onStatus = vm::setUnitStatus,
                )
            }
            composable("profile") {
                ui.profile?.let { profile ->
                    ProfileScreen(
                        profile = profile,
                        busy = ui.busy,
                        onSave = vm::saveProfile,
                        onLtl = vm::setLtl,
                        onHazmat = vm::setHazmat,
                        onRoutes = vm::saveRoutes,
                        onNotices = { nav.navigate("notices") },
                        onLogout = vm::logout,
                    )
                }
            }
            composable("notices") {
                NoticesScreen(
                    notices = ui.notices,
                    onBack = { nav.popBackStack() },
                    onMarkAll = vm::markAllRead,
                    onOpen = { notice ->
                        vm.openNotice(notice)
                        val id = notice.loadId ?: return@NoticesScreen
                        val destination = if (trips.any { it.id == id }) "trip/$id" else "load/$id"
                        nav.navigate(destination)
                    },
                )
            }
            composable("load/{id}") { entry ->
                LoadDetailScreen(
                    loadId = entry.arguments?.getString("id").orEmpty(),
                    ui = ui,
                    busy = ui.busy,
                    onBack = { nav.popBackStack() },
                    onFixed = vm::confirmFixed,
                    onBid = vm::placeBid,
                    onAvailability = vm::indicate,
                    onLtl = vm::quoteLtl,
                )
            }
            composable("trip/{id}") { entry ->
                TripDetailScreen(
                    loadId = entry.arguments?.getString("id").orEmpty(),
                    ui = ui,
                    busy = ui.busy,
                    onBack = { nav.popBackStack() },
                    onAdvance = vm::advanceTrip,
                )
            }
        }
    }
}

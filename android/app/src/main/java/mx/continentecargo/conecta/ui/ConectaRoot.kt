package mx.continentecargo.conecta.ui

import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.GridView
import androidx.compose.material.icons.outlined.Groups
import androidx.compose.material.icons.outlined.History
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Inventory2
import androidx.compose.material.icons.outlined.LocalShipping
import androidx.compose.material.icons.outlined.MoreHoriz
import androidx.compose.material.icons.outlined.Route
import androidx.compose.material.icons.outlined.Sell
import androidx.compose.material.icons.outlined.TravelExplore
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import mx.continentecargo.conecta.data.availablePosts
import mx.continentecargo.conecta.data.clientLoads
import mx.continentecargo.conecta.data.clientOpportunities
import mx.continentecargo.conecta.data.directoryFor
import mx.continentecargo.conecta.data.loadsForPricer
import mx.continentecargo.conecta.data.myAvailability
import mx.continentecargo.conecta.data.myOffers
import mx.continentecargo.conecta.data.paymentCarriers
import mx.continentecargo.conecta.data.myTrips
import mx.continentecargo.conecta.data.myUnits
import mx.continentecargo.conecta.data.openLoads
import mx.continentecargo.conecta.data.visibleLoads
import mx.continentecargo.conecta.ui.screens.AdminHomeScreen
import mx.continentecargo.conecta.ui.screens.ClientHomeScreen
import mx.continentecargo.conecta.ui.screens.DirectoryScreen
import mx.continentecargo.conecta.ui.screens.FleetBoard
import mx.continentecargo.conecta.ui.screens.HomeScreen
import mx.continentecargo.conecta.ui.screens.LoadBoard
import mx.continentecargo.conecta.ui.screens.LoadDetailScreen
import mx.continentecargo.conecta.ui.screens.AvailabilityScreen
import mx.continentecargo.conecta.ui.screens.MoreItem
import mx.continentecargo.conecta.ui.screens.MoreScreen
import mx.continentecargo.conecta.ui.screens.OpportunitiesScreen
import mx.continentecargo.conecta.ui.screens.PaymentsScreen
import mx.continentecargo.conecta.ui.screens.PublishLoadScreen
import mx.continentecargo.conecta.ui.screens.TariffListScreen
import mx.continentecargo.conecta.ui.screens.TariffScreen
import mx.continentecargo.conecta.ui.screens.PricerHomeScreen
import mx.continentecargo.conecta.ui.screens.PricerLoadsScreen
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

private val carrierTabs = listOf(
    Tab("home", "Cargas", Icons.Outlined.Home),
    Tab("offers", "Ofertas", Icons.Outlined.Sell),
    Tab("trips", "Viajes", Icons.Outlined.Route),
    Tab("units", "Unidades", Icons.Outlined.LocalShipping),
    Tab("more", "Más", Icons.Outlined.MoreHoriz),
)

private fun tabsFor(role: String?): List<Tab> = when (role) {
    "admin" -> listOf(
        Tab("home", "Inicio", Icons.Outlined.GridView),
        Tab("loads", "Cargas", Icons.Outlined.Inventory2),
        Tab("directory", "Transportistas", Icons.Outlined.Groups),
        Tab("units", "Unidades", Icons.Outlined.LocalShipping),
        Tab("more", "Más", Icons.Outlined.MoreHoriz),
    )
    "pricer" -> listOf(
        Tab("home", "Inicio", Icons.Outlined.GridView),
        Tab("loads", "Cargas", Icons.Outlined.Inventory2),
        Tab("directory", "Directorio", Icons.Outlined.Groups),
        Tab("more", "Más", Icons.Outlined.MoreHoriz),
    )
    "client" -> listOf(
        Tab("home", "Inicio", Icons.Outlined.Home),
        Tab("history", "Historial", Icons.Outlined.History),
        Tab("opportunities", "Oportunidades", Icons.Outlined.TravelExplore),
        Tab("more", "Más", Icons.Outlined.MoreHoriz),
    )
    else -> carrierTabs
}

private fun moreItems(role: String?): List<MoreItem> = when (role) {
    "admin", "pricer" -> listOf(
        MoreItem("tariffs", "Tarifarios", "Tarifas publicadas por los transportistas."),
        MoreItem("payments", "Pagos", "Cuenta del transportista y pagos de Operaciones."),
        MoreItem("notices", "Avisos", "Avisos de la operación."),
        MoreItem("profile", "Perfil", "Nombre, teléfono y sesión."),
    )
    "client" -> listOf(
        MoreItem("publish", "Publicar", "Publica una carga sin poner precio."),
        MoreItem("routes", "Rutas", "Rutas y tipos de unidad para las oportunidades."),
        MoreItem("notices", "Avisos", "Avisos de tus cargas."),
        MoreItem("profile", "Perfil", "Nombre, teléfono y sesión."),
    )
    else -> listOf(
        MoreItem("availability", "Disponibilidad", "Avisa que tienes unidades libres."),
        MoreItem("tariff", "Tarifario", "La tarifa con la que Continente Cargo puede asignarte."),
        MoreItem("payments", "Pagos", "Tu cuenta y lo que Operaciones ya registró."),
        MoreItem("notices", "Avisos", "Avisos de cargas y viajes."),
        MoreItem("profile", "Perfil", "Nombre, teléfono, rutas y sesión."),
    )
}

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
    val tabs = tabsFor(ui.profile?.role)
    val showBar = tabs.any { it.route == route }
    val loads = visibleLoads(ui.profile, ui.loads, ui.passedRoutes, ui.passedLoadIds)
    val unread = ui.notices.count { !it.isRead }
    val role = ui.profile?.role
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
                when (role) {
                    "admin" -> AdminHomeScreen(
                        name = ui.profile?.name.orEmpty(),
                        loads = ui.loads,
                        offers = ui.offers,
                        people = ui.directory,
                        unread = unread,
                        onOpenLoads = { nav.navigate("loads") },
                        onOpenDirectory = { nav.navigate("directory") },
                        onNotices = { nav.navigate("notices") },
                        onApprove = vm::approvePerson,
                        onReject = vm::rejectPerson,
                        onApproveOffer = vm::approveOffer,
                        onRejectOffer = vm::rejectOffer,
                    )
                    "pricer" -> ui.profile?.let { profile ->
                        PricerHomeScreen(
                            name = profile.name,
                            loads = ui.loads,
                            people = ui.directory,
                            profile = profile,
                            unread = unread,
                            onOpenLoads = { nav.navigate("loads") },
                            onNotices = { nav.navigate("notices") },
                        )
                    }
                    "client" -> ui.profile?.let { profile ->
                        ClientHomeScreen(
                            name = profile.name,
                            loads = ui.loads,
                            profile = profile,
                            units = ui.units,
                            unread = unread,
                            onHistory = { nav.navigate("history") },
                            onOpportunities = { nav.navigate("opportunities") },
                            onNotices = { nav.navigate("notices") },
                        )
                    }
                    else -> HomeScreen(
                        loads = loads,
                        unread = unread,
                        dataError = ui.dataError,
                        onOpen = { nav.navigate("load/${it.id}") },
                        onNotices = { nav.navigate("notices") },
                    )
                }
            }
            composable("loads") {
                when (role) {
                    "pricer" -> PricerLoadsScreen(
                        open = openLoads(ui.loads),
                        portfolio = loadsForPricer(ui.profile, ui.loads, ui.directory),
                        onOpen = { nav.navigate("load/${it.id}") },
                    )
                    else -> LoadBoard(
                        title = "Cargas",
                        loads = ui.loads.sortedByDescending { it.publishedAt.time },
                        summary = "${ui.loads.size} cargas en total",
                        emptyTitle = "Sin cargas en este filtro",
                        emptySubtitle = "Cuando publiques una carga aparecerá aquí.",
                        onOpen = { nav.navigate("load/${it.id}") },
                        statusChips = true,
                        onNotices = { nav.navigate("notices") },
                        unread = unread,
                    )
                }
            }
            composable("directory") {
                val people = directoryFor(ui.profile, ui.directory)
                if (role == "pricer") {
                    DirectoryScreen(
                        title = "Directorio",
                        people = people,
                        emptyTitle = "Sin transportistas asignados",
                        emptySubtitle = "Cuando se te asigne un transportista, aparece aquí.",
                    )
                } else {
                    DirectoryScreen(
                        title = "Transportistas",
                        people = people,
                        emptyTitle = "Sin registros",
                        emptySubtitle = "Los transportistas y clientes aparecen aquí.",
                        onApprove = if (role == "admin") vm::approvePerson else null,
                        onReject = if (role == "admin") vm::rejectPerson else null,
                        onBlock = if (role == "admin") vm::blockPerson else null,
                        onUnblock = if (role == "admin") vm::unblockPerson else null,
                    )
                }
            }
            composable("history") {
                val mine = clientLoads(ui.profile, ui.loads)
                LoadBoard(
                    title = "Historial de cargas",
                    loads = mine,
                    summary = "Las cargas que publicaste: abiertas, en progreso y entregadas.",
                    emptyTitle = "Sin cargas publicadas",
                    emptySubtitle = "Cuando publiques, la carga queda aquí aunque siga abierta. Las entregadas no se quitan.",
                    onOpen = { nav.navigate("load/${it.id}") },
                )
            }
            composable("opportunities") {
                val profile = ui.profile
                val ready = profile != null && profile.routes.isNotEmpty() && profile.coverageEquipmentTypes.isNotEmpty()
                OpportunitiesScreen(
                    readyForOffers = ready,
                    offers = clientOpportunities(profile, ui.loads),
                    units = availablePosts(ui.units),
                    claimed = ui.claimedUnitIds,
                    onOpen = { nav.navigate("load/${it.id}") },
                    onRoutes = { nav.navigate("profile") },
                    onClaim = vm::claimRoute,
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
                if (role == "admin") {
                    FleetBoard(units = myUnits(ui.profile, ui.units))
                    return@composable
                }
                UnitsScreen(
                    units = units,
                    ownerId = ui.profile?.uuid.orEmpty(),
                    busy = ui.busy,
                    onSave = vm::saveUnit,
                    onDelete = vm::deleteUnit,
                    onStatus = vm::setUnitStatus,
                )
            }
            composable("more") {
                MoreScreen(items = moreItems(role), onOpen = { destination ->
                    nav.navigate(if (destination == "routes") "profile" else destination)
                })
            }
            composable("availability") {
                AvailabilityScreen(
                    posts = myAvailability(ui.profile, ui.units),
                    busy = ui.busy,
                    onPublish = vm::postAvailability,
                    onWithdraw = vm::withdrawAvailability,
                )
            }
            composable("tariff") {
                LaunchedEffect(ui.profile?.authUid) { vm.refreshTariffs() }
                TariffScreen(
                    book = ui.tariffs.firstOrNull(),
                    busy = ui.busy,
                    onSave = vm::saveTariff,
                )
            }
            composable("tariffs") {
                LaunchedEffect(ui.profile?.authUid) { vm.refreshTariffs() }
                TariffListScreen(books = ui.tariffs)
            }
            composable("publish") {
                PublishLoadScreen(
                    busy = ui.busy,
                    history = clientLoads(ui.profile, ui.loads),
                    onPublish = vm::publishClientLoad,
                    onOpen = { nav.navigate("load/${it.id}") },
                )
            }
            composable("payments") {
                val mine = role == "carrier" || role == "independent_operator"
                var selected by remember { mutableStateOf(ui.profile.takeIf { mine }) }
                LaunchedEffect(ui.profile?.uuid, mine) {
                    if (mine) {
                        ui.profile?.let {
                            selected = it
                            vm.loadCarrierPayments(it)
                        }
                    }
                }
                PaymentsScreen(
                    title = if (mine) "Mis pagos" else "Pagos",
                    subtitle = if (mine) {
                        "Tu cuenta, si ya te pagaron y el envío de facturas."
                    } else {
                        "Cuenta del transportista, pagos de Operaciones y envío de facturas."
                    },
                    carriers = if (mine) emptyList() else paymentCarriers(ui.directory),
                    busy = ui.payBusy,
                    snapshot = ui.pay,
                    selected = selected,
                    onCarrier = { person ->
                        selected = person
                        vm.loadCarrierPayments(person)
                    },
                    onSupplier = vm::openPaySupplier,
                    onRfc = vm::linkPayRfc,
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
                        onClientPreferences = vm::saveClientPreferences,
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
                    onApproveOffer = if (role == "admin") vm::approveOffer else null,
                    onRejectOffer = if (role == "admin") vm::rejectOffer else null,
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

package mx.continentecargo.conecta.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mx.continentecargo.conecta.data.CarrierProfile
import mx.continentecargo.conecta.data.Catalog
import mx.continentecargo.conecta.data.FleetUnit
import mx.continentecargo.conecta.data.FreightLoad
import mx.continentecargo.conecta.data.FreightOffer
import mx.continentecargo.conecta.data.approvedPricers
import mx.continentecargo.conecta.data.availablePosts
import mx.continentecargo.conecta.data.clientLoads
import mx.continentecargo.conecta.data.clientOpportunities
import mx.continentecargo.conecta.data.formatMoney
import mx.continentecargo.conecta.data.loadsForPricer
import mx.continentecargo.conecta.data.pendingCarriers
import mx.continentecargo.conecta.ui.components.EmptyState
import mx.continentecargo.conecta.ui.components.LoadCard
import mx.continentecargo.conecta.ui.components.NavyBar
import mx.continentecargo.conecta.ui.components.PrimaryButton
import mx.continentecargo.conecta.ui.theme.Brand
import mx.continentecargo.conecta.ui.theme.Ink
import mx.continentecargo.conecta.ui.theme.Line
import mx.continentecargo.conecta.ui.theme.Muted
import mx.continentecargo.conecta.ui.theme.Success

@Composable
fun AdminHomeScreen(
    name: String,
    loads: List<FreightLoad>,
    offers: List<FreightOffer>,
    people: List<CarrierProfile>,
    unread: Int,
    onOpenLoads: () -> Unit,
    onOpenDirectory: () -> Unit,
    onNotices: () -> Unit,
    onApprove: ((CarrierProfile) -> Unit)? = null,
    onReject: ((CarrierProfile) -> Unit)? = null,
    onApproveOffer: ((FreightOffer) -> Unit)? = null,
    onRejectOffer: ((FreightOffer) -> Unit)? = null,
) {
    val published = loads.count { it.status == "Publicado" }
    val moving = loads.count { it.status !in setOf("Publicado", "Entregado", "Cancelado") }
    val waiting = pendingCarriers(people)
    val counters = offers.filter { it.status == "PendienteAprobacion" }
    val pricers = approvedPricers(people)
    Column(Modifier.fillMaxSize()) {
        NavyBar(title = "Inicio") { NoticeButton(unread, onNotices) }
        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Text("Panel de operación", color = Muted, fontSize = 13.sp)
                Text("Hola, $name", fontWeight = FontWeight.Bold, fontSize = 24.sp, color = Ink)
            }
            item {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    StatCard("Cargas publicadas", published.toString(), "Abiertas en el tablero", Modifier.weight(1f), onOpenLoads)
                    StatCard("Viajes en curso", moving.toString(), "Asignados o en ruta", Modifier.weight(1f), onOpenLoads)
                }
            }
            item {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    StatCard("Registros nuevos", waiting.size.toString(), "Esperan tu aprobación", Modifier.weight(1f), onOpenDirectory)
                    StatCard("Contra-ofertas", counters.size.toString(), "Requiere tu atención", Modifier.weight(1f), onOpenLoads)
                }
            }
            if (waiting.isNotEmpty()) {
                item { Text("Registros nuevos", fontWeight = FontWeight.SemiBold, color = Ink) }
                items(waiting.take(8), key = { "pending-${it.uuid}" }) { person ->
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        PersonRow(person)
                        DecisionRow(onApprove?.let { { it(person) } }, onReject?.let { { it(person) } })
                    }
                }
            }
            if (counters.isNotEmpty()) {
                item { Text("Contra-ofertas", fontWeight = FontWeight.SemiBold, color = Ink) }
                items(counters.take(8), key = { "counter-${it.id}" }) { offer ->
                    val reference = loads.firstOrNull { it.id == offer.loadId }?.reference ?: offer.loadId
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        PlainCard("${offer.carrierName} · $reference", "${formatMoney(offer.amount, offer.currency)} · ${offer.status}")
                        DecisionRow(onApproveOffer?.let { { it(offer) } }, onRejectOffer?.let { { it(offer) } })
                    }
                }
            }
            item { Text("Pricers", fontWeight = FontWeight.SemiBold, color = Ink) }
            if (pricers.isEmpty()) {
                item { Text("No hay pricers aprobados.", color = Muted, fontSize = 13.sp) }
            } else {
                items(pricers, key = { "pricer-${it.uuid}" }) { person -> PersonRow(person) }
            }
        }
    }
}

@Composable
fun PricerHomeScreen(
    name: String,
    loads: List<FreightLoad>,
    people: List<CarrierProfile>,
    profile: CarrierProfile,
    unread: Int,
    onOpenLoads: () -> Unit,
    onNotices: () -> Unit,
) {
    val portfolio = loadsForPricer(profile, loads, people)
    val progress = portfolio.count { it.status != "Publicado" && it.status != "Entregado" && it.status != "Cancelado" }
    val published = portfolio.count { it.status == "Publicado" }
    val done = portfolio.count { it.status == "Entregado" || it.status == "Cancelado" }
    val letters = portfolio.count { it.carta == null && it.status != "Cancelado" && it.status != "Entregado" }
    Column(Modifier.fillMaxSize()) {
        NavyBar(title = "Inicio") { NoticeButton(unread, onNotices) }
        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Text("Tu cartera", color = Muted, fontSize = 13.sp)
                Text("Hola, $name", fontWeight = FontWeight.Bold, fontSize = 24.sp, color = Ink)
            }
            item {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    StatCard("En progreso", progress.toString(), "Cargas de tu cartera", Modifier.weight(1f), onOpenLoads)
                    StatCard("Publicadas", published.toString(), "Ya tomadas, aún abiertas", Modifier.weight(1f), onOpenLoads)
                }
            }
            item {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    StatCard("Completadas", done.toString(), "Entregadas o canceladas", Modifier.weight(1f), onOpenLoads)
                    StatCard("Sin carta", letters.toString(), "Cartas de instrucción pendientes", Modifier.weight(1f), onOpenLoads)
                }
            }
            item {
                Text(
                    "En Cargas ves lo que nadie ha tomado y lo que ya tomó tu cartera.",
                    color = Muted,
                    fontSize = 13.sp,
                )
            }
        }
    }
}

@Composable
fun ClientHomeScreen(
    name: String,
    loads: List<FreightLoad>,
    profile: CarrierProfile,
    units: List<FleetUnit>,
    unread: Int,
    onHistory: () -> Unit,
    onOpportunities: () -> Unit,
    onNotices: () -> Unit,
) {
    val mine = clientLoads(profile, loads)
    val open = mine.count { it.status == "Publicado" }
    val delivered = mine.count { it.status == "Entregado" }
    val historyDetail = if (mine.isEmpty()) {
        "Abiertas, en progreso y entregadas"
    } else {
        "${mine.size} en historial · $open abierta${if (open == 1) "" else "s"} · $delivered entregada${if (delivered == 1) "" else "s"}"
    }
    val offers = clientOpportunities(profile, loads).size
    val posts = availablePosts(units).size
    Column(Modifier.fillMaxSize()) {
        NavyBar(title = "Inicio") { NoticeButton(unread, onNotices) }
        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Text("Bienvenido", color = Brand, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
                Text("Hola, $name", fontWeight = FontWeight.Bold, fontSize = 24.sp, color = Ink)
                Text(
                    "Desde aquí llegas a tus cargas, rutas, ofertas y unidades.",
                    color = Muted,
                    fontSize = 14.sp,
                )
            }
            item { LinkCard("Historial de cargas", historyDetail, onHistory) }
            item { LinkCard("Oportunidades", "$offers buenas ofertas · $posts unidades disponibles", onOpportunities) }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun LoadBoard(
    title: String,
    loads: List<FreightLoad>,
    summary: String,
    emptyTitle: String,
    emptySubtitle: String,
    onOpen: (FreightLoad) -> Unit,
    statusChips: Boolean = false,
    onNotices: (() -> Unit)? = null,
    unread: Int = 0,
) {
    var query by rememberSaveable { mutableStateOf("") }
    var bucket by rememberSaveable { mutableStateOf("all") }
    val searched = loads.filter { load ->
        val statusOk = when {
            !statusChips || bucket == "all" -> true
            bucket == "open" -> load.status == "Publicado"
            bucket == "active" ->
                (load.status == "Publicado" && load.confirmedUnitCount > 0) ||
                    load.status !in setOf("Publicado", "Entregado", "Cancelado")
            bucket == "done" -> load.status == "Entregado" || load.status == "Cancelado"
            else -> true
        }
        val text = listOf(load.reference, load.originCity, load.originState, load.destinationCity, load.destinationState)
            .joinToString(" ")
        statusOk && (query.isBlank() || text.contains(query.trim(), ignoreCase = true))
    }.sortedByDescending { it.publishedAt.time }
    Column(Modifier.fillMaxSize()) {
        NavyBar(title = title) {
            if (onNotices != null) NoticeButton(unread, onNotices)
        }
        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item { Text(summary, color = Muted, fontSize = 13.sp) }
            item {
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    modifier = Modifier.fillMaxWidth(),
                    placeholder = { Text("Buscar ruta o referencia") },
                    singleLine = true,
                )
            }
            if (statusChips) {
                item {
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf("all" to "Todas", "open" to "Abiertas", "active" to "En curso", "done" to "Cerradas").forEach { (id, label) ->
                            FilterChip(selected = bucket == id, onClick = { bucket = id }, label = { Text(label) })
                        }
                    }
                }
            }
            if (searched.isEmpty()) {
                item {
                    EmptyState(
                        title = if (query.isNotBlank()) "Nada con esos filtros" else emptyTitle,
                        subtitle = if (query.isNotBlank()) "Prueba con otra ciudad o referencia." else emptySubtitle,
                    )
                }
            } else {
                items(searched, key = { it.id }) { load -> LoadCard(load) { onOpen(load) } }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun PricerLoadsScreen(
    open: List<FreightLoad>,
    portfolio: List<FreightLoad>,
    onOpen: (FreightLoad) -> Unit,
) {
    var mode by rememberSaveable { mutableStateOf("open") }
    val rows = if (mode == "open") open else portfolio
    Column(Modifier.fillMaxSize()) {
        NavyBar(title = "Cargas")
        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Text(
                    if (mode == "open") {
                        if (open.size == 1) "1 carga publicada todavía sin transportista" else "${open.size} cargas publicadas todavía sin transportista"
                    } else {
                        "Cargas que ya tomó alguien de tu cartera."
                    },
                    color = Muted,
                    fontSize = 13.sp,
                )
            }
            item {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(selected = mode == "open", onClick = { mode = "open" }, label = { Text("Por cubrir") })
                    FilterChip(selected = mode == "mine", onClick = { mode = "mine" }, label = { Text("Cartera") })
                }
            }
            if (rows.isEmpty()) {
                item {
                    EmptyState(
                        title = if (mode == "open") "Nada por cubrir" else "Sin cargas en tu cartera",
                        subtitle = if (mode == "open") {
                            "Cuando se publique una carga y nadie la tome, aparecerá aquí para todos los pricers."
                        } else {
                            "Cuando un transportista de tu cartera tome una carga, aparece aquí."
                        },
                    )
                }
            } else {
                items(rows, key = { it.id }) { load -> LoadCard(load) { onOpen(load) } }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun DirectoryScreen(
    title: String,
    people: List<CarrierProfile>,
    emptyTitle: String,
    emptySubtitle: String,
    onApprove: ((CarrierProfile) -> Unit)? = null,
    onReject: ((CarrierProfile) -> Unit)? = null,
    onBlock: ((CarrierProfile) -> Unit)? = null,
    onUnblock: ((CarrierProfile) -> Unit)? = null,
) {
    var query by rememberSaveable { mutableStateOf("") }
    var filter by rememberSaveable { mutableStateOf("all") }
    val shown = people.filter { person ->
        val statusOk = when (filter) {
            "pending" -> person.status == "pending_approval"
            "approved" -> person.status == "approved"
            else -> true
        }
        val text = listOf(person.name, person.email, person.phone, Catalog.roleLabel(person.role)).joinToString(" ")
        statusOk && (query.isBlank() || text.contains(query.trim(), ignoreCase = true))
    }
    Column(Modifier.fillMaxSize()) {
        NavyBar(title = title)
        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item { Text("${shown.size} registros", color = Muted, fontSize = 13.sp) }
            item {
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    modifier = Modifier.fillMaxWidth(),
                    placeholder = { Text("Buscar nombre, correo o teléfono") },
                    singleLine = true,
                )
            }
            item {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(selected = filter == "all", onClick = { filter = "all" }, label = { Text("Todos") })
                    FilterChip(selected = filter == "pending", onClick = { filter = "pending" }, label = { Text("Pendientes") })
                    FilterChip(selected = filter == "approved", onClick = { filter = "approved" }, label = { Text("Aprobados") })
                }
            }
            if (shown.isEmpty()) {
                item { EmptyState(title = emptyTitle, subtitle = emptySubtitle) }
            } else {
                items(shown, key = { it.authUid + it.uuid }) { person ->
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        PersonRow(person)
                        when {
                            person.status == "pending_approval" ->
                                DecisionRow(onApprove?.let { { it(person) } }, onReject?.let { { it(person) } })
                            person.status == "approved" && onBlock != null ->
                                DecisionRow(null, { onBlock(person) }, approveLabel = "", rejectLabel = "Bloquear")
                            person.status == "suspended" && onUnblock != null ->
                                DecisionRow({ onUnblock(person) }, null, approveLabel = "Reactivar")
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun FleetBoard(units: List<FleetUnit>) {
    Column(Modifier.fillMaxSize()) {
        NavyBar(title = "Unidades")
        if (units.isEmpty()) {
            EmptyState(title = "Sin unidades", subtitle = "Las unidades de los transportistas aparecen aquí.")
        } else {
            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item { Text("${units.size} unidades", color = Muted, fontSize = 13.sp) }
                items(units, key = { it.id }) { unit ->
                    PlainCard(
                        "${unit.equipmentType} · ${unit.plates.ifBlank { "Sin placas" }}",
                        listOf(unit.status, unit.currentLocation, unit.operatorName).filter { it.isNotBlank() }.joinToString(" · "),
                    )
                }
            }
        }
    }
}

@Composable
fun OpportunitiesScreen(
    readyForOffers: Boolean,
    offers: List<FreightLoad>,
    units: List<FleetUnit>,
    claimed: Set<String>,
    onOpen: (FreightLoad) -> Unit,
    onRoutes: () -> Unit,
    onClaim: (FleetUnit) -> Unit,
) {
    Column(Modifier.fillMaxSize()) {
        NavyBar(title = "Oportunidades")
        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Text("Cargas que coinciden contigo y unidades que ya están disponibles.", color = Muted, fontSize = 13.sp)
                Text("Buenas ofertas", fontWeight = FontWeight.Bold, fontSize = 20.sp, color = Ink)
                Text(
                    "Cargas publicadas que coinciden con tus rutas y tu unidad. No pones precio.",
                    color = Muted,
                    fontSize = 13.sp,
                )
            }
            if (!readyForOffers) {
                item {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        PlainCard(
                            "Elige al menos una ruta y un tipo de unidad, y guárdalos, para ver ofertas.",
                            "",
                        )
                        PrimaryButton(text = "Ir a rutas", onClick = onRoutes)
                    }
                }
            } else if (offers.isEmpty()) {
                item {
                    Text(
                        "Por ahora no hay cargas publicadas que coincidan con tus rutas y tu unidad.",
                        color = Muted,
                        fontSize = 14.sp,
                    )
                }
            } else {
                items(offers, key = { "offer-${it.id}" }) { load -> LoadCard(load) { onOpen(load) } }
            }
            item {
                Text("Unidades disponibles", fontWeight = FontWeight.Bold, fontSize = 20.sp, color = Ink)
                Text(
                    "Unidades que un transportista publicó. Si te sirve la ruta, avisa que puedes tomarla.",
                    color = Muted,
                    fontSize = 13.sp,
                )
            }
            if (units.isEmpty()) {
                item { Text("No hay unidades publicadas en este momento.", color = Muted, fontSize = 14.sp) }
            } else {
                items(units, key = { "unit-${it.id}" }) { unit ->
                    val from = unit.postedOriginState?.takeIf { it.isNotBlank() } ?: unit.currentLocation
                    val to = unit.postedDestinationState?.takeIf { it.isNotBlank() } ?: unit.coverageZones.firstOrNull().orEmpty()
                    val claimedAlready = unit.id in claimed
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        PlainCard(
                            "${from.ifBlank { "Origen" }} → ${to.ifBlank { "Destino" }}",
                            listOf(unit.equipmentType, unit.trailerNumber).filter { it.isNotBlank() }.joinToString(" · "),
                        )
                        if (claimedAlready) {
                            Text("Ya avisaste que puedes tomarla", color = Success, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                        } else {
                            PrimaryButton(
                                text = "Puedo tomar esta ruta",
                                enabled = from.isNotBlank() && to.isNotBlank(),
                                onClick = { onClaim(unit) },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun NoticeButton(unread: Int, onClick: () -> Unit) {
    IconButton(onClick = onClick) {
        BadgedBox(
            badge = {
                if (unread > 0) Badge { Text(if (unread > 9) "9+" else unread.toString()) }
            },
        ) {
            Icon(Icons.Outlined.Notifications, contentDescription = "Avisos", tint = Color.White)
        }
    }
}

@Composable
private fun StatCard(
    label: String,
    value: String,
    hint: String,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Card(
        onClick = onClick,
        modifier = modifier,
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        border = androidx.compose.foundation.BorderStroke(1.dp, Line),
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(label, color = Muted, fontSize = 12.sp)
            Text(value, fontWeight = FontWeight.Bold, fontSize = 28.sp, color = Ink)
            Text(hint, color = Muted, fontSize = 11.sp)
        }
    }
}

@Composable
private fun LinkCard(title: String, detail: String, onClick: () -> Unit) {
    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        border = androidx.compose.foundation.BorderStroke(1.dp, Line),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, fontWeight = FontWeight.SemiBold, color = Ink)
            Text(detail, color = Muted, fontSize = 13.sp)
        }
    }
}

@Composable
private fun DecisionRow(
    onApprove: (() -> Unit)?,
    onReject: (() -> Unit)?,
    approveLabel: String = "Aprobar",
    rejectLabel: String = "Rechazar",
) {
    if (onApprove == null && onReject == null) return
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        if (onApprove != null && approveLabel.isNotBlank()) {
            androidx.compose.material3.TextButton(onClick = onApprove) { Text(approveLabel) }
        }
        if (onReject != null && rejectLabel.isNotBlank()) {
            androidx.compose.material3.TextButton(onClick = onReject) { Text(rejectLabel, color = mx.continentecargo.conecta.ui.theme.Danger) }
        }
    }
}

@Composable
private fun PersonRow(person: CarrierProfile) {
    PlainCard(
        person.name,
        listOf(Catalog.roleLabel(person.role), Catalog.statusLabel(person.status), person.phone, person.email)
            .filter { it.isNotBlank() }
            .joinToString(" · "),
    )
}

@Composable
private fun PlainCard(title: String, detail: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        border = androidx.compose.foundation.BorderStroke(1.dp, Line),
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, fontWeight = FontWeight.SemiBold, color = Ink)
            if (detail.isNotBlank()) Text(detail, color = Muted, fontSize = 13.sp)
        }
    }
}

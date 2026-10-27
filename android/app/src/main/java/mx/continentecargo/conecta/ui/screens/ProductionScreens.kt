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
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mx.continentecargo.conecta.data.Catalog
import mx.continentecargo.conecta.data.ClientPublish
import mx.continentecargo.conecta.data.FleetUnit
import mx.continentecargo.conecta.data.PaySnapshot
import mx.continentecargo.conecta.data.TariffBasis
import mx.continentecargo.conecta.data.TariffBook
import mx.continentecargo.conecta.data.TariffRow
import mx.continentecargo.conecta.data.formatMoney
import mx.continentecargo.conecta.data.formatStamp
import mx.continentecargo.conecta.ui.components.EmptyState
import mx.continentecargo.conecta.ui.components.NavyBar
import mx.continentecargo.conecta.ui.components.PrimaryButton
import mx.continentecargo.conecta.ui.components.SecondaryButton
import mx.continentecargo.conecta.ui.theme.Danger
import mx.continentecargo.conecta.ui.theme.Ink
import mx.continentecargo.conecta.ui.theme.Line
import mx.continentecargo.conecta.ui.theme.Muted

data class MoreItem(val route: String, val title: String, val detail: String)

@Composable
fun MoreScreen(items: List<MoreItem>, onOpen: (String) -> Unit) {
    Column(Modifier.fillMaxSize()) {
        NavyBar(title = "Más")
        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            items(items, key = { it.route }) { item ->
                Card(
                    onClick = { onOpen(item.route) },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = Color.White),
                    border = androidx.compose.foundation.BorderStroke(1.dp, Line),
                ) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(item.title, fontWeight = FontWeight.SemiBold, color = Ink)
                        Text(item.detail, color = Muted, fontSize = 13.sp)
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun AvailabilityScreen(
    posts: List<FleetUnit>,
    busy: Boolean,
    onPublish: (String, Int, String, String) -> Unit,
    onWithdraw: (String) -> Unit,
) {
    var equipment by rememberSaveable { mutableStateOf(Catalog.equipment.first()) }
    var origin by rememberSaveable { mutableStateOf("N.L.") }
    var destination by rememberSaveable { mutableStateOf("CDMX") }
    var count by rememberSaveable { mutableIntStateOf(1) }
    Column(Modifier.fillMaxSize()) {
        NavyBar(title = "Disponibilidad")
        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Text("Avisa a Continente Cargo que tienes unidades libres para recibir cargas a tu medida.", color = Muted, fontSize = 13.sp)
                Text("Publicación rápida", fontWeight = FontWeight.Bold, fontSize = 20.sp, color = Ink)
                Text("Toma menos de 10 segundos", color = Muted, fontSize = 13.sp)
            }
            item {
                Text("Tipo de equipo", color = Muted, fontSize = 12.sp)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Catalog.equipment.forEach { item ->
                        FilterChip(selected = equipment == item, onClick = { equipment = item }, label = { Text(item) })
                    }
                }
            }
            item {
                Text("¿Dónde está tu unidad?", color = Muted, fontSize = 12.sp)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Catalog.mexicoStates.forEach { state ->
                        FilterChip(selected = origin == state, onClick = { origin = state }, label = { Text(state) })
                    }
                }
            }
            item {
                Text("Destino preferido", color = Muted, fontSize = 12.sp)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Catalog.mexicoStates.forEach { state ->
                        FilterChip(selected = destination == state, onClick = { destination = state }, label = { Text(state) })
                    }
                }
            }
            item {
                Text("Unidades disponibles", color = Muted, fontSize = 12.sp)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    TextButton(onClick = { if (count > 1) count -= 1 }, enabled = count > 1) { Text("Menos") }
                    Text(count.toString(), fontWeight = FontWeight.Bold, fontSize = 20.sp, color = Ink)
                    TextButton(onClick = { count += 1 }) { Text("Más") }
                }
                PrimaryButton(
                    text = if (busy) "Publicando…" else "Publicar disponibilidad",
                    enabled = !busy && count >= 1,
                    onClick = { onPublish(equipment, count, origin, destination) },
                )
            }
            item { Text("Tus publicaciones", fontWeight = FontWeight.SemiBold, color = Ink) }
            if (posts.isEmpty()) {
                item { EmptyState(title = "Sin publicaciones activas", subtitle = "Lo que publiques aparecerá aquí.") }
            } else {
                items(posts, key = { it.id }) { post ->
                    val to = post.coverageZones.firstOrNull()?.takeIf { it.isNotBlank() } ?: "Cualquier destino"
                    val units = post.trailerNumber.toIntOrNull()?.coerceAtLeast(1) ?: 1
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text("${post.currentLocation} → $to", fontWeight = FontWeight.SemiBold, color = Ink)
                        Text("$units × ${post.equipmentType} · ${formatStamp(post.availableFrom)}", color = Muted, fontSize = 13.sp)
                        TextButton(onClick = { onWithdraw(post.id) }) { Text("Retirar publicación", color = Danger) }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun TariffScreen(
    book: TariffBook?,
    busy: Boolean,
    onSave: (List<TariffRow>) -> Unit,
) {
    var rows by androidx.compose.runtime.remember(book?.id, book?.rows) { mutableStateOf(book?.rows.orEmpty()) }
    var origin by rememberSaveable { mutableStateOf("") }
    var destination by rememberSaveable { mutableStateOf("") }
    var equipment by rememberSaveable { mutableStateOf(Catalog.equipment.first()) }
    var amount by rememberSaveable { mutableStateOf("") }
    var currency by rememberSaveable { mutableStateOf("MXN") }
    var basis by rememberSaveable { mutableStateOf("viaje") }
    Column(Modifier.fillMaxSize()) {
        NavyBar(title = "Tarifario")
        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            item {
                Text(
                    "Este tarifario es el que Continente Cargo usa para asignarte cargas directo, sin que cotices cada viaje.",
                    color = Ink,
                    fontSize = 14.sp,
                )
            }
            item { Text("Estado de origen", color = Muted, fontSize = 12.sp) }
            item {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    (Catalog.mexicoStates + Catalog.usaStates).forEach { state ->
                        FilterChip(selected = origin == state, onClick = { origin = state }, label = { Text(state) })
                    }
                }
            }
            item { Text("Estado de destino", color = Muted, fontSize = 12.sp) }
            item {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    (Catalog.mexicoStates + Catalog.usaStates).forEach { state ->
                        FilterChip(selected = destination == state, onClick = { destination = state }, label = { Text(state) })
                    }
                }
            }
            item {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Catalog.equipment.forEach { item ->
                        FilterChip(selected = equipment == item, onClick = { equipment = item }, label = { Text(item) })
                    }
                }
            }
            item {
                OutlinedTextField(
                    value = amount,
                    onValueChange = { amount = it.filter { ch -> ch.isDigit() || ch == '.' } },
                    label = { Text("Tarifa") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
            }
            item {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(selected = currency == "MXN", onClick = { currency = "MXN" }, label = { Text("MXN") })
                    FilterChip(selected = currency == "USD", onClick = { currency = "USD" }, label = { Text("USD") })
                    TariffBasis.options.forEach { (key, label) ->
                        FilterChip(selected = basis == key, onClick = { basis = key }, label = { Text(label) })
                    }
                }
            }
            item {
                SecondaryButton(
                    text = "Agregar tarifa",
                    onClick = {
                        val price = amount.toDoubleOrNull() ?: return@SecondaryButton
                        val row = mx.continentecargo.conecta.data.sanitizeTariffRow(
                            origin, destination, equipment, price, currency, basis, "", "manual",
                        ) ?: return@SecondaryButton
                        rows = (rows + row).take(300)
                        amount = ""
                    },
                )
            }
            if (rows.isEmpty()) {
                item { Text("Sin tarifas publicadas.", color = Muted, fontSize = 13.sp) }
            } else {
                items(rows.size) { index ->
                    val row = rows[index]
                    Row {
                        Text(
                            "${row.origin} → ${row.destination} · ${row.equipment.ifBlank { "Equipo" }} · ${formatMoney(row.amount, row.currency)} · ${TariffBasis.label(row.basis)}",
                            modifier = Modifier.weight(1f),
                            color = Ink,
                            fontSize = 14.sp,
                        )
                        TextButton(onClick = { rows = rows.filterIndexed { i, _ -> i != index } }) { Text("Quitar") }
                    }
                }
            }
            item {
                PrimaryButton(
                    text = if (busy) "Guardando…" else "Guardar tarifa",
                    enabled = !busy,
                    onClick = { onSave(rows) },
                )
            }
        }
    }
}

@Composable
fun TariffListScreen(books: List<TariffBook>) {
    Column(Modifier.fillMaxSize()) {
        NavyBar(title = "Tarifarios")
        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Text(
                    "Tarifas publicadas por los transportistas. Continente Cargo las usa para asignar cargas directo.",
                    color = Muted,
                    fontSize = 13.sp,
                )
            }
            if (books.isEmpty()) {
                item { EmptyState(title = "Sin tarifas publicadas", subtitle = "Todavía no hay tarifarios publicados.") }
            } else {
                items(books, key = { it.id }) { book ->
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(book.label, fontWeight = FontWeight.SemiBold, color = Ink)
                        Text("${book.rows.size} tarifas · ${book.phone}", color = Muted, fontSize = 13.sp)
                        book.rows.take(8).forEach { row ->
                            Text(
                                "${row.origin} → ${row.destination} · ${formatMoney(row.amount, row.currency)} · ${TariffBasis.label(row.basis)}",
                                color = Ink,
                                fontSize = 13.sp,
                            )
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun PublishLoadScreen(
    busy: Boolean,
    history: List<mx.continentecargo.conecta.data.FreightLoad>,
    onPublish: (ClientPublish) -> Unit,
    onOpen: (mx.continentecargo.conecta.data.FreightLoad) -> Unit,
) {
    var usa by rememberSaveable { mutableStateOf(false) }
    var ltl by rememberSaveable { mutableStateOf(false) }
    var originCity by rememberSaveable { mutableStateOf("") }
    var destinationCity by rememberSaveable { mutableStateOf("") }
    var origin by rememberSaveable { mutableStateOf("N.L.") }
    var destination by rememberSaveable { mutableStateOf("CDMX") }
    var day by rememberSaveable { mutableStateOf("") }
    var equipment by rememberSaveable { mutableStateOf("Caja Seca 53'") }
    var currency by rememberSaveable { mutableStateOf("MXN") }
    var merchandise by rememberSaveable { mutableStateOf("") }
    val places = if (usa) Catalog.usaStates else Catalog.mexicoStates
    Column(Modifier.fillMaxSize()) {
        NavyBar(title = "Publicar carga")
        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            item {
                Text(
                    "Origen, destino, fecha, equipo y qué se mueve. No pones precio: las líneas cotizan y gana la más baja.",
                    color = Muted,
                    fontSize = 13.sp,
                )
            }
            item {
                Text("Mercado", color = Muted, fontSize = 12.sp)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(selected = !usa, onClick = { usa = false; origin = "N.L."; destination = "CDMX"; currency = "MXN" }, label = { Text("México") })
                    FilterChip(selected = usa, onClick = { usa = true; origin = "TX"; destination = "CA"; currency = "USD" }, label = { Text("EE.UU.") })
                }
            }
            item {
                Text("Tipo de carga", color = Muted, fontSize = 12.sp)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(selected = !ltl, onClick = { ltl = false }, label = { Text("Carga completa") })
                    FilterChip(selected = ltl, onClick = { ltl = true }, label = { Text("LTL") })
                }
                Text(
                    if (ltl) "Se guarda como Consolidada LTL. Tú no pones precio." else "Subasta inversa: gana la oferta más baja. Tú no pones precio.",
                    color = Muted,
                    fontSize = 12.sp,
                )
            }
            item {
                OutlinedTextField(originCity, { originCity = it }, label = { Text("Ciudad de origen") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
            }
            item {
                Text("Estado de origen", color = Muted, fontSize = 12.sp)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    places.forEach { state ->
                        FilterChip(selected = origin == state, onClick = { origin = state }, label = { Text(state) })
                    }
                }
            }
            item {
                OutlinedTextField(destinationCity, { destinationCity = it }, label = { Text("Ciudad de destino") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
            }
            item {
                Text("Estado de destino", color = Muted, fontSize = 12.sp)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    places.forEach { state ->
                        FilterChip(selected = destination == state, onClick = { destination = state }, label = { Text(state) })
                    }
                }
            }
            item {
                OutlinedTextField(day, { day = it }, label = { Text("Fecha de recolección") }, placeholder = { Text("AAAA-MM-DD") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
            }
            item {
                Text("Equipo", color = Muted, fontSize = 12.sp)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Catalog.equipment.forEach { item ->
                        FilterChip(selected = equipment == item, onClick = { equipment = item }, label = { Text(item) })
                    }
                }
            }
            item {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(selected = currency == "MXN", onClick = { currency = "MXN" }, label = { Text("MXN") })
                    FilterChip(selected = currency == "USD", onClick = { currency = "USD" }, label = { Text("USD") })
                }
            }
            item {
                OutlinedTextField(merchandise, { merchandise = it }, label = { Text("Qué se mueve") }, placeholder = { Text("Tarima, caja, maquinaria…") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
            }
            item {
                PrimaryButton(
                    text = if (busy) "Publicando…" else "Publicar",
                    enabled = !busy,
                    onClick = {
                        onPublish(
                            ClientPublish(
                                originCity = originCity,
                                originState = origin,
                                destinationCity = destinationCity,
                                destinationState = destination,
                                pickupDay = day,
                                equipment = equipment,
                                merchandise = merchandise,
                                currency = currency,
                                ltl = ltl,
                                marketUsa = usa,
                            ),
                        )
                    },
                )
            }
            item {
                Text("Historial de cargas", fontWeight = FontWeight.SemiBold, color = Ink)
                Text("Las que publicaste: abiertas, en progreso y entregadas.", color = Muted, fontSize = 13.sp)
            }
            if (history.isEmpty()) {
                item { Text("Sin cargas publicadas", color = Muted, fontSize = 13.sp) }
            } else {
                items(history, key = { "pub-${it.id}" }) { load ->
                    TextButton(onClick = { onOpen(load) }) { Text("${load.reference} · ${load.routeLabel} · ${load.status}") }
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun PaymentsScreen(
    title: String,
    subtitle: String,
    carriers: List<mx.continentecargo.conecta.data.CarrierProfile>,
    busy: Boolean,
    snapshot: PaySnapshot?,
    onCarrier: (mx.continentecargo.conecta.data.CarrierProfile) -> Unit,
    onSupplier: (String) -> Unit,
    onRfc: (mx.continentecargo.conecta.data.CarrierProfile, String) -> Unit,
    selected: mx.continentecargo.conecta.data.CarrierProfile?,
) {
    var query by rememberSaveable { mutableStateOf("") }
    var rfc by rememberSaveable { mutableStateOf("") }
    val shown = carriers.filter { person ->
        query.isBlank() || listOf(person.name, person.email, person.phone).joinToString(" ").contains(query.trim(), ignoreCase = true)
    }.take(40)
    Column(Modifier.fillMaxSize()) {
        NavyBar(title = title)
        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            item { Text(subtitle, color = Muted, fontSize = 13.sp) }
            if (carriers.isNotEmpty()) {
                item {
                    OutlinedTextField(
                        value = query,
                        onValueChange = { query = it },
                        modifier = Modifier.fillMaxWidth(),
                        placeholder = { Text("Buscar transportista") },
                        singleLine = true,
                    )
                }
                if (shown.isEmpty()) {
                    item { Text("No hay transportistas con ese nombre.", color = Muted, fontSize = 13.sp) }
                } else {
                    items(shown, key = { it.uuid }) { person ->
                        TextButton(onClick = { onCarrier(person) }) { Text(person.name) }
                    }
                }
            }
            if (busy) item { Text("Consultando el portal de proveedores…", color = Muted, fontSize = 13.sp) }
            snapshot?.error?.let { message -> item { Text(message, color = Danger, fontSize = 13.sp) } }
            if (snapshot != null && snapshot.needsRfc && selected != null) {
                item {
                    Text("No hay una cuenta ligada por el nombre. Escribe el RFC para buscar al proveedor.", color = Muted, fontSize = 13.sp)
                    OutlinedTextField(rfc, { rfc = it.uppercase() }, label = { Text("RFC") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
                    PrimaryButton(text = if (busy) "Buscando…" else "Buscar por RFC", enabled = !busy, onClick = { onRfc(selected, rfc) })
                }
            }
            if ((snapshot?.suppliers?.size ?: 0) > 1) {
                item {
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        snapshot?.suppliers.orEmpty().forEach { supplier ->
                            FilterChip(selected = false, onClick = { onSupplier(supplier.id) }, label = { Text(supplier.name) })
                        }
                    }
                }
            }
            snapshot?.accountTitle?.let { name ->
                item { Text(name, fontWeight = FontWeight.Bold, fontSize = 18.sp, color = Ink) }
            }
            snapshot?.accountLine?.takeIf { it.isNotBlank() }?.let { line ->
                item { Text(line, color = Muted, fontSize = 13.sp) }
            }
            val page = snapshot
            if (page != null && page.cards.isNotEmpty()) {
                items(page.cards) { (label, value) ->
                    Text("$label: $value", color = Ink, fontSize = 14.sp)
                }
            }
            if (page != null && page.accountTitle != null) {
                item {
                    Text("Pagos de Operaciones", fontWeight = FontWeight.SemiBold, color = Ink)
                    Text("Lo que Operaciones ya registró para pagar a este proveedor, desde enero de 2026.", color = Muted, fontSize = 13.sp)
                }
                page.portalError?.let { message -> item { Text(message, color = Danger, fontSize = 13.sp) } }
                if (page.payments.isEmpty()) {
                    item { Text("Todavía no hay pagos registrados.", color = Muted, fontSize = 13.sp) }
                } else {
                    items(page.payments, key = { it.id + it.invoice + it.shipment }) { line ->
                        Text("${line.invoice} · ${line.shipment} · ${line.total} · ${line.status} · ${line.paid} · ${line.folio}", color = Ink, fontSize = 13.sp)
                    }
                }
            }
        }
    }
}

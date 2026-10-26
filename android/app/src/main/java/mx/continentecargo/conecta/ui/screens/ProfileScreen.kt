package mx.continentecargo.conecta.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.FilterChip
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mx.continentecargo.conecta.data.Catalog
import mx.continentecargo.conecta.data.CarrierProfile
import mx.continentecargo.conecta.data.RouteCoverage
import mx.continentecargo.conecta.ui.components.EmptyState
import mx.continentecargo.conecta.ui.components.NavyBar
import mx.continentecargo.conecta.ui.components.PrimaryButton
import mx.continentecargo.conecta.ui.components.SecondaryButton
import mx.continentecargo.conecta.ui.theme.Danger
import mx.continentecargo.conecta.ui.theme.Ink
import mx.continentecargo.conecta.ui.theme.Muted
import java.util.UUID

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ProfileScreen(
    profile: CarrierProfile,
    busy: Boolean,
    onSave: (String, String) -> Unit,
    onLtl: (Boolean) -> Unit,
    onHazmat: (Boolean) -> Unit,
    onRoutes: (List<RouteCoverage>) -> Unit,
    onClientPreferences: (List<RouteCoverage>, List<String>) -> Unit,
    onNotices: () -> Unit,
    onLogout: () -> Unit,
) {
    var name by remember(profile.uuid) { mutableStateOf(profile.name) }
    var phone by remember(profile.uuid) { mutableStateOf(profile.phone) }
    var routes by remember(profile.uuid, profile.routes) { mutableStateOf(profile.routes) }
    var equipment by remember(profile.uuid, profile.coverageEquipmentTypes) { mutableStateOf(profile.coverageEquipmentTypes) }
    val carrierAccount = profile.role in Catalog.carrierRoles
    val clientAccount = profile.role == "client"
    var origin by remember { mutableStateOf(Catalog.mexicoStates.first()) }
    var destination by remember { mutableStateOf("N.L.") }
    Column(Modifier.fillMaxSize()) {
        NavyBar(title = "Perfil")
        Column(
            Modifier
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(profile.name, fontWeight = FontWeight.Bold, fontSize = 22.sp, color = Ink)
            Text(Catalog.roleLabel(profile.role), color = Muted)
            Text("Este correo no se cambia desde aquí.", color = Muted, fontSize = 13.sp)
            Text(profile.email, color = Ink)
            OutlinedTextField(name, { name = it }, label = { Text("Nombre") }, modifier = Modifier.fillMaxWidth(), singleLine = true, shape = RoundedCornerShape(12.dp))
            OutlinedTextField(phone, { phone = it }, label = { Text("Teléfono") }, modifier = Modifier.fillMaxWidth(), singleLine = true, shape = RoundedCornerShape(12.dp))
            PrimaryButton(
                text = if (busy) "Guardando…" else "Guardar perfil",
                enabled = !busy,
                onClick = { onSave(name, phone) },
            )
            if (carrierAccount) {
            Text("Configuración", fontWeight = FontWeight.SemiBold)
            Toggle("Acepto cargas parciales (LTL)", profile.handlesLTL, onLtl)
            Toggle("Puedo mover materiales peligrosos con la documentación requerida.", profile.handlesHazmat, onHazmat)
            Text("Rutas", fontWeight = FontWeight.SemiBold)
            Text("Recibirás avisos de cargas en estas rutas. Al guardar, la cobertura por estados se reemplaza.", color = Muted, fontSize = 13.sp)
            routes.forEach { route ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        "${route.originState} → ${route.destinationState}" + if (route.bidirectional) " · ida y vuelta" else "",
                        modifier = Modifier.weight(1f),
                    )
                    TextButton(onClick = { routes = routes.filterNot { it.id == route.id } }) { Text("Quitar") }
                }
            }
            Text("Origen", color = Muted, fontSize = 12.sp)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Catalog.mexicoStates.forEach { state ->
                    FilterChip(selected = origin == state, onClick = { origin = state }, label = { Text(state) })
                }
            }
            Text("Destino", color = Muted, fontSize = 12.sp)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Catalog.mexicoStates.forEach { state ->
                    FilterChip(selected = destination == state, onClick = { destination = state }, label = { Text(state) })
                }
            }
            SecondaryButton(
                text = "Agregar ruta",
                onClick = {
                    if (origin != destination && routes.none { it.originState == origin && it.destinationState == destination }) {
                        routes = routes + RouteCoverage(
                            id = UUID.randomUUID().toString(),
                            originState = origin,
                            destinationState = destination,
                            bidirectional = true,
                            equipmentTypes = profile.coverageEquipmentTypes,
                        )
                    }
                },
            )
            PrimaryButton(
                text = if (busy) "Guardando…" else "Guardar rutas",
                enabled = !busy,
                onClick = { onRoutes(routes) },
            )
            }
            if (clientAccount) {
                Text("Rutas y equipo", fontWeight = FontWeight.SemiBold)
                Text(
                    "Las oportunidades usan estas rutas y el tipo de unidad. Máximo 12 rutas.",
                    color = Muted,
                    fontSize = 13.sp,
                )
                Text("Equipo", color = Muted, fontSize = 12.sp)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Catalog.equipment.forEach { item ->
                        FilterChip(
                            selected = item in equipment,
                            onClick = {
                                equipment = if (item in equipment) equipment - item else equipment + item
                            },
                            label = { Text(item) },
                        )
                    }
                }
                routes.forEach { route ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            "${route.originState} → ${route.destinationState}" + if (route.bidirectional) " · ida y vuelta" else "",
                            modifier = Modifier.weight(1f),
                        )
                        TextButton(onClick = { routes = routes.filterNot { it.id == route.id } }) { Text("Quitar") }
                    }
                }
                Text("Origen", color = Muted, fontSize = 12.sp)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Catalog.mexicoStates.forEach { state ->
                        FilterChip(selected = origin == state, onClick = { origin = state }, label = { Text(state) })
                    }
                }
                Text("Destino", color = Muted, fontSize = 12.sp)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Catalog.mexicoStates.forEach { state ->
                        FilterChip(selected = destination == state, onClick = { destination = state }, label = { Text(state) })
                    }
                }
                SecondaryButton(
                    text = "Agregar ruta",
                    onClick = {
                        if (origin != destination && routes.none { it.originState == origin && it.destinationState == destination } && routes.size < 12) {
                            routes = routes + RouteCoverage(
                                id = UUID.randomUUID().toString(),
                                originState = origin,
                                destinationState = destination,
                                bidirectional = true,
                                equipmentTypes = emptyList(),
                            )
                        }
                    },
                )
                PrimaryButton(
                    text = if (busy) "Guardando…" else "Guardar rutas y equipo",
                    enabled = !busy,
                    onClick = { onClientPreferences(routes, equipment) },
                )
            }
            TextButton(onClick = onNotices) { Text("Avisos") }
            TextButton(onClick = onLogout) { Text("Cerrar sesión", color = Danger) }
        }
    }
}

@Composable
private fun Toggle(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(label, modifier = Modifier.weight(1f), fontSize = 14.sp)
        Switch(checked = checked, onCheckedChange = onChange)
    }
}

@Composable
fun NoticesScreen(
    notices: List<mx.continentecargo.conecta.data.Notice>,
    onBack: () -> Unit,
    onOpen: (mx.continentecargo.conecta.data.Notice) -> Unit,
    onMarkAll: () -> Unit,
) {
    val today = java.time.LocalDate.now(java.time.ZoneId.of("America/Monterrey"))
    Column(Modifier.fillMaxSize()) {
        NavyBar(title = "Avisos", onBack = onBack) {
            TextButton(onClick = onMarkAll) { Text("Marcar leídos", color = androidx.compose.ui.graphics.Color.White) }
        }
        if (notices.isEmpty()) {
            EmptyState(title = "Estás al día", subtitle = "Aquí aparecen las cargas y cambios de tus viajes.")
        } else {
            val groups = notices.groupBy { notice ->
                val day = notice.createdAt.toInstant().atZone(java.time.ZoneId.of("America/Monterrey")).toLocalDate()
                if (day == today) "Hoy" else "Anteriores"
            }
            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                listOf("Hoy", "Anteriores").forEach { label ->
                    val rows = groups[label].orEmpty()
                    if (rows.isNotEmpty()) {
                        item(key = "label-$label") { Text(label, fontWeight = FontWeight.SemiBold, color = Muted) }
                        items(rows, key = { it.id }) { notice ->
                            CardNotice(notice) { onOpen(notice) }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CardNotice(notice: mx.continentecargo.conecta.data.Notice, onClick: () -> Unit) {
    androidx.compose.material3.Card(onClick = onClick, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(notice.title, fontWeight = if (notice.isRead) FontWeight.Medium else FontWeight.Bold)
            Text(notice.body, color = Ink, fontSize = 14.sp)
            Text(mx.continentecargo.conecta.data.formatStamp(notice.createdAt), color = Muted, fontSize = 12.sp)
        }
    }
}

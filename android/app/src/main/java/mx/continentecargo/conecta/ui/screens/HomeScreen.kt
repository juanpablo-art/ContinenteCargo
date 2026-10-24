package mx.continentecargo.conecta.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mx.continentecargo.conecta.data.Catalog
import mx.continentecargo.conecta.data.FreightLoad
import mx.continentecargo.conecta.ui.components.EmptyState
import mx.continentecargo.conecta.ui.components.LoadCard
import mx.continentecargo.conecta.ui.components.NavyBar
import mx.continentecargo.conecta.ui.theme.Danger
import mx.continentecargo.conecta.ui.theme.Muted

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun HomeScreen(
    loads: List<FreightLoad>,
    unread: Int,
    dataError: String?,
    onOpen: (FreightLoad) -> Unit,
    onNotices: () -> Unit,
) {
    var query by rememberSaveable { mutableStateOf("") }
    var mode by rememberSaveable { mutableStateOf("") }
    var equipment by rememberSaveable { mutableStateOf("") }
    val filtered = loads.filter { load ->
        (mode.isBlank() || load.assignmentMode == mode) &&
            (equipment.isBlank() || load.equipmentType == equipment) &&
            (query.isBlank() || listOf(
                load.originCity,
                load.destinationCity,
                load.originState,
                load.destinationState,
                load.reference,
            ).joinToString(" ").contains(query.trim(), ignoreCase = true))
    }
    Column(Modifier.fillMaxSize()) {
        NavyBar(title = "Cargas") {
            IconButton(onClick = onNotices) {
                BadgedBox(
                    badge = {
                        if (unread > 0) {
                            Badge { Text(if (unread > 9) "9+" else unread.toString()) }
                        }
                    },
                ) {
                    Icon(Icons.Outlined.Notifications, contentDescription = "Avisos", tint = Color.White)
                }
            }
        }
        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Text(
                    if (filtered.size == 1) "1 carga abierta para ti" else "${filtered.size} cargas abiertas para ti",
                    color = Muted,
                    fontSize = 13.sp,
                )
            }
            item {
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    modifier = Modifier.fillMaxWidth(),
                    placeholder = { Text("Buscar ciudad, estado o referencia") },
                    singleLine = true,
                )
            }
            item {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(selected = mode.isBlank(), onClick = { mode = "" }, label = { Text("Todas") })
                    Catalog.assignmentModes.forEach { item ->
                        FilterChip(selected = mode == item, onClick = { mode = item }, label = { Text(item) })
                    }
                }
            }
            item {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(selected = equipment.isBlank(), onClick = { equipment = "" }, label = { Text("Equipo") })
                    loads.map { it.equipmentType }.distinct().sorted().forEach { item ->
                        FilterChip(
                            selected = equipment == item,
                            onClick = { equipment = if (equipment == item) "" else item },
                            label = { Text(item) },
                        )
                    }
                }
            }
            if (!dataError.isNullOrBlank()) {
                item { Text(dataError, color = Danger, fontSize = 13.sp) }
            }
            if (filtered.isEmpty()) {
                item {
                    val filtering = query.isNotBlank() || mode.isNotBlank() || equipment.isNotBlank()
                    EmptyState(
                        title = if (filtering) "Nada con esos filtros" else "Sin cargas por ahora",
                        subtitle = if (filtering) {
                            "Prueba con otra ciudad o quita los filtros."
                        } else {
                            "Te avisaremos en cuanto se publique una carga en tus rutas."
                        },
                    )
                }
            } else {
                items(filtered, key = { it.id }) { load ->
                    LoadCard(load, onClick = { onOpen(load) })
                }
            }
        }
    }
}

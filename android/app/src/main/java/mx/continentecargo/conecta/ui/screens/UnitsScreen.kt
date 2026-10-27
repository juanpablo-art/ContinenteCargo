package mx.continentecargo.conecta.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import mx.continentecargo.conecta.data.Catalog
import mx.continentecargo.conecta.data.FleetUnit
import mx.continentecargo.conecta.data.formatDay
import mx.continentecargo.conecta.ui.components.EmptyState
import mx.continentecargo.conecta.ui.components.NavyBar
import mx.continentecargo.conecta.ui.components.PrimaryButton
import mx.continentecargo.conecta.ui.components.SecondaryButton
import mx.continentecargo.conecta.ui.components.StatusBadge
import mx.continentecargo.conecta.ui.theme.Ink
import mx.continentecargo.conecta.ui.theme.Muted

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun UnitsScreen(
    units: List<FleetUnit>,
    ownerId: String,
    busy: Boolean,
    onSave: (FleetUnit, Boolean) -> Unit,
    onDelete: (String) -> Unit,
    onStatus: (String, String) -> Unit,
) {
    var editing by remember { mutableStateOf<FleetUnit?>(null) }
    var creating by remember { mutableStateOf(false) }
    var deleting by remember { mutableStateOf<FleetUnit?>(null) }
    Column(Modifier.fillMaxSize()) {
        NavyBar(title = "Mis unidades") {
            IconButton(onClick = { creating = true }) {
                Icon(Icons.Outlined.Add, contentDescription = "Agregar unidad", tint = Color.White)
            }
        }
        if (units.isEmpty()) {
            EmptyState(
                title = "Aún no tienes unidades",
                subtitle = "Agrega tu flota para tomar cargas de tarifa fija y publicar disponibilidad.",
            )
            PrimaryButton(
                text = "Agregar unidad",
                onClick = { creating = true },
                modifier = Modifier.padding(16.dp),
            )
        } else {
            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                items(units, key = { it.id }) { unit ->
                    Card(shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(
                                    unit.plates.ifBlank { unit.trailerNumber }.ifBlank { "Sin placas" },
                                    fontWeight = FontWeight.Bold,
                                    modifier = Modifier.weight(1f),
                                )
                                StatusBadge(unit.status)
                            }
                            Text(unit.equipmentType, color = Ink)
                            if (unit.currentLocation.isNotBlank()) Text(unit.currentLocation, color = Muted)
                            if (unit.operatorName.isNotBlank()) Text(unit.operatorName, color = Muted)
                            Text("Disponible desde ${formatDay(unit.availableFrom)}", color = Muted)
                            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Catalog.unitStatuses.forEach { status ->
                                    FilterChip(
                                        selected = unit.status == status,
                                        onClick = { if (unit.status != status) onStatus(unit.id, status) },
                                        label = { Text(status) },
                                    )
                                }
                            }
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                TextButton(onClick = { editing = unit }) { Text("Editar") }
                                TextButton(onClick = { deleting = unit }) { Text("Eliminar", color = mx.continentecargo.conecta.ui.theme.Danger) }
                            }
                        }
                    }
                }
            }
        }
    }
    if (creating || editing != null) {
        val initial = editing ?: FleetUnit.draft(ownerId)
        UnitDialog(
            initial = initial,
            isNew = editing == null,
            busy = busy,
            onDismiss = {
                creating = false
                editing = null
            },
            onSave = { unit ->
                onSave(unit, editing == null)
                creating = false
                editing = null
            },
        )
    }
    deleting?.let { unit ->
        AlertDialog(
            onDismissRequest = { deleting = null },
            title = { Text("¿Eliminar unidad?") },
            text = { Text("Se eliminará la unidad ${unit.plates.ifBlank { "sin placas" }}. Esta acción no se puede deshacer.") },
            confirmButton = {
                TextButton(onClick = {
                    onDelete(unit.id)
                    deleting = null
                }) { Text("Eliminar") }
            },
            dismissButton = { TextButton(onClick = { deleting = null }) { Text("Cancelar") } },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
private fun UnitDialog(
    initial: FleetUnit,
    isNew: Boolean,
    busy: Boolean,
    onDismiss: () -> Unit,
    onSave: (FleetUnit) -> Unit,
) {
    var equipment by remember(initial.id) { mutableStateOf(initial.equipmentType) }
    var plates by remember(initial.id) { mutableStateOf(initial.plates) }
    var trailer by remember(initial.id) { mutableStateOf(initial.trailerNumber) }
    var location by remember(initial.id) { mutableStateOf(initial.currentLocation) }
    var operator by remember(initial.id) { mutableStateOf(initial.operatorName) }
    var scac by remember(initial.id) { mutableStateOf(initial.scac) }
    var caat by remember(initial.id) { mutableStateOf(initial.caat) }
    var notes by remember(initial.id) { mutableStateOf(initial.notes) }
    var status by remember(initial.id) { mutableStateOf(initial.status) }
    var open by remember { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (isNew) "Nueva unidad" else "Editar unidad") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Los datos se comparten con Continente Cargo al asignarte un viaje.", color = Muted)
                ExposedDropdownMenuBox(expanded = open, onExpandedChange = { open = it }) {
                    OutlinedTextField(
                        value = equipment,
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("Tipo de equipo") },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(open) },
                        modifier = Modifier.menuAnchor(MenuAnchorType.PrimaryNotEditable).fillMaxWidth(),
                    )
                    ExposedDropdownMenu(expanded = open, onDismissRequest = { open = false }) {
                        Catalog.equipment.forEach { item ->
                            DropdownMenuItem(
                                text = { Text(item) },
                                onClick = {
                                    equipment = item
                                    open = false
                                },
                            )
                        }
                    }
                }
                OutlinedTextField(plates, { plates = it.uppercase() }, label = { Text("Placas") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(trailer, { trailer = it }, label = { Text("Número de caja") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(location, { location = it }, label = { Text("Ubicación actual") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(operator, { operator = it }, label = { Text("Operador") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(scac, { scac = it.uppercase() }, label = { Text("SCAC") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(caat, { caat = it }, label = { Text("CAAT") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(notes, { notes = it }, label = { Text("Notas") }, modifier = Modifier.fillMaxWidth())
                Text("Estado", fontWeight = FontWeight.SemiBold)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Catalog.unitStatuses.forEach { item ->
                        FilterChip(selected = status == item, onClick = { status = item }, label = { Text(item) })
                    }
                }
            }
        },
        confirmButton = {
            PrimaryButton(
                text = if (busy) "Guardando…" else if (isNew) "Agregar unidad" else "Guardar cambios",
                enabled = !busy,
                onClick = {
                    onSave(
                        initial.copy(
                            equipmentType = equipment,
                            plates = plates.trim(),
                            trailerNumber = trailer.trim(),
                            currentLocation = location.trim(),
                            operatorName = operator.trim(),
                            scac = scac.trim(),
                            caat = caat.trim(),
                            notes = notes.trim(),
                            status = status,
                        ),
                    )
                },
            )
        },
        dismissButton = { SecondaryButton(text = "Cancelar", onClick = onDismiss) },
    )
}

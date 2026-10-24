package mx.continentecargo.conecta.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mx.continentecargo.conecta.data.FleetUnit
import mx.continentecargo.conecta.data.FreightLoad
import mx.continentecargo.conecta.data.canSeePrivate
import mx.continentecargo.conecta.data.dateFromPicker
import mx.continentecargo.conecta.data.eligibleUnits
import mx.continentecargo.conecta.data.formatDay
import mx.continentecargo.conecta.data.formatMoney
import mx.continentecargo.conecta.data.formatStamp
import mx.continentecargo.conecta.data.pickerMillis
import mx.continentecargo.conecta.data.vatLabel
import mx.continentecargo.conecta.ui.ConectaUi
import mx.continentecargo.conecta.ui.components.InfoRow
import mx.continentecargo.conecta.ui.components.NavyBar
import mx.continentecargo.conecta.ui.components.PrimaryButton
import mx.continentecargo.conecta.ui.components.SectionLabel
import mx.continentecargo.conecta.ui.components.StatusBadge
import mx.continentecargo.conecta.ui.theme.Amber
import mx.continentecargo.conecta.ui.theme.Ink
import mx.continentecargo.conecta.ui.theme.Muted
import java.util.Date

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LoadDetailScreen(
    loadId: String,
    ui: ConectaUi,
    busy: Boolean,
    onBack: () -> Unit,
    onFixed: (FreightLoad, String?, String, Date, String, Int, Double) -> Unit,
    onBid: (FreightLoad, Double, String?, Int) -> Unit,
    onAvailability: (FreightLoad, String?, Double?) -> Unit,
    onLtl: (FreightLoad, Double, String) -> Unit,
) {
    val load = ui.loads.firstOrNull { it.id == loadId }
    Column(Modifier.fillMaxSize()) {
        NavyBar(title = load?.reference ?: "Detalle de carga", onBack = onBack)
        if (load == null) {
            Text("Esta carga ya no está disponible.", modifier = Modifier.padding(20.dp), color = Muted)
            return
        }
        val units = eligibleUnits(ui.profile, ui.units, load)
        val open = load.status == "Publicado" && Date().before(load.deadline)
        Column(
            Modifier
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(load.routeLabel, fontWeight = FontWeight.Bold, fontSize = 22.sp, modifier = Modifier.weight(1f))
                StatusBadge(load.status)
            }
            Text("${load.originCity}, ${load.originState}  →  ${load.destinationCity}, ${load.destinationState}", color = Muted)
            InfoRow("Equipo", load.equipmentType)
            InfoRow("Recolección", formatDay(load.pickupDate))
            InfoRow("Entrega", formatDay(load.deliveryDate))
            InfoRow("Cierra", formatStamp(load.deadline))
            InfoRow("Unidades", "${load.confirmedUnitCount} de ${load.unitCount} confirmadas")
            if (load.weightKg > 0) InfoRow("Peso", "${load.weightKg.toInt()} kg")
            InfoRow("Mercancía", load.merchandiseDescription)
            InfoRow("Medidas", load.measurementsDescription)
            if (load.specialRequirements.isNotEmpty()) {
                InfoRow("Requisitos", load.specialRequirements.joinToString(", "))
            }
            InfoRow("Observaciones", load.observations)
            Text(
                "${formatMoney(load.offeredPrice, load.currency)} · ${vatLabel(load.includesVAT)}",
                fontWeight = FontWeight.Bold,
                color = Ink,
                fontSize = 18.sp,
            )
            Text(load.assignmentMode, color = Muted, fontSize = 13.sp)
            if (canSeePrivate(ui.profile, load)) {
                SectionLabel("Contacto y direcciones")
                InfoRow("Contacto", load.clientContactName)
                InfoRow("Teléfono", load.clientContactPhone)
                InfoRow("Recolección", load.exactPickupAddress)
                InfoRow("Entrega", load.exactDeliveryAddress)
                load.carta?.let { carta ->
                    SectionLabel("Carta de instrucción")
                    InfoRow("Folio", carta.folio)
                    InfoRow("Recolección", carta.recoleccion)
                    InfoRow("Entrega", carta.entrega)
                }
            } else {
                Text(
                    "Las direcciones exactas y el contacto del cliente se muestran al confirmar tu participación.",
                    color = Muted,
                    fontSize = 13.sp,
                )
            }
            if (open) {
                when (load.assignmentMode) {
                    "Tarifa Fija" -> FixedPanel(load, units, busy, onFixed)
                    "Subasta Inversa" -> BidPanel(load, ui, units, busy, onBid)
                    "Confirmación Manual" -> AvailabilityPanel(load, units, busy, onAvailability)
                    "Consolidada LTL" -> LtlPanel(load, busy, onLtl)
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FixedPanel(
    load: FreightLoad,
    units: List<FleetUnit>,
    busy: Boolean,
    onFixed: (FreightLoad, String?, String, Date, String, Int, Double) -> Unit,
) {
    var priceText by remember(load.id) { mutableStateOf(load.offeredPrice.toInt().toString()) }
    var count by remember(load.id) { mutableIntStateOf(load.placesLeft.coerceAtLeast(1)) }
    var unitId by remember(load.id) { mutableStateOf(units.singleOrNull()?.id) }
    var phone by remember(load.id) { mutableStateOf("") }
    var tracking by remember(load.id) { mutableStateOf("") }
    var eta by remember(load.id) { mutableStateOf(load.pickupDate) }
    var picking by remember { mutableStateOf(false) }
    val price = priceText.toDoubleOrNull()
    val over = price != null && price > load.offeredPrice &&
        (load.maxAuthorizedPriceSinIVA?.let { price > it } ?: true)
    SectionLabel("Confirmar y tomar carga")
    OutlinedTextField(
        value = priceText,
        onValueChange = { priceText = it.filter { ch -> ch.isDigit() || ch == '.' } },
        label = { Text("Tu precio por unidad (sin IVA)") },
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        shape = RoundedCornerShape(12.dp),
    )
    if (over) {
        Text(
            "Tu precio supera el máximo autorizado. Se enviará al administrador para aprobación.",
            color = Amber,
            fontSize = 13.sp,
        )
    }
    if (load.unitCount > 1) {
        OutlinedTextField(
            value = count.toString(),
            onValueChange = { raw -> raw.toIntOrNull()?.let { count = it.coerceIn(1, load.placesLeft.coerceAtLeast(1)) } },
            label = { Text("Unidades (máx. ${load.placesLeft})") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
        )
    }
    UnitPicker(units, unitId) { unitId = it }
    OutlinedTextField(
        value = phone,
        onValueChange = { phone = it },
        label = { Text("Teléfono del operador (opcional)") },
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
    )
    OutlinedTextField(
        value = tracking,
        onValueChange = { tracking = it },
        label = { Text("Liga de rastreo (opcional)") },
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
    )
    TextButton(onClick = { picking = true }) { Text("Llegada al origen: ${formatDay(eta)}") }
    if (picking) {
        val state = rememberDatePickerState(initialSelectedDateMillis = pickerMillis(eta))
        DatePickerDialog(
            onDismissRequest = { picking = false },
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let { eta = dateFromPicker(it) }
                    picking = false
                }) { Text("Listo") }
            },
            dismissButton = { TextButton(onClick = { picking = false }) { Text("Cancelar") } },
        ) { DatePicker(state) }
    }
    val needsUnit = load.unitCount <= 1 && unitId.isNullOrBlank()
    PrimaryButton(
        text = if (busy) "Enviando…" else if (over) "Enviar para aprobación" else "Confirmar y tomar carga",
        enabled = !busy && price != null && price > 0 && !needsUnit && load.placesLeft > 0,
        onClick = { onFixed(load, unitId, phone, eta, tracking, if (load.unitCount > 1) count else 1, price ?: 0.0) },
    )
}

@Composable
private fun BidPanel(
    load: FreightLoad,
    ui: ConectaUi,
    units: List<FleetUnit>,
    busy: Boolean,
    onBid: (FreightLoad, Double, String?, Int) -> Unit,
) {
    var amount by remember(load.id) { mutableStateOf("") }
    var unitId by remember(load.id) { mutableStateOf<String?>(null) }
    var count by remember(load.id) { mutableIntStateOf(1) }
    val best = ui.offers
        .filter { it.loadId == load.id && (it.status == "Activa" || it.status == "Ganando") }
        .minOfOrNull { it.amount }
    SectionLabel("Subasta inversa")
    Text("Gana la oferta más baja al cierre.", color = Muted, fontSize = 13.sp)
    if (best != null) {
        Text("Mejor oferta: ${formatMoney(best, load.currency)}", fontWeight = FontWeight.SemiBold)
        Text("Decremento mínimo: ${formatMoney(load.minBidDecrement, load.currency)}", color = Muted, fontSize = 13.sp)
    }
    OutlinedTextField(
        value = amount,
        onValueChange = { amount = it.filter { ch -> ch.isDigit() || ch == '.' } },
        label = { Text("Tu oferta") },
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
    )
    if (load.unitCount > 1) {
        OutlinedTextField(
            value = count.toString(),
            onValueChange = { raw -> raw.toIntOrNull()?.let { count = it.coerceAtLeast(1) } },
            label = { Text("Unidades") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
        )
    }
    UnitPicker(units, unitId) { unitId = it }
    PrimaryButton(
        text = if (busy) "Enviando…" else "Enviar oferta",
        enabled = !busy && (amount.toDoubleOrNull() ?: 0.0) > 0,
        onClick = { onBid(load, amount.toDoubleOrNull() ?: 0.0, unitId, count) },
    )
}

@Composable
private fun AvailabilityPanel(
    load: FreightLoad,
    units: List<FleetUnit>,
    busy: Boolean,
    onAvailability: (FreightLoad, String?, Double?) -> Unit,
) {
    var unitId by remember(load.id) { mutableStateOf<String?>(null) }
    var custom by remember(load.id) { mutableStateOf(false) }
    var price by remember(load.id) { mutableStateOf(load.offeredPrice.toInt().toString()) }
    SectionLabel("Indicar disponibilidad")
    UnitPicker(units, unitId) { unitId = it }
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text("Proponer un precio distinto", modifier = Modifier.weight(1f))
        Switch(checked = custom, onCheckedChange = { custom = it })
    }
    if (custom) {
        OutlinedTextField(
            value = price,
            onValueChange = { price = it.filter { ch -> ch.isDigit() || ch == '.' } },
            label = { Text("Precio por unidad") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
        )
    }
    PrimaryButton(
        text = if (busy) "Enviando…" else "Enviar disponibilidad",
        enabled = !busy,
        onClick = {
            onAvailability(load, unitId, if (custom) price.toDoubleOrNull() else null)
        },
    )
}

@Composable
private fun LtlPanel(
    load: FreightLoad,
    busy: Boolean,
    onLtl: (FreightLoad, Double, String) -> Unit,
) {
    var amount by remember(load.id) { mutableStateOf("") }
    var notes by remember(load.id) { mutableStateOf("") }
    SectionLabel("Cotización LTL")
    Text("Cada consolidadora cotiza su propio precio.", color = Muted, fontSize = 13.sp)
    OutlinedTextField(
        value = amount,
        onValueChange = { amount = it.filter { ch -> ch.isDigit() || ch == '.' } },
        label = { Text("Tu cotización") },
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
    )
    OutlinedTextField(
        value = notes,
        onValueChange = { notes = it },
        label = { Text("Tiempo de tránsito, condiciones, etc.") },
        modifier = Modifier.fillMaxWidth(),
    )
    PrimaryButton(
        text = if (busy) "Enviando…" else "Enviar cotización",
        enabled = !busy && (amount.toDoubleOrNull() ?: 0.0) > 0,
        onClick = { onLtl(load, amount.toDoubleOrNull() ?: 0.0, notes.trim()) },
    )
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun UnitPicker(units: List<FleetUnit>, selected: String?, onSelect: (String?) -> Unit) {
    if (units.isEmpty()) {
        Text("Sin unidad específica. Agrega una unidad disponible de este equipo.", color = Muted, fontSize = 13.sp)
        return
    }
    SectionLabel("Unidad")
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        FilterChip(selected = selected == null, onClick = { onSelect(null) }, label = { Text("Sin unidad") })
        units.forEach { unit ->
            val label = unit.plates.ifBlank { unit.trailerNumber }.ifBlank { unit.equipmentType }
            FilterChip(selected = selected == unit.id, onClick = { onSelect(unit.id) }, label = { Text(label) })
        }
    }
}

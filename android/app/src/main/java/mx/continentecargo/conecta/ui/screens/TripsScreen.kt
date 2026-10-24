package mx.continentecargo.conecta.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mx.continentecargo.conecta.data.Catalog
import mx.continentecargo.conecta.data.FreightLoad
import mx.continentecargo.conecta.data.canSeePrivate
import mx.continentecargo.conecta.data.formatDay
import mx.continentecargo.conecta.data.formatMoney
import mx.continentecargo.conecta.data.vatLabel
import mx.continentecargo.conecta.ui.ConectaUi
import mx.continentecargo.conecta.ui.components.EmptyState
import mx.continentecargo.conecta.ui.components.InfoRow
import mx.continentecargo.conecta.ui.components.LoadCard
import mx.continentecargo.conecta.ui.components.NavyBar
import mx.continentecargo.conecta.ui.components.PrimaryButton
import mx.continentecargo.conecta.ui.components.SectionLabel
import mx.continentecargo.conecta.ui.theme.Brand
import mx.continentecargo.conecta.ui.theme.Line
import mx.continentecargo.conecta.ui.theme.Muted
import mx.continentecargo.conecta.ui.theme.Success

@Composable
fun TripsScreen(
    trips: List<FreightLoad>,
    onOpen: (FreightLoad) -> Unit,
) {
    var past by rememberSaveable { mutableStateOf(false) }
    val shown = trips.filter { load ->
        val done = load.status == "Entregado" || load.status == "Cancelado"
        if (past) done else !done
    }
    Column(Modifier.fillMaxSize()) {
        NavyBar(title = "Mis viajes")
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Da seguimiento y actualiza el estatus de tus cargas", color = Muted, fontSize = 13.sp)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(selected = !past, onClick = { past = false }, label = { Text("En curso") })
                FilterChip(selected = past, onClick = { past = true }, label = { Text("Historial") })
            }
        }
        if (shown.isEmpty()) {
            EmptyState(
                title = if (past) "Aún no hay historial" else "Sin viajes en curso",
                subtitle = "Cuando confirmes o ganes una carga, aparecerá aquí.",
            )
        } else {
            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                items(shown, key = { it.id }) { load ->
                    LoadCard(load) { onOpen(load) }
                }
            }
        }
    }
}

@Composable
fun TripDetailScreen(
    loadId: String,
    ui: ConectaUi,
    busy: Boolean,
    onBack: () -> Unit,
    onAdvance: (FreightLoad, String) -> Unit,
) {
    val load = ui.loads.firstOrNull { it.id == loadId }
    Column(Modifier.fillMaxSize()) {
        NavyBar(title = "Detalle de viaje", onBack = onBack)
        if (load == null) {
            Text("Este viaje ya no está en tu lista.", modifier = Modifier.padding(20.dp), color = Muted)
            return
        }
        val index = Catalog.tripSteps.indexOf(load.status)
        val next = when {
            index >= Catalog.tripSteps.lastIndex -> null
            index < 0 -> Catalog.tripSteps.first()
            else -> Catalog.tripSteps[index + 1]
        }
        val price = load.assignedPriceSinIVA ?: load.offeredPrice
        Column(
            Modifier
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(load.reference, color = Brand, fontWeight = FontWeight.SemiBold)
            Text(load.routeLabel, fontWeight = FontWeight.Bold, fontSize = 22.sp)
            Text("${load.originState} → ${load.destinationState}", color = Muted)
            InfoRow("Equipo", load.equipmentType)
            InfoRow("Recolección", formatDay(load.pickupDate))
            InfoRow("Entrega", formatDay(load.deliveryDate))
            Text(formatMoney(price, load.currency), fontWeight = FontWeight.Bold, fontSize = 20.sp)
            Text(vatLabel(load.includesVAT), color = Muted, fontSize = 13.sp)
            if (load.unitCount > 1) {
                InfoRow("Unidades", "Tomaste participación en ${load.unitCount} unidades publicadas")
            }
            SectionLabel("Progreso del viaje")
            Catalog.tripSteps.forEachIndexed { step, label ->
                val done = index >= step && index >= 0
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    androidx.compose.foundation.layout.Box(
                        Modifier
                            .size(12.dp)
                            .clip(CircleShape)
                            .background(if (done) Success else Line),
                    )
                    Text(label, color = if (done) Color(0xFF10243A) else Muted, fontWeight = if (label == load.status) FontWeight.Bold else FontWeight.Normal)
                }
            }
            if (canSeePrivate(ui.profile, load)) {
                SectionLabel("Contacto")
                InfoRow("Nombre", load.clientContactName)
                InfoRow("Teléfono", load.clientContactPhone)
                InfoRow("Recolección", load.exactPickupAddress)
                InfoRow("Entrega", load.exactDeliveryAddress)
            }
            load.carta?.let { carta ->
                SectionLabel("Carta de instrucción")
                InfoRow("Folio", carta.folio)
                InfoRow("Recolección", carta.recoleccion)
                InfoRow("Entrega", carta.entrega)
                InfoRow("Contacto de carga", carta.contactoCarga)
                InfoRow("Contacto de descarga", carta.contactoDescarga)
                InfoRow("Observaciones", carta.observaciones)
            } ?: Text("La carta de instrucción no está disponible.", color = Muted, fontSize = 13.sp)
            if (load.trackingUrl.isNotBlank()) InfoRow("Rastreo", load.trackingUrl)
            if (next != null && load.status != "Cancelado") {
                Text(
                    "Continente Cargo y el cliente verán el cambio de inmediato.",
                    color = Muted,
                    fontSize = 13.sp,
                )
                PrimaryButton(
                    text = if (busy) "Actualizando…" else "Marcar como “$next”",
                    enabled = !busy,
                    onClick = { onAdvance(load, next) },
                )
            }
        }
    }
}

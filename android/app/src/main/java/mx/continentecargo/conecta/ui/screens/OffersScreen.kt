package mx.continentecargo.conecta.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mx.continentecargo.conecta.data.FreightLoad
import mx.continentecargo.conecta.data.FreightOffer
import mx.continentecargo.conecta.data.formatMoney
import mx.continentecargo.conecta.data.formatStamp
import mx.continentecargo.conecta.ui.components.EmptyState
import mx.continentecargo.conecta.ui.components.NavyBar
import mx.continentecargo.conecta.ui.components.PrimaryButton
import mx.continentecargo.conecta.ui.components.SecondaryButton
import mx.continentecargo.conecta.ui.components.StatusBadge
import mx.continentecargo.conecta.ui.theme.Amber
import mx.continentecargo.conecta.ui.theme.Ink
import mx.continentecargo.conecta.ui.theme.Muted
import java.util.Date

@Composable
fun OffersScreen(
    offers: List<FreightOffer>,
    loads: List<FreightLoad>,
    busy: Boolean,
    onOpenLoad: (String) -> Unit,
    onImprove: (FreightOffer, Double, Int) -> Unit,
    onAnswer: (FreightOffer, String) -> Unit,
) {
    var selected by remember { mutableStateOf<FreightOffer?>(null) }
    Column(Modifier.fillMaxSize()) {
        NavyBar(title = "Mis ofertas")
        if (offers.isEmpty()) {
            EmptyState(
                title = "Sin ofertas",
                subtitle = "Cuando participes en una carga, la verás aquí.",
            )
        } else {
            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item {
                    Text("Ofertas activas y pendientes de aprobación", color = Muted, fontSize = 13.sp)
                }
                items(offers, key = { it.id }) { offer ->
                    val load = loads.firstOrNull { it.id == offer.loadId }
                    Card(onClick = { selected = offer }, shape = RoundedCornerShape(16.dp)) {
                        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(load?.reference ?: offer.loadId.take(8), fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                                StatusBadge(offer.status)
                            }
                            Text(
                                load?.let { "${it.originCity} → ${it.destinationCity}" } ?: "Carga",
                                color = Ink,
                            )
                            Text(formatStamp(offer.submittedAt), color = Muted, fontSize = 12.sp)
                            Text(
                                formatMoney(offer.proposedPrice ?: offer.amount, offer.currency),
                                fontWeight = FontWeight.Bold,
                            )
                            if (offer.status == "Ganando" && load != null && Date().before(load.deadline)) {
                                Text("Vas ganando", color = mx.continentecargo.conecta.ui.theme.Success, fontWeight = FontWeight.SemiBold)
                            }
                        }
                    }
                }
            }
        }
    }
    selected?.let { offer ->
        val load = loads.firstOrNull { it.id == offer.loadId }
        OfferDialog(
            offer = offer,
            load = load,
            busy = busy,
            onDismiss = { selected = null },
            onOpen = {
                selected = null
                onOpenLoad(offer.loadId)
            },
            onImprove = { price, units ->
                onImprove(offer, price, units)
                selected = null
            },
            onAnswer = { decision ->
                onAnswer(offer, decision)
                selected = null
            },
        )
    }
}

@Composable
private fun OfferDialog(
    offer: FreightOffer,
    load: FreightLoad?,
    busy: Boolean,
    onDismiss: () -> Unit,
    onOpen: () -> Unit,
    onImprove: (Double, Int) -> Unit,
    onAnswer: (String) -> Unit,
) {
    var price by remember(offer.id) { mutableStateOf((offer.proposedPrice ?: offer.amount).toString()) }
    var units by remember(offer.id) { mutableStateOf(offer.availableUnitCount.toString()) }
    val canEdit = load != null && load.status == "Publicado" && Date().before(load.deadline) &&
        offer.status in setOf("Activa", "Ganando", "Superada")
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(load?.reference ?: "Oferta") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                if (load != null) {
                    Text("${load.originCity}, ${load.originState} → ${load.destinationCity}, ${load.destinationState}")
                    Text("${load.equipmentType} · ${formatStamp(load.pickupDate)}", color = Muted, fontSize = 13.sp)
                }
                Text(formatMoney(offer.proposedPrice ?: offer.amount, offer.currency), fontWeight = FontWeight.Bold)
                if (offer.notes.isNotBlank()) Text(offer.notes, color = Muted, fontSize = 13.sp)
                if (offer.staffCounterPrice != null) {
                    Text(
                        "${offer.staffCounterByName ?: "El equipo"} propone ${formatMoney(offer.staffCounterPrice, offer.currency)} / ud",
                        color = Amber,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        when (offer.staffCounterStatus) {
                            "Aceptada" -> "Aceptada. El viaje se asigna con este precio."
                            "Rechazada" -> "Rechazaste esta contra propuesta. Tu oferta original sigue pendiente."
                            else -> "Puedes aceptar o rechazar. La carga no se asigna hasta que aceptes."
                        },
                        fontSize = 13.sp,
                    )
                }
                if (canEdit) {
                    OutlinedTextField(
                        value = price,
                        onValueChange = { price = it.filter { ch -> ch.isDigit() || ch == '.' } },
                        label = { Text("Precio por unidad (sin IVA)") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    if ((load?.unitCount ?: 1) > 1) {
                        OutlinedTextField(
                            value = units,
                            onValueChange = { units = it.filter { ch -> ch.isDigit() } },
                            label = { Text("Unidades") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
            }
        },
        confirmButton = {
            Column {
                if (offer.staffCounterStatus == "PendienteTransportista") {
                    PrimaryButton(text = "Aceptar", onClick = { onAnswer("Aceptada") })
                    SecondaryButton(text = "Rechazar", onClick = { onAnswer("Rechazada") })
                }
                if (canEdit) {
                    PrimaryButton(
                        text = if (busy) "Guardando…" else "Actualizar oferta",
                        enabled = !busy && (price.toDoubleOrNull() ?: 0.0) > 0,
                        onClick = { onImprove(price.toDoubleOrNull() ?: 0.0, units.toIntOrNull() ?: 1) },
                    )
                }
                TextButton(onClick = onOpen) { Text("Ver carga") }
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cerrar") } },
    )
}

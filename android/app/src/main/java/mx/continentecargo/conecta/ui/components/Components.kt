package mx.continentecargo.conecta.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mx.continentecargo.conecta.data.FreightLoad
import mx.continentecargo.conecta.data.formatDay
import mx.continentecargo.conecta.data.formatMoney
import mx.continentecargo.conecta.ui.theme.Amber
import mx.continentecargo.conecta.ui.theme.AmberSoft
import mx.continentecargo.conecta.ui.theme.Brand
import mx.continentecargo.conecta.ui.theme.BrandSoft
import mx.continentecargo.conecta.ui.theme.Danger
import mx.continentecargo.conecta.ui.theme.Ink
import mx.continentecargo.conecta.ui.theme.Line
import mx.continentecargo.conecta.ui.theme.Muted
import mx.continentecargo.conecta.ui.theme.NavyDeep
import mx.continentecargo.conecta.ui.theme.Success
import mx.continentecargo.conecta.ui.theme.SuccessSoft

@Composable
fun NavyBar(
    title: String,
    onBack: (() -> Unit)? = null,
    actions: @Composable RowScope.() -> Unit = {},
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(NavyDeep)
            .statusBarsPadding()
            .height(64.dp)
            .padding(horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (onBack != null) {
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "Regresar", tint = Color.White)
            }
        }
        Text(
            text = title,
            color = Color.White,
            fontWeight = FontWeight.SemiBold,
            fontSize = 18.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier
                .weight(1f)
                .padding(start = if (onBack == null) 12.dp else 0.dp),
        )
        actions()
    }
}

@Composable
fun PrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier
            .fillMaxWidth()
            .height(48.dp),
        shape = RoundedCornerShape(12.dp),
        colors = ButtonDefaults.buttonColors(containerColor = Brand, contentColor = Color.White),
    ) {
        Text(text, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
fun SecondaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    OutlinedButton(
        onClick = onClick,
        modifier = modifier
            .fillMaxWidth()
            .height(48.dp),
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(1.dp, Line),
    ) {
        Text(text, color = Ink, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
fun StatusBadge(status: String) {
    val (bg, fg) = when (status) {
        "Publicado", "Activa" -> BrandSoft to Brand
        "Ganando", "Ganadora", "Asignado", "Entregado", "Disponible" -> SuccessSoft to Success
        "PendienteAprobacion", "Superada", "Reservada", "En tránsito", "En camino a recolección", "En origen", "Cargado" ->
            AmberSoft to Amber
        "Cancelada", "Cancelado", "Rechazada", "Perdida", "Fuera de servicio" -> Color(0xFFFEECEC) to Danger
        else -> Color(0xFFEEF3F8) to Muted
    }
    val label = when (status) {
        "PendienteAprobacion" -> "Pendiente"
        else -> status
    }
    Surface(color = bg, shape = RoundedCornerShape(999.dp)) {
        Text(
            text = label,
            color = fg,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
        )
    }
}

@Composable
fun LoadCard(load: FreightLoad, onClick: () -> Unit) {
    Card(
        onClick = onClick,
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        border = BorderStroke(1.dp, Line),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(load.reference, color = Brand, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                StatusBadge(load.status)
            }
            Text(load.routeLabel, style = MaterialTheme.typography.titleMedium)
            Text(
                "${load.originState}  →  ${load.destinationState}",
                color = Muted,
                fontSize = 13.sp,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(load.equipmentType, fontSize = 13.sp, fontWeight = FontWeight.Medium)
                Text(formatDay(load.pickupDate), fontSize = 13.sp, color = Muted)
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    formatMoney(load.assignedPriceSinIVA ?: load.offeredPrice, load.currency),
                    fontWeight = FontWeight.Bold,
                    color = Ink,
                    modifier = Modifier.weight(1f),
                )
                Text(load.assignmentMode, color = Muted, fontSize = 12.sp)
            }
        }
    }
}

@Composable
fun EmptyState(title: String, subtitle: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 48.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(title, style = MaterialTheme.typography.titleMedium, color = Ink)
        Text(subtitle, color = Muted, fontSize = 14.sp)
    }
}

@Composable
fun SectionLabel(text: String) {
    Text(text, color = Muted, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
}

@Composable
fun InfoRow(label: String, value: String) {
    if (value.isBlank()) return
    Column(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
        Text(label, color = Muted, fontSize = 12.sp)
        Text(value, color = Ink, fontSize = 15.sp)
    }
}

@Composable
fun BellDot(count: Int, modifier: Modifier = Modifier) {
    if (count <= 0) return
    Surface(color = Danger, shape = RoundedCornerShape(99.dp), modifier = modifier.size(18.dp)) {
        Text(
            text = if (count > 9) "9+" else count.toString(),
            color = Color.White,
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(top = 1.dp),
        )
    }
}

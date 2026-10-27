package mx.continentecargo.conecta.ui.screens

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Mail
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mx.continentecargo.conecta.R
import mx.continentecargo.conecta.data.Catalog
import mx.continentecargo.conecta.data.RegisterInput
import mx.continentecargo.conecta.ui.components.PrimaryButton
import mx.continentecargo.conecta.ui.components.SecondaryButton
import mx.continentecargo.conecta.ui.theme.Brand
import mx.continentecargo.conecta.ui.theme.Canvas
import mx.continentecargo.conecta.ui.theme.Danger
import mx.continentecargo.conecta.ui.theme.Ink
import mx.continentecargo.conecta.ui.theme.Muted
import mx.continentecargo.conecta.ui.theme.NavyDeep

@Composable
fun SplashScreen() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(NavyDeep),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Image(
            painter = painterResource(R.drawable.logo_mark),
            contentDescription = "Continente Conecta",
            modifier = Modifier.size(88.dp),
        )
        Spacer(Modifier.height(20.dp))
        CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp, modifier = Modifier.size(28.dp))
    }
}

@Composable
fun LoginScreen(
    banner: String?,
    registered: Boolean,
    busy: Boolean,
    onLogin: (String, String) -> Unit,
    onReset: (String) -> Unit,
    onRegister: () -> Unit,
    onRetry: () -> Unit,
) {
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    var showReset by rememberSaveable { mutableStateOf(false) }
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Canvas)
            .imePadding()
            .verticalScroll(rememberScrollState()),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(NavyDeep)
                .statusBarsPadding()
                .padding(horizontal = 24.dp, vertical = 36.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Image(
                painter = painterResource(R.drawable.logo_mark),
                contentDescription = null,
                modifier = Modifier.size(72.dp),
            )
            Spacer(Modifier.height(12.dp))
            Text("Continente Conecta", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 22.sp)
            Text(
                "Plataforma de carga Continente Cargo",
                color = Color.White.copy(alpha = 0.75f),
                fontSize = 14.sp,
                textAlign = TextAlign.Center,
            )
        }
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            if (!banner.isNullOrBlank()) {
                Text(banner, color = if (registered) Brand else Danger, fontSize = 14.sp)
            }
            OutlinedTextField(
                value = email,
                onValueChange = { email = it },
                label = { Text("Correo electrónico") },
                leadingIcon = { Icon(Icons.Outlined.Mail, null) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp),
            )
            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                label = { Text("Contraseña") },
                leadingIcon = { Icon(Icons.Outlined.Lock, null) },
                visualTransformation = PasswordVisualTransformation(),
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp),
            )
            PrimaryButton(
                text = if (busy) "Entrando…" else "Entrar",
                enabled = !busy,
                onClick = { onLogin(email, password) },
            )
            TextButton(onClick = { showReset = true }, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                Text("Olvidé mi contraseña", color = Brand)
            }
            SecondaryButton(text = "Crear cuenta", onClick = onRegister)
            if (banner?.contains("conectar") == true) {
                TextButton(onClick = onRetry, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                    Text("Reintentar")
                }
            }
        }
    }
    if (showReset) {
        var resetEmail by rememberSaveable { mutableStateOf(email) }
        AlertDialog(
            onDismissRequest = { showReset = false },
            title = { Text("Restablecer contraseña") },
            text = {
                OutlinedTextField(
                    value = resetEmail,
                    onValueChange = { resetEmail = it },
                    label = { Text("Correo electrónico") },
                    singleLine = true,
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    onReset(resetEmail)
                    showReset = false
                }) { Text("Enviar") }
            },
            dismissButton = { TextButton(onClick = { showReset = false }) { Text("Cancelar") } },
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun RegisterScreen(
    banner: String?,
    busy: Boolean,
    onSubmit: (RegisterInput) -> Unit,
    onBack: () -> Unit,
) {
    var name by rememberSaveable { mutableStateOf("") }
    var company by rememberSaveable { mutableStateOf("") }
    var phone by rememberSaveable { mutableStateOf("") }
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    var rfc by rememberSaveable { mutableStateOf("") }
    var role by rememberSaveable { mutableStateOf("carrier") }
    var equipment by remember { mutableStateOf(listOf<String>()) }
    var states by remember { mutableStateOf(listOf<String>()) }
    var usa by remember { mutableStateOf(listOf<String>()) }
    var ltl by rememberSaveable { mutableStateOf(false) }
    var hazmat by rememberSaveable { mutableStateOf(false) }
    var local by rememberSaveable { mutableStateOf(false) }
    var intra by rememberSaveable { mutableStateOf(false) }
    var coversUsa by rememberSaveable { mutableStateOf(false) }
    var reveal by rememberSaveable { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Canvas)
            .statusBarsPadding()
            .imePadding()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        TextButton(onClick = onBack) { Text("Volver", color = Brand) }
        Text("Registro", style = MaterialTheme.typography.headlineMedium)
        Text(
            "Tu cuenta queda pendiente hasta que Continente Cargo la acepte.",
            color = Muted,
            fontSize = 14.sp,
        )
        if (!banner.isNullOrBlank()) Text(banner, color = Danger, fontSize = 14.sp)
        Field("Nombre", name) { name = it }
        Field("Empresa", company) { company = it }
        Field("WhatsApp / Teléfono", phone) { phone = it }
        Field("Correo electrónico", email) { email = it }
        OutlinedTextField(
            value = password,
            onValueChange = { password = it },
            label = { Text("Contraseña") },
            visualTransformation = if (reveal) VisualTransformation.None else PasswordVisualTransformation(),
            trailingIcon = {
                TextButton(onClick = { reveal = !reveal }) { Text(if (reveal) "Ocultar" else "Ver") }
            },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            shape = RoundedCornerShape(12.dp),
        )
        Field("RFC (opcional)", rfc) { rfc = it.uppercase() }
        Text("Tipo de cuenta", fontWeight = FontWeight.SemiBold, color = Ink)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FilterChip(
                selected = role == "carrier",
                onClick = { role = "carrier" },
                label = { Text("Línea transportista") },
            )
            FilterChip(
                selected = role == "independent_operator",
                onClick = { role = "independent_operator" },
                label = { Text("Operador independiente") },
            )
        }
        Text("Equipo que opero", fontWeight = FontWeight.SemiBold, color = Ink)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
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
        Text("Cobertura en México", fontWeight = FontWeight.SemiBold, color = Ink)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Catalog.mexicoStates.forEach { item ->
                FilterChip(
                    selected = item in states,
                    onClick = { states = if (item in states) states - item else states + item },
                    label = { Text(item) },
                )
            }
        }
        ToggleRow("Acepto cargas parciales que se agrupan con otros envíos", ltl) { ltl = it }
        ToggleRow("Puedo transportar materiales peligrosos con la documentación requerida.", hazmat) { hazmat = it }
        ToggleRow("Entrego dentro de la misma ciudad o zona metropolitana", local) { local = it }
        ToggleRow("También muevo cargas dentro del mismo estado", intra) { intra = it }
        ToggleRow("También opero en EE.UU.", coversUsa) { coversUsa = it }
        if (coversUsa) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Catalog.usaStates.forEach { item ->
                    FilterChip(
                        selected = item in usa,
                        onClick = { usa = if (item in usa) usa - item else usa + item },
                        label = { Text(item) },
                    )
                }
            }
        }
        PrimaryButton(
            text = if (busy) "Enviando…" else "Crear cuenta",
            enabled = !busy,
            onClick = {
                onSubmit(
                    RegisterInput(
                        name = name,
                        companyName = company,
                        phone = phone,
                        email = email,
                        password = password,
                        role = role,
                        equipment = equipment,
                        states = states,
                        handlesLtl = ltl,
                        handlesHazmat = hazmat,
                        handlesLocal = local,
                        handlesIntraState = intra,
                        coversUsa = coversUsa,
                        usaStates = usa,
                        rfc = rfc,
                    ),
                )
            },
        )
        Spacer(Modifier.height(12.dp))
    }
}

@Composable
private fun Field(label: String, value: String, onChange: (String) -> Unit) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        label = { Text(label) },
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
    )
}

@Composable
private fun ToggleRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    androidx.compose.foundation.layout.Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, modifier = Modifier.weight(1f), fontSize = 14.sp, color = Ink)
        Switch(checked = checked, onCheckedChange = onChange)
    }
}

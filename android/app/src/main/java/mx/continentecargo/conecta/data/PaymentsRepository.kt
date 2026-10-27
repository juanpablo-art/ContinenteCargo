package mx.continentecargo.conecta.data

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

class PaymentsRepository(
    private val db: FirebaseFirestore = FirebaseFirestore.getInstance(),
    private val auth: FirebaseAuth = FirebaseAuth.getInstance(),
) {
    suspend fun openCarrier(carrier: CarrierProfile): PaySnapshot = withContext(Dispatchers.IO) {
        try {
            val name = carrier.name.trim().take(60)
            var rows = if (name.length >= 2) supplierList("/supplier/list", mapOf("term" to name, "per_page" to "8")) else emptyList()
            if (rows.isEmpty()) {
                val digits = carrier.phone.filter { it.isDigit() }.takeLast(10)
                if (digits.length == 10) {
                    rows = supplierList("/supplier/list", mapOf("term" to digits, "per_page" to "8"))
                }
            }
            val rfc = companyRfc(carrier.companyId)
            if (rfc.isNotBlank()) {
                val byRfc = rows.filter { compactRfc(it.taxNumber) == rfc }
                rows = when {
                    byRfc.size == 1 -> byRfc
                    byRfc.isEmpty() -> catalogSupplier(rfc)?.let { listOf(it) } ?: rows
                    else -> rows
                }
            }
            if (rows.size == 1) openSupplier(rows.first().id) else PaySnapshot(
                suppliers = rows.map { PaySupplier(it.id, it.title) },
                needsRfc = rows.isEmpty(),
            )
        } catch (error: Exception) {
            PaySnapshot(error = payError(error))
        }
    }

    suspend fun openSupplier(id: String): PaySnapshot = withContext(Dispatchers.IO) {
        try {
            val account = getJson("/supplier/$id")
            val payments = runCatching { getJson("/portal/payment-requests", mapOf("supplier_id" to id, "per_page" to "20", "page" to "1")) }
            val portalError = payments.exceptionOrNull()?.let { payError(it) }
            val lines = payments.getOrNull()?.optJSONArray("data").toPayLines()
            PaySnapshot(
                suppliers = listOf(PaySupplier(id, accountTitle(account))),
                accountTitle = accountTitle(account),
                accountLine = accountLine(account),
                cards = accountCards(account),
                payments = lines,
                portalError = portalError,
            )
        } catch (error: Exception) {
            PaySnapshot(error = payError(error))
        }
    }

    suspend fun linkRfc(carrier: CarrierProfile, rfc: String): PaySnapshot = withContext(Dispatchers.IO) {
        val clean = compactRfc(rfc)
        if (!clean.matches(Regex("^[A-Z&Ñ]{3,4}[0-9]{6}[A-Z0-9]{3}$"))) {
            return@withContext PaySnapshot(error = "Escribe un RFC de 12 o 13 caracteres.", needsRfc = true)
        }
        try {
            val result = sendJson(
                "/portal/link-rfc",
                JSONObject().put("rfc", clean).put("companyId", carrier.companyId.orEmpty()),
                mapOf("rfc" to clean, "companyId" to carrier.companyId.orEmpty()),
            )
            val supplier = result.optJSONObject("supplier")
            if (supplier == null) PaySnapshot(needsRfc = true) else openSupplier(supplier.optString("id"))
        } catch (error: Exception) {
            PaySnapshot(error = payError(error), needsRfc = true)
        }
    }

    private suspend fun companyRfc(companyId: String?): String {
        if (companyId.isNullOrBlank()) return ""
        return runCatching {
            val snap = db.collection("companies").document(companyId).get().await()
            compactRfc(snap.getString("rfc"))
        }.getOrDefault("")
    }

    private suspend fun catalogSupplier(rfc: String): SupplierRow? {
        val catalog = runCatching { getJson("/portal/suppliers", mapOf("search" to rfc)) }.getOrNull() ?: return null
        val exact = catalog.optJSONArray("data").objects().firstOrNull { compactRfc(it.optString("tax_number")) == rfc } ?: return null
        val account = runCatching { getJson("/supplier/${exact.optString("id")}") }.getOrNull() ?: return null
        val id = account.optString("id")
        if (id.isBlank()) return null
        return SupplierRow(id, accountTitle(account), account.optString("tax_number"))
    }

    private suspend fun supplierList(path: String, query: Map<String, String>): List<SupplierRow> =
        getJson(path, query).optJSONArray("data").objects().mapNotNull { item ->
            val id = item.optString("id")
            if (id.isBlank()) null else SupplierRow(id, accountTitle(item), item.optString("tax_number"))
        }

    private suspend fun getJson(path: String, query: Map<String, String> = emptyMap()): JSONObject =
        request("GET", path, query, null)

    private suspend fun sendJson(path: String, body: JSONObject, query: Map<String, String>): JSONObject =
        request("POST", path, query, body)

    private suspend fun request(method: String, path: String, query: Map<String, String>, body: JSONObject?): JSONObject {
        val token = auth.currentUser?.getIdToken(false)?.await()?.token ?: error("Inicia sesión de nuevo.")
        val url = StringBuilder(FirebaseBackend.supplierProxyUrl)
            .append("?path=").append(encode(path))
        query.forEach { (key, value) ->
            if (value.isNotBlank()) url.append("&").append(encode(key)).append("=").append(encode(value))
        }
        val connection = (URL(url.toString()).openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = 20000
            readTimeout = 20000
            setRequestProperty("Authorization", "Bearer $token")
            setRequestProperty("Accept", "application/json")
            if (body != null) {
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
            }
        }
        if (body != null) connection.outputStream.use { it.write(body.toString().toByteArray()) }
        val code = connection.responseCode
        val text = (if (code in 200..299) connection.inputStream else connection.errorStream)
            ?.bufferedReader()?.use { it.readText() }.orEmpty()
        val json = runCatching { JSONObject(text.ifBlank { "{}" }) }.getOrDefault(JSONObject())
        if (code !in 200..299) {
            error(json.optString("error").ifBlank { json.optString("msg") }.ifBlank { "No se pudo consultar pagos." })
        }
        return json
    }
}

private data class SupplierRow(val id: String, val title: String, val taxNumber: String)

private fun compactRfc(value: String?): String =
    value.orEmpty().uppercase().replace(Regex("[^A-Z0-9&Ñ]"), "")

private fun encode(value: String): String = URLEncoder.encode(value, "UTF-8")

private fun payError(error: Throwable): String {
    val message = error.message?.takeIf { it.isNotBlank() } ?: "No se pudo consultar pagos."
    return if (message.length > 280) message.take(280) + "…" else message
}

private fun accountTitle(json: JSONObject): String =
    json.optString("name").ifBlank { json.optString("legal_name") }.ifBlank { "Proveedor ${json.optString("id")}" }

private fun accountLine(json: JSONObject): String = listOf(
    json.optString("legal_name").ifBlank { json.optString("name") },
    json.optString("tax_number").takeIf { it.isNotBlank() }?.let { "RFC $it" }.orEmpty(),
    json.optString("phone"),
    if (json.optBoolean("international")) "Internacional" else "Nacional",
    json.optString("approval_status").takeIf { it.isNotBlank() }?.let { "Estatus $it" }.orEmpty(),
).filter { it.isNotBlank() }.joinToString(" · ")

private fun accountCards(json: JSONObject): List<Pair<String, String>> = listOf(
    "Saldo" to moneyOrDash(json, "balance"),
    "Saldo pendiente" to moneyOrDash(json, "outstanding_balance"),
    "Saldo real" to moneyOrDash(json, "real_balance"),
    "Pendiente real" to moneyOrDash(json, "real_outstanding_balance"),
    "Días de crédito" to json.opt("credit_days").let { if (it == null || it == JSONObject.NULL) "—" else it.toString() },
    "Crédito" to moneyOrDash(json, "credit_amount"),
)

private fun moneyOrDash(json: JSONObject, key: String): String {
    if (!json.has(key) || json.isNull(key)) return "—"
    return formatMoney(json.get(key).asDouble())
}

private fun JSONArray?.objects(): List<JSONObject> {
    if (this == null) return emptyList()
    return buildList {
        for (index in 0 until length()) {
            optJSONObject(index)?.let { add(it) }
        }
    }
}

private fun JSONArray?.toPayLines(): List<PayLine> = objects().map { item ->
    val currency = item.optString("currency").ifBlank { "MXN" }
    PayLine(
        id = item.optString("id").ifBlank { item.optString("invoice_number") },
        invoice = item.optString("invoice_number").ifBlank { "—" },
        shipment = item.optString("shipment").ifBlank { "—" },
        total = formatMoney(item.opt("total").asDouble(), currency),
        status = payStatusLabel(item.optString("status")),
        paid = payWhen(item.optString("paid_at")),
        folio = item.optString("sp_folio").ifBlank { "—" },
    )
}

private fun payWhen(value: String): String {
    if (value.isBlank()) return "—"
    val date = runCatching { Instant.parse(value) }.getOrNull()
        ?: return value
    return DateTimeFormatter.ofPattern("d MMM yyyy", Locale("es", "MX"))
        .withZone(ZoneId.of("America/Monterrey"))
        .format(date)
}

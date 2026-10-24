package mx.continentecargo.conecta.data

import java.text.NumberFormat
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Currency
import java.util.Date
import java.util.Locale

private val zone: ZoneId = ZoneId.of("America/Monterrey")
private val locale = Locale("es", "MX")
private val dayFormatter: DateTimeFormatter =
    DateTimeFormatter.ofPattern("d MMM yyyy", locale)
private val stampFormatter: DateTimeFormatter =
    DateTimeFormatter.ofPattern("d MMM yyyy, h:mm a", locale)

fun formatDay(date: Date): String =
    dayFormatter.format(date.toInstant().atZone(zone))

fun formatStamp(date: Date): String =
    stampFormatter.format(date.toInstant().atZone(zone))

fun formatMoney(amount: Double, currency: String = "MXN"): String {
    val format = NumberFormat.getCurrencyInstance(locale)
    runCatching { format.currency = Currency.getInstance(currency.ifBlank { "MXN" }) }
    val whole = amount % 1.0 == 0.0
    format.maximumFractionDigits = if (whole) 0 else 2
    format.minimumFractionDigits = if (whole) 0 else 2
    return format.format(amount)
}

fun phoneDigits(raw: String): String {
    val digits = raw.filter { it.isDigit() }
    return if (digits.startsWith("52") && digits.length == 12) digits.drop(2) else digits
}

fun phoneProblem(raw: String): String? {
    val digits = phoneDigits(raw)
    return when {
        digits.isEmpty() -> "Escribe un teléfono."
        digits.length < 10 -> "Se requieren 10 dígitos."
        digits.length > 10 -> "El teléfono tiene dígitos de más."
        else -> null
    }
}

private val emailPattern = Regex("^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$")

fun emailValid(email: String): Boolean = emailPattern.matches(email.trim())

fun mailDomain(email: String): String {
    val trimmed = email.trim().lowercase()
    val at = trimmed.lastIndexOf('@')
    return if (at < 0) "" else trimmed.substring(at + 1).replace(Regex("\\s+"), "")
}

fun domainValid(domain: String): Boolean {
    val value = domain.trim().lowercase()
    return value.length in 3..80 &&
        value.matches(Regex("^[a-z0-9.-]+$")) &&
        value.contains('.') &&
        !value.contains("..")
}

fun vatLabel(includesVat: Boolean): String = if (includesVat) "IVA incluido" else "Más IVA"

fun pickerMillis(date: Date): Long {
    val local = date.toInstant().atZone(zone).toLocalDate()
    return local.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
}

fun dateFromPicker(millis: Long): Date {
    val local = java.time.Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate()
    return Date.from(local.atStartOfDay(zone).toInstant())
}

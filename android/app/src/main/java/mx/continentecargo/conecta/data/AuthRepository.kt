package mx.continentecargo.conecta.data

import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseAuthException
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

class AuthRepository(
    private val auth: FirebaseAuth = FirebaseAuth.getInstance(),
    private val db: FirebaseFirestore = FirebaseFirestore.getInstance(),
) {
    init {
        auth.setLanguageCode("es")
    }

    fun authState(): Flow<String?> = callbackFlow {
        val listener = FirebaseAuth.AuthStateListener { trySend(it.currentUser?.uid) }
        auth.addAuthStateListener(listener)
        awaitClose { auth.removeAuthStateListener(listener) }
    }

    fun currentUid(): String? = auth.currentUser?.uid

    suspend fun signIn(email: String, password: String) {
        auth.signInWithEmailAndPassword(email.trim(), password).await()
    }

    fun signOut() {
        auth.signOut()
    }

    suspend fun sendReset(email: String) {
        auth.sendPasswordResetEmail(email.trim()).await()
    }

    suspend fun loadProfile(uid: String): ProfileRead = try {
        val snap = db.collection("users").document(uid).get().await()
        if (!snap.exists()) {
            ProfileRead.Missing
        } else {
            val profile = parseProfile(uid, snapshotMap(snap.data))
            if (profile == null) ProfileRead.Missing else ProfileRead.Found(profile)
        }
    } catch (error: Exception) {
        ProfileRead.Failed(error)
    }

    suspend fun register(input: RegisterInput): String? {
        val local = validate(input)
        if (local != null) return local
        val email = input.email.trim().lowercase()
        return try {
            val created = auth.createUserWithEmailAndPassword(email, input.password).await()
            val user = created.user ?: return "No se pudo crear la cuenta."
            runCatching { user.sendEmailVerification().await() }
            val domainError = domainIssue(email)
            if (domainError != null) {
                runCatching { user.delete().await() }
                auth.signOut()
                return domainError
            }
            val profileUuid = UUID.randomUUID().toString()
            val companyId = UUID.randomUUID().toString()
            val digits = phoneDigits(input.phone)
            try {
                if (input.states.size > 16) {
                    val token = user.getIdToken(true).await().token
                        ?: error("Sin token de sesión")
                    postProfile(token, input, email, profileUuid, companyId, digits)
                } else {
                    writeProfile(user.uid, input, email, profileUuid, companyId, digits)
                }
            } catch (error: Exception) {
                runCatching { user.delete().await() }
                auth.signOut()
                return writeError(error)
            }
            auth.signOut()
            null
        } catch (error: Exception) {
            authError(error)
        }
    }

    private suspend fun writeProfile(
        authUid: String,
        input: RegisterInput,
        email: String,
        profileUuid: String,
        companyId: String,
        digits: String,
    ) {
        db.collection("users").document(authUid).set(
            userDocument(input, email, profileUuid, companyId, digits),
        ).await()
        runCatching {
            db.collection("companies").document(companyId).set(
                companyDocument(input, email, companyId),
            ).await()
        }
        runCatching { claimDomain(companyId, email) }
        if (digits.length == 10) {
            runCatching {
                db.collection("users_by_phone").document(digits).set(
                    mapOf(
                        "phoneDigits" to digits,
                        "uuid" to profileUuid,
                        "name" to input.name.trim(),
                        "role" to input.role,
                        "status" to "pending_approval",
                    ),
                ).await()
            }
        }
    }

    private fun userDocument(
        input: RegisterInput,
        email: String,
        profileUuid: String,
        companyId: String,
        digits: String,
    ): Map<String, Any> {
        val map = mutableMapOf<String, Any>(
            "uuid" to profileUuid,
            "name" to input.name.trim(),
            "email" to email,
            "phone" to input.phone.trim(),
            "role" to input.role,
            "status" to "pending_approval",
            "companyId" to companyId,
            "canNegotiateRates" to true,
            "handlesLTL" to input.handlesLtl,
            "handlesHazmat" to input.handlesHazmat,
            "handlesLocal" to input.handlesLocal,
            "handlesIntraState" to input.handlesIntraState,
            "createdAt" to Timestamp.now(),
            "routes" to emptyList<Map<String, Any>>(),
            "emailDomain" to mailDomain(email),
        )
        if (input.states.isNotEmpty()) map["coverageStates"] = input.states
        if (input.equipment.isNotEmpty()) map["coverageEquipmentTypes"] = input.equipment
        if (input.coversUsa) map["coversUSA"] = true
        if (input.coversUsa && input.usaStates.isNotEmpty()) map["coverageUSAStates"] = input.usaStates
        if (digits.length == 10) map["phoneDigits"] = digits
        return map
    }

    private fun companyDocument(input: RegisterInput, email: String, companyId: String): Map<String, Any> =
        mapOf(
            "id" to companyId,
            "name" to input.companyName.trim(),
            "contactName" to input.name.trim(),
            "phone" to input.phone.trim(),
            "email" to email,
            "rfc" to input.rfc.trim().uppercase(),
            "status" to "pending_approval",
            "createdAt" to Timestamp.now(),
        )

    private suspend fun claimDomain(companyId: String, email: String) {
        val domain = mailDomain(email)
        if (!domainValid(domain) || domain in Catalog.genericEmailDomains) return
        val ref = db.collection("corporate_email_domains").document(domain)
        if (ref.get().await().exists()) return
        ref.set(
            mapOf(
                "domain" to domain,
                "companyId" to companyId,
                "createdAt" to Timestamp.now(),
            ),
        ).await()
    }

    private suspend fun domainIssue(email: String): String? {
        val domain = mailDomain(email)
        if (!domainValid(domain)) return "Revisa el correo: el dominio no parece válido."
        val blocked = runCatching {
            db.collection("blocked_domains").document(domain).get().await().exists()
        }.getOrDefault(false)
        if (blocked) return "No se puede crear la cuenta: este dominio de correo está bloqueado."
        if (domain !in Catalog.genericEmailDomains) {
            val claimed = runCatching {
                db.collection("corporate_email_domains").document(domain).get().await().exists()
            }.getOrDefault(false)
            if (claimed) {
                return "Ya hay una empresa registrada con este dominio de correo corporativo. Si ya tienes cuenta, inicia sesión o pide ayuda a tu pricer."
            }
        }
        return null
    }

    private fun postProfile(
        token: String,
        input: RegisterInput,
        email: String,
        profileUuid: String,
        companyId: String,
        digits: String,
    ) {
        val profile = JSONObject()
            .put("uuid", profileUuid)
            .put("name", input.name.trim())
            .put("email", email)
            .put("phone", input.phone.trim())
            .put("role", input.role)
            .put("status", "pending_approval")
            .put("companyId", companyId)
            .put("canNegotiateRates", true)
            .put("handlesLTL", input.handlesLtl)
            .put("handlesHazmat", input.handlesHazmat)
            .put("handlesLocal", input.handlesLocal)
            .put("handlesIntraState", input.handlesIntraState)
            .put("routes", JSONArray())
            .put("emailDomain", mailDomain(email))
            .put("coverageStates", JSONArray(input.states))
            .put("coverageEquipmentTypes", JSONArray(input.equipment))
        if (input.coversUsa) profile.put("coversUSA", true)
        if (input.coversUsa && input.usaStates.isNotEmpty()) {
            profile.put("coverageUSAStates", JSONArray(input.usaStates))
        }
        if (digits.length == 10) profile.put("phoneDigits", digits)
        val company = JSONObject()
            .put("id", companyId)
            .put("name", input.companyName.trim())
            .put("contactName", input.name.trim())
            .put("phone", input.phone.trim())
            .put("email", email)
            .put("rfc", input.rfc.trim().uppercase())
        profile.put("company", company)
        val body = JSONObject().put("data", profile).toString()
        val connection = (URL(FirebaseBackend.createProfileUrl).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 20000
            readTimeout = 20000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Authorization", "Bearer $token")
        }
        connection.outputStream.use { it.write(body.toByteArray()) }
        val code = connection.responseCode
        if (code !in 200..299) {
            val text = (connection.errorStream ?: connection.inputStream)?.bufferedReader()?.use { it.readText() }.orEmpty()
            error(text.ifBlank { "HTTP $code" })
        }
    }

    private fun validate(input: RegisterInput): String? {
        if (input.name.trim().length !in 2..80) return "Escribe tu nombre."
        if (input.companyName.trim().length !in 2..80) return "Escribe el nombre de la empresa."
        phoneProblem(input.phone)?.let { return it }
        if (!emailValid(input.email)) return "El correo no es válido."
        if (input.password.length < 6) return "La contraseña debe tener al menos 6 caracteres."
        if (input.role !in Catalog.carrierRoles) return "Elige el tipo de cuenta."
        if (input.equipment.isEmpty()) return "Elige al menos un tipo de equipo."
        if (input.states.isEmpty() && !(input.coversUsa && input.usaStates.isNotEmpty())) {
            return "Elige al menos un estado de cobertura."
        }
        val rfc = input.rfc.trim().uppercase()
        if (rfc.isNotEmpty() && !rfc.matches(Regex("^[A-Z&Ñ]{3,4}[0-9]{6}[A-Z0-9]{3}$"))) {
            return "El RFC no tiene el formato correcto."
        }
        return null
    }

    private fun writeError(error: Exception): String {
        val text = error.message.orEmpty()
        return if (text.contains("permission", true) || text.contains("denied", true)) {
            "No se pudo guardar el registro. Intenta de nuevo."
        } else {
            "No se pudo guardar el registro. Intenta de nuevo."
        }
    }
}

fun authError(error: Exception): String {
    val code = (error as? FirebaseAuthException)?.errorCode.orEmpty()
    val message = error.message.orEmpty()
    return when {
        code.contains("EMAIL_ALREADY_IN_USE") || message.contains("email-already-in-use") ->
            "Ese correo ya está registrado"
        code.contains("WEAK_PASSWORD") || message.contains("weak-password") ->
            "La contraseña debe tener al menos 6 caracteres"
        code.contains("INVALID_EMAIL") || message.contains("invalid-email") ->
            "El correo no es válido"
        code.contains("WRONG_PASSWORD") ||
            code.contains("INVALID_CREDENTIAL") ||
            code.contains("USER_NOT_FOUND") ||
            code.contains("USER_DISABLED") ||
            message.contains("INVALID_LOGIN_CREDENTIALS") ||
            message.contains("invalid-credential") ||
            message.contains("wrong-password") ->
            "Correo o contraseña incorrectos"
        message.contains("network", true) || message.contains("timeout", true) ->
            "Sin conexión. Revisa tu internet e inténtalo de nuevo."
        else -> "Ocurrió un error. Intenta de nuevo."
    }
}

package mx.continentecargo.conecta.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import mx.continentecargo.conecta.data.AuthRepository
import mx.continentecargo.conecta.data.CarrierProfile
import mx.continentecargo.conecta.data.CarrierRepository
import mx.continentecargo.conecta.data.FleetUnit
import mx.continentecargo.conecta.data.FreightLoad
import mx.continentecargo.conecta.data.FreightOffer
import mx.continentecargo.conecta.data.Gate
import mx.continentecargo.conecta.data.Notice
import mx.continentecargo.conecta.data.ProfileRead
import mx.continentecargo.conecta.data.RegisterInput
import mx.continentecargo.conecta.data.RouteCoverage
import mx.continentecargo.conecta.data.actionMessage
import mx.continentecargo.conecta.data.authError
import mx.continentecargo.conecta.data.formatMoney
import mx.continentecargo.conecta.data.gate
import mx.continentecargo.conecta.data.needsCounterOffer
import java.util.Date

data class ConectaUi(
    val booting: Boolean = true,
    val profile: CarrierProfile? = null,
    val banner: String? = null,
    val loads: List<FreightLoad> = emptyList(),
    val offers: List<FreightOffer> = emptyList(),
    val units: List<FleetUnit> = emptyList(),
    val notices: List<Notice> = emptyList(),
    val passedRoutes: Set<String> = emptySet(),
    val passedLoadIds: Set<String> = emptySet(),
    val dataError: String? = null,
    val busy: Boolean = false,
    val toast: String? = null,
    val registered: Boolean = false,
)

class ConectaViewModel(
    private val auth: AuthRepository = AuthRepository(),
    private val data: CarrierRepository = CarrierRepository(),
) : ViewModel() {
    private val _ui = MutableStateFlow(ConectaUi())
    val ui = _ui.asStateFlow()

    private var acceptAuth = true
    private var pendingBanner: String? = null
    private var listeningUid: String? = null

    init {
        viewModelScope.launch {
            auth.authState().collect { uid ->
                if (!acceptAuth) return@collect
                if (uid == null) {
                    data.stop()
                    listeningUid = null
                    val banner = pendingBanner
                    pendingBanner = null
                    _ui.update {
                        ConectaUi(
                            booting = false,
                            banner = banner,
                            registered = it.registered && banner != null,
                        )
                    }
                } else {
                    admit(uid)
                }
            }
        }
    }

    fun clearToast() = _ui.update { it.copy(toast = null) }

    fun clearBanner() = _ui.update { it.copy(banner = null, registered = false) }

    fun retry() {
        val uid = auth.currentUid() ?: return
        viewModelScope.launch { admit(uid) }
    }

    fun login(email: String, password: String) {
        viewModelScope.launch {
            _ui.update { it.copy(busy = true, banner = null, registered = false) }
            try {
                auth.signIn(email, password)
            } catch (error: Exception) {
                _ui.update { it.copy(banner = authError(error)) }
            } finally {
                _ui.update { it.copy(busy = false) }
            }
        }
    }

    fun sendReset(email: String) {
        viewModelScope.launch {
            _ui.update { it.copy(busy = true) }
            try {
                auth.sendReset(email)
                _ui.update { it.copy(toast = "Te enviamos un correo para restablecer la contraseña.") }
            } catch (error: Exception) {
                _ui.update { it.copy(banner = authError(error)) }
            } finally {
                _ui.update { it.copy(busy = false) }
            }
        }
    }

    fun register(input: RegisterInput) {
        viewModelScope.launch {
            acceptAuth = false
            _ui.update { it.copy(busy = true, banner = null, registered = false) }
            val error = try {
                auth.register(input)
            } finally {
                acceptAuth = true
            }
            if (error == null) {
                pendingBanner = "Registro enviado. Tu cuenta queda pendiente de aprobación. Te avisaremos cuando Continente Cargo la revise."
                _ui.update {
                    it.copy(
                        busy = false,
                        booting = false,
                        profile = null,
                        banner = pendingBanner,
                        registered = true,
                    )
                }
                pendingBanner = null
            } else {
                _ui.update { it.copy(busy = false, banner = error, registered = false) }
            }
        }
    }

    fun logout() {
        data.stop()
        listeningUid = null
        auth.signOut()
    }

    fun confirmFixed(load: FreightLoad, unitId: String?, phone: String, eta: Date, tracking: String, units: Int, price: Double) {
        val profile = _ui.value.profile ?: return
        viewModelScope.launch {
            _ui.update { it.copy(busy = true) }
            try {
                val operatorId = phone.takeIf { it.isNotBlank() }?.let { data.lookupOperator(it) }
                val code = if (needsCounterOffer(load, price)) {
                    data.submitCounter(profile, load, unitId, operatorId, tracking.trim(), units, price)
                } else {
                    data.takeLoad(profile, load, unitId, operatorId, eta, tracking.trim(), units, price)
                }
                _ui.update { it.copy(toast = actionMessage(code)) }
            } catch (error: Exception) {
                _ui.update { it.copy(toast = error.message ?: "No se pudo confirmar la carga.") }
            } finally {
                _ui.update { it.copy(busy = false) }
            }
        }
    }

    fun placeBid(load: FreightLoad, amount: Double, unitId: String?, units: Int) {
        val profile = _ui.value.profile ?: return
        viewModelScope.launch {
            _ui.update { it.copy(busy = true) }
            try {
                val code = data.placeBid(profile, load, _ui.value.offers, amount, unitId, units)
                val label = formatMoney(load.minBidDecrement, load.currency)
                _ui.update {
                    it.copy(toast = if (code == "success") "Oferta enviada" else actionMessage(code, label))
                }
            } catch (error: Exception) {
                _ui.update { it.copy(toast = error.message ?: "No se pudo enviar la oferta.") }
            } finally {
                _ui.update { it.copy(busy = false) }
            }
        }
    }

    fun indicate(load: FreightLoad, unitId: String?, custom: Double?) {
        val profile = _ui.value.profile ?: return
        viewModelScope.launch {
            _ui.update { it.copy(busy = true) }
            try {
                data.indicateAvailability(profile, load, unitId, custom)
                _ui.update { it.copy(toast = "Disponibilidad enviada") }
            } catch (error: Exception) {
                _ui.update { it.copy(toast = error.message ?: "No se pudo registrar la disponibilidad.") }
            } finally {
                _ui.update { it.copy(busy = false) }
            }
        }
    }

    fun quoteLtl(load: FreightLoad, amount: Double, notes: String) {
        val profile = _ui.value.profile ?: return
        viewModelScope.launch {
            _ui.update { it.copy(busy = true) }
            try {
                val ok = data.submitLtl(profile, load, amount, notes)
                _ui.update {
                    it.copy(toast = if (ok) "Cotización enviada" else "No se pudo enviar la cotización.")
                }
            } catch (error: Exception) {
                _ui.update { it.copy(toast = error.message ?: "No se pudo enviar la cotización.") }
            } finally {
                _ui.update { it.copy(busy = false) }
            }
        }
    }

    fun improveOffer(offer: FreightOffer, price: Double, units: Int) {
        viewModelScope.launch {
            _ui.update { it.copy(busy = true) }
            try {
                data.updateOffer(offer, price, units)
                _ui.update { it.copy(toast = "Oferta actualizada") }
            } catch (error: Exception) {
                _ui.update { it.copy(toast = error.message ?: "No se pudo actualizar la oferta.") }
            } finally {
                _ui.update { it.copy(busy = false) }
            }
        }
    }

    fun answerCounter(offer: FreightOffer, decision: String) {
        val profile = _ui.value.profile ?: return
        viewModelScope.launch {
            try {
                data.answerCounter(profile, offer, decision)
                _ui.update {
                    it.copy(toast = if (decision == "Aceptada") "Aceptaste la contra propuesta." else "Rechazaste la contra propuesta.")
                }
            } catch (error: Exception) {
                _ui.update { it.copy(toast = error.message ?: "No se pudo responder la contra propuesta.") }
            }
        }
    }

    fun advanceTrip(load: FreightLoad, status: String) {
        val profile = _ui.value.profile ?: return
        viewModelScope.launch {
            _ui.update { it.copy(busy = true) }
            try {
                data.updateTripStatus(profile, load, status)
                _ui.update { it.copy(toast = "El viaje ahora está: $status") }
            } catch (error: Exception) {
                _ui.update { it.copy(toast = error.message ?: "No se pudo actualizar el estatus.") }
            } finally {
                _ui.update { it.copy(busy = false) }
            }
        }
    }

    fun saveUnit(unit: FleetUnit, isNew: Boolean) {
        viewModelScope.launch {
            _ui.update { it.copy(busy = true) }
            try {
                data.saveUnit(unit)
                _ui.update { it.copy(toast = if (isNew) "Unidad agregada" else "Unidad actualizada") }
            } catch (error: Exception) {
                _ui.update { it.copy(toast = error.message ?: "No se pudo guardar la unidad.") }
            } finally {
                _ui.update { it.copy(busy = false) }
            }
        }
    }

    fun deleteUnit(id: String) {
        viewModelScope.launch {
            try {
                data.deleteUnit(id)
                _ui.update { it.copy(toast = "Unidad eliminada") }
            } catch (error: Exception) {
                _ui.update { it.copy(toast = error.message ?: "No se pudo eliminar la unidad.") }
            }
        }
    }

    fun setUnitStatus(id: String, status: String) {
        viewModelScope.launch {
            try {
                data.setUnitStatus(id, status)
            } catch (error: Exception) {
                _ui.update { it.copy(toast = error.message ?: "No se pudo cambiar el estado.") }
            }
        }
    }

    fun saveProfile(name: String, phone: String) {
        val profile = _ui.value.profile ?: return
        viewModelScope.launch {
            _ui.update { it.copy(busy = true) }
            try {
                data.updateProfile(profile, name, phone)
                _ui.update { it.copy(toast = "Perfil guardado") }
            } catch (error: Exception) {
                _ui.update { it.copy(toast = error.message ?: "No se pudo guardar el perfil.") }
            } finally {
                _ui.update { it.copy(busy = false) }
            }
        }
    }

    fun setLtl(value: Boolean) = setFlag("handlesLTL", value)
    fun setHazmat(value: Boolean) = setFlag("handlesHazmat", value)

    fun saveRoutes(routes: List<RouteCoverage>) {
        val profile = _ui.value.profile ?: return
        viewModelScope.launch {
            _ui.update { it.copy(busy = true) }
            try {
                data.saveRoutes(profile, routes)
                _ui.update { it.copy(toast = "Rutas guardadas") }
            } catch (error: Exception) {
                _ui.update { it.copy(toast = error.message ?: "No se pudieron guardar las rutas.") }
            } finally {
                _ui.update { it.copy(busy = false) }
            }
        }
    }

    fun openNotice(notice: Notice) {
        if (!notice.isRead) {
            viewModelScope.launch { runCatching { data.markRead(notice.id) } }
        }
    }

    fun markAllRead() {
        val notices = _ui.value.notices
        viewModelScope.launch { data.markAllRead(notices) }
    }

    private fun setFlag(field: String, value: Boolean) {
        val profile = _ui.value.profile ?: return
        viewModelScope.launch {
            try {
                data.setFlag(profile, field, value)
            } catch (error: Exception) {
                _ui.update { it.copy(toast = error.message ?: "No se pudo guardar.") }
            }
        }
    }

    private suspend fun admit(uid: String) {
        when (val read = auth.loadProfile(uid)) {
            is ProfileRead.Failed -> _ui.update {
                it.copy(
                    booting = false,
                    banner = "No se pudo conectar. Revisa tu internet e inténtalo de nuevo.",
                )
            }
            is ProfileRead.Missing -> deny(uid, gate(null))
            is ProfileRead.Found -> when (val decision = gate(read.profile)) {
                Gate.Allow -> {
                    if (listeningUid != uid) {
                        listeningUid = uid
                        data.listen(
                            profile = read.profile,
                            onLoads = { loads -> _ui.update { it.copy(loads = loads, dataError = null) } },
                            onOffers = { offers -> _ui.update { it.copy(offers = offers) } },
                            onUnits = { units -> _ui.update { it.copy(units = units) } },
                            onNotices = { notices -> _ui.update { it.copy(notices = notices) } },
                            onPasses = { routes, ids ->
                                _ui.update { it.copy(passedRoutes = routes, passedLoadIds = ids) }
                            },
                            onProfile = { profile -> onProfile(profile) },
                            onError = { message -> _ui.update { it.copy(dataError = message) } },
                        )
                    }
                    _ui.update { it.copy(booting = false, profile = read.profile, banner = null, registered = false) }
                }
                is Gate.Deny -> deny(uid, decision)
            }
        }
    }

    private fun onProfile(profile: CarrierProfile?) {
        when (val decision = gate(profile)) {
            Gate.Allow -> _ui.update { it.copy(profile = profile) }
            is Gate.Deny -> {
                pendingBanner = decision.message
                logout()
            }
        }
    }

    private fun deny(uid: String, decision: Gate) {
        val message = (decision as? Gate.Deny)?.message ?: "No se pudo entrar."
        pendingBanner = message
        data.stop()
        listeningUid = null
        if (auth.currentUid() == uid) auth.signOut()
        _ui.update { ConectaUi(booting = false, banner = message) }
    }

    override fun onCleared() {
        data.stop()
        super.onCleared()
    }
}

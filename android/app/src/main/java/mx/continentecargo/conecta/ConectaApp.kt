package mx.continentecargo.conecta

import android.app.Application
import android.content.Context
import android.content.res.Configuration
import mx.continentecargo.conecta.data.FirebaseBackend
import java.util.Locale

class ConectaApp : Application() {
    override fun attachBaseContext(base: Context) {
        val locale = Locale("es", "MX")
        Locale.setDefault(locale)
        val config = Configuration(base.resources.configuration)
        config.setLocale(locale)
        super.attachBaseContext(base.createConfigurationContext(config))
    }

    override fun onCreate() {
        super.onCreate()
        FirebaseBackend.install(this)
    }
}

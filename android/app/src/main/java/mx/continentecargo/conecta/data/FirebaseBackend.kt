package mx.continentecargo.conecta.data

import android.app.Application
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions

/**
 * Public web config from https://continente-conecta.web.app
 * (project continente-conecta). This is the client API key already shipped
 * in the web bundle, not a service account.
 */
object FirebaseBackend {
    const val apiKey = "AIzaSyD7Se9v2g2QIWGmXxp6ebM_xs1Xy-tk6Jk"
    const val projectId = "continente-conecta"
    const val appId = "1:78623337597:web:d5de2b0bb04eb65c5dd514"
    const val storageBucket = "continente-conecta.firebasestorage.app"
    const val senderId = "78623337597"
    const val authDomain = "continente-conecta.firebaseapp.com"
    const val createProfileUrl =
        "https://us-central1-continente-conecta.cloudfunctions.net/createUserProfile"

    fun install(app: Application) {
        if (FirebaseApp.getApps(app).isNotEmpty()) return
        val options = FirebaseOptions.Builder()
            .setApiKey(apiKey)
            .setApplicationId(appId)
            .setProjectId(projectId)
            .setStorageBucket(storageBucket)
            .setGcmSenderId(senderId)
            .build()
        FirebaseApp.initializeApp(app, options)
    }
}

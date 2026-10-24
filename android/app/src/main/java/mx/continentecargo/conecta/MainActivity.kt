package mx.continentecargo.conecta

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import mx.continentecargo.conecta.ui.ConectaRoot
import mx.continentecargo.conecta.ui.ConectaViewModel
import mx.continentecargo.conecta.ui.theme.ConectaTheme

class MainActivity : ComponentActivity() {
    private val viewModel: ConectaViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            ConectaTheme {
                ConectaRoot(viewModel)
            }
        }
    }
}

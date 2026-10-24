package mx.continentecargo.conecta.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import mx.continentecargo.conecta.R

val NavyDeep = Color(0xFF011E39)
val Navy = Color(0xFF022F56)
val Brand = Color(0xFF0057B8)
val BrandSoft = Color(0xFFEBF3FE)
val Canvas = Color(0xFFF6F8FC)
val Ink = Color(0xFF10243A)
val Muted = Color(0xFF62738A)
val Line = Color(0xFFE6EBF3)
val Danger = Color(0xFFD62929)
val Success = Color(0xFF048A60)
val SuccessSoft = Color(0xFFE8FAF1)
val Amber = Color(0xFFDE680E)
val AmberSoft = Color(0xFFFEF3E9)

val DmSans = FontFamily(
    Font(R.font.dm_sans_400, FontWeight.Normal),
    Font(R.font.dm_sans_500, FontWeight.Medium),
    Font(R.font.dm_sans_600, FontWeight.SemiBold),
    Font(R.font.dm_sans_700, FontWeight.Bold),
)

private val Colors = lightColorScheme(
    primary = Brand,
    onPrimary = Color.White,
    secondary = NavyDeep,
    onSecondary = Color.White,
    background = Canvas,
    onBackground = Ink,
    surface = Color.White,
    onSurface = Ink,
    surfaceVariant = Canvas,
    onSurfaceVariant = Muted,
    error = Danger,
    outline = Line,
)

private val Type = Typography(
    headlineMedium = TextStyle(fontFamily = DmSans, fontWeight = FontWeight.Bold, fontSize = 28.sp, color = Ink),
    titleLarge = TextStyle(fontFamily = DmSans, fontWeight = FontWeight.SemiBold, fontSize = 20.sp, color = Ink),
    titleMedium = TextStyle(fontFamily = DmSans, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, color = Ink),
    bodyLarge = TextStyle(fontFamily = DmSans, fontWeight = FontWeight.Normal, fontSize = 16.sp, color = Ink),
    bodyMedium = TextStyle(fontFamily = DmSans, fontWeight = FontWeight.Normal, fontSize = 14.sp, color = Ink),
    bodySmall = TextStyle(fontFamily = DmSans, fontWeight = FontWeight.Medium, fontSize = 12.sp, color = Muted),
    labelLarge = TextStyle(fontFamily = DmSans, fontWeight = FontWeight.SemiBold, fontSize = 15.sp),
)

@Composable
fun ConectaTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = Colors, typography = Type, content = content)
}

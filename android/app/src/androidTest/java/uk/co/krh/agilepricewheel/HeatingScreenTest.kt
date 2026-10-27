package uk.co.krh.agilepricewheel

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.darkColorScheme
import androidx.compose.ui.test.*
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.time.Instant

@RunWith(AndroidJUnit4::class)
class HeatingScreenTest {
    @get:Rule val compose = createComposeRule()
    private fun state(): HeatingUiState {
        val now = Instant.now()
        val start = Instant.ofEpochSecond(now.epochSecond / 1800 * 1800)
        val status = JSONObject().put("mode", "automatic").put("control_enabled", true).put("stale", false)
            .put("price_requests_heat", true).put("current", JSONObject().put("start", start.toString())
                .put("end", start.plusSeconds(1800).toString()).put("effective_price_p", -5).put("agile_price_p", -5))
            .put("heating_control", JSONObject().put("phase", "boost_active").put("last_checked_at", now.toString())
                .put("observation", JSONObject().put("reported_heating_on", false)))
        return HeatingUiState(message = "Controller policy loaded.", keyConfigured = true, fetchedAt = now, needsReload = false, onPrice = -5.0, offPrice = -1.0,
            policy = JSONObject("""{"revision":11,"policy":{"on_price_p":-5,"off_price_p":-1,"load_kw":3,"array_kwp":5,"tariff":"E-1R-EXAMPLE-G"}}"""),
            status = status, automation = JSONObject("""{"enabled":false,"can_enable":true,"shutdown_pending":false}"""))
    }
    private fun show(s: HeatingUiState, automation: (Boolean) -> Unit = {}, prices: (Double, Double) -> Unit = { _, _ -> }) {
        compose.setContent { MaterialTheme(colorScheme = darkColorScheme()) {
            Surface { HeatingPanel(s, AppSettings(), {}, {}, automation, prices, {}, {}) }
        } }
    }
    @Test fun policyAndPhysicalStateAreSeparateAndVisible() {
        show(state())
        compose.onNodeWithTag("heating-policy").assertTextEquals("Heating policy: ON").assertIsDisplayed()
        compose.onNodeWithTag("heating-state").assertTextEquals("Heating state: OFF").assertIsDisplayed()
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val image = compose.onRoot().captureToImage().asAndroidBitmap()
        File(context.filesDir, "heating-screen.png").outputStream().use { image.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
        compose.onNodeWithText("Test connection / reload controller policy").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Weekly heating log").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Target temp", substring = true).assertDoesNotExist()
    }
    @Test fun failedConnectionShowsUnknownNotOff() {
        show(state().copy(status = null, fetchedAt = null, needsReload = true))
        compose.onNodeWithTag("heating-policy").assertTextEquals("Heating policy: UNKNOWN")
        compose.onNodeWithTag("heating-state").assertTextEquals("Heating state: UNKNOWN")
    }
    @Test fun enablingRequiresConfirmationAndCancelDoesNotWrite() {
        var writes = 0
        show(state(), automation = { writes++ })
        compose.onNodeWithTag("automation-switch").performScrollTo().performClick()
        compose.onNodeWithText("Enable automation?").assertIsDisplayed()
        assertEquals(0, writes)
        compose.onNodeWithText("Cancel").performClick(); assertEquals(0, writes)
        compose.onNodeWithTag("automation-switch").performClick()
        compose.onNodeWithText("Enable", useUnmergedTree = true).performClick()
        compose.runOnIdle { assertEquals(1, writes) }
    }
    @Test fun negativePolicyChoiceIsSelectable() {
        var on = 0.0
        show(state(), prices = { value, _ -> on = value })
        compose.onNodeWithTag("Heating on").performScrollTo().performClick()
        compose.onNodeWithText("-20.00 p/kWh").performScrollTo().performClick()
        compose.runOnIdle { assertEquals(-20.0, on, 0.0) }
    }
    @Test fun weeklyHistoryShowsPairedSessionAndEstimatedPayment() {
        val history = JSONObject("""{"week_start":"2026-10-19","week_end":"2026-10-26","current_week":"2026-10-26","oldest_week":"2025-10-27","retention_days":366,"events":[],"sessions":[{"id":"session","on_at":"2026-10-25T00:30:00Z","off_at":"2026-10-25T01:00:00Z","duration_seconds":1800,"estimated_cost_gbp":-0.075,"estimated_energy_kwh":1.5,"cost_status":"estimated","intervals":[]}]}""")
        compose.setContent { MaterialTheme(colorScheme = darkColorScheme()) { Surface { HeatingHistoryPanel(state().copy(history = history), null, {}, {}) } } }
        compose.onNodeWithText("Estimated payment: £0.0750").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Duration: 0h 30m 0s").assertExists()
        compose.onNodeWithText("ON Sun 25 Oct, 01:30:00 BST").assertExists()
        compose.onNodeWithText("OFF Sun 25 Oct, 01:00:00 GMT").assertExists()
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val image = compose.onRoot().captureToImage().asAndroidBitmap()
        File(context.filesDir, "heating-history.png").outputStream().use { image.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
    }
    @Test fun appNavigationReachesHeatingAndConnectionSettings() {
        compose.setContent { MaterialTheme(colorScheme = darkColorScheme()) { AgilePriceWheelApp() } }
        compose.onNode(hasText("Heating") and hasClickAction()).performScrollTo().performClick()
        compose.onNodeWithText("Agile heating").assertIsDisplayed()
        compose.onNodeWithTag("heating-policy").assertTextEquals("Heating policy: UNKNOWN")
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val image = compose.onRoot().captureToImage().asAndroidBitmap()
        File(context.filesDir, "heating-app.png").outputStream().use { image.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
        compose.onNode(hasText("Settings") and hasClickAction()).performScrollTo().performClick()
        compose.onNodeWithText("Controller HTTPS address").performScrollTo().assertIsDisplayed()
        compose.onNodeWithText("Save connection").performScrollTo().assertIsDisplayed()
        compose.onNode(isToggleable()).performScrollTo().performClick()
        compose.onNode(hasText("PV") and hasClickAction()).assertDoesNotExist()
        compose.onNode(hasText("Heating") and hasClickAction()).performScrollTo().performClick()
        compose.onNodeWithText("Agile heating").assertIsDisplayed()
    }
    @Test fun credentialStorageIsEncryptedBoundToAddressAndSurvivesNewInstance() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val path = File(context.noBackupFilesDir, "heating-connection.json")
        // Fresh emulator only; never replace an existing user's configured connection.
        assertFalse("Test requires an unconfigured emulator", path.exists())
        val token = "offline-fixture-secret-which-must-not-be-in-the-file"
        try {
            KeystoreHeatingConnectionStore(context).save(HeatingConnection("https://controller.example:8451", token))
            val raw = path.readText(); assertFalse(raw.contains(token))
            assertEquals(token, KeystoreHeatingConnectionStore(context).load()!!.token)
            path.writeText(raw.replace("controller.example", "different.example"))
            assertThrows(Exception::class.java) { KeystoreHeatingConnectionStore(context).load() }
        } finally { path.delete() }
    }
}

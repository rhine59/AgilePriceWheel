package uk.co.krh.agilepricewheel

import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.runTest
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import java.net.URI
import java.time.Instant

private val fixedNow = Instant.parse("2026-10-25T01:00:10Z")
private fun policyFixture() = JSONObject("""{"revision":11,"policy":{"on_price_p":-5,"off_price_p":-1,"target_c":20,"limit_c":22,"product":"AGILE-24-10-01","tariff":"E-1R-AGILE-24-10-01-G","latitude":54,"longitude":-2,"array_kwp":5,"loss_percent":14,"inverter_kw":5,"load_kw":3}}""")
private fun statusFixture() = JSONObject("""{"revision":11,"control_enabled":true,"mode":"automatic","stale":false,"price_requests_heat":true,"current":{"start":"2026-10-25T01:00:00Z","end":"2026-10-25T01:30:00Z","effective_price_p":-5,"agile_price_p":-5},"heating_control":{"phase":"boost_active","last_checked_at":"2026-10-25T01:00:05Z","error":null,"observation":{"reported_heating_on":false}}}""")
private fun automationFixture() = JSONObject("""{"revision":3,"enabled":true,"can_enable":true,"shutdown_pending":false,"phase":"boost_active","error":null}""")
private fun historyFixture() = JSONObject("""{"week_start":"2026-10-19","week_end":"2026-10-26","current_week":"2026-10-26","oldest_week":"2025-10-27","timezone":"Europe/London","events":[],"sessions":[{"id":"cross-week","on_at":"2026-10-25T23:45:00Z","off_at":"2026-10-26T00:15:00Z","duration_seconds":1800,"estimated_cost_gbp":-0.075,"estimated_energy_kwh":1.5,"cost_status":"estimated","intervals":[{"start":"2026-10-25T23:30:00Z","end":"2026-10-26T00:00:00Z","agile_price_p":-5,"effective_price_p":-5,"load_kw":3}]}]}""")
private class MemoryConnectionStore : HeatingConnectionStore {
    var saved: HeatingConnection? = HeatingConnection("https://controller.example:8451", "fixture-key")
    override fun load() = saved
    override fun save(connection: HeatingConnection) { saved = connection }
}
private class FixtureTransport : HeatingTransport {
    val calls = mutableListOf<Pair<String, JSONObject?>>()
    var policy = policyFixture(); var status = statusFixture(); var automation = automationFixture()
    var failWrites = false; var failStatus = false; var failHistory = false
    override fun exchange(origin: URI, token: String, path: String, body: JSONObject?): JSONObject {
        assertEquals("https", origin.scheme); assertEquals("fixture-key", token)
        calls += path to body
        if (body != null && failWrites) throw HeatingFailure("Save outcome is unconfirmed. Reload before retrying.", true)
        if (path == "/v1/status" && failStatus) throw HeatingFailure("Could not contact controller.")
        val result = when {
            path == "/v1/policy" && body != null -> { policy = JSONObject(body.toString()).put("revision", policy.getLong("revision") + 1); status.put("revision", policy.getLong("revision")); policy }
            path == "/v1/automation" && body != null -> { automation.put("enabled", body.getBoolean("enabled")); automation }
            path == "/v1/policy" -> policy
            path == "/v1/status" -> status
            path == "/v1/automation" -> automation
            path.startsWith("/v1/history") -> { if (failHistory) throw HeatingFailure("History unavailable"); historyFixture() }
            else -> error("Unexpected request")
        }
        return JSONObject(result.toString())
    }
}

class HeatingControllerTest {
    @Test fun httpsOriginRejectsInsecureAndCredentialBearingAddresses() {
        for (address in listOf("http://controller.example", "https://u:p@controller.example", "https://controller.example/path", "https://controller.example?key=x", "https://controller.example#x", "https://controller.example:0", "https://controller.example:65536")) {
            assertThrows(HeatingFailure::class.java) { heatingOrigin(address) }
        }
        assertEquals("https://controller.example:8451", heatingOrigin(" https://CONTROLLER.example:8451/ ").toString())
    }
    @Test fun negativePriceDraftPreservesEveryOtherFieldAndRevision() {
        val before = policyFixture(); val draft = heatingPriceDraft(before, -20.0, 0.0)
        assertEquals(-20.0, draft.getJSONObject("policy").getDouble("on_price_p"), 0.0)
        assertEquals(-5.0, before.getJSONObject("policy").getDouble("on_price_p"), 0.0)
        for (key in before.getJSONObject("policy").keys()) if (key !in listOf("on_price_p", "off_price_p"))
            assertEquals(before.getJSONObject("policy").get(key), draft.getJSONObject("policy").get(key))
        assertEquals(11, draft.getInt("revision"))
        assertThrows(HeatingFailure::class.java) { heatingPriceDraft(before, 1.0, -1.0) }
        assertThrows(HeatingFailure::class.java) { heatingPriceDraft(before, Double.NaN, 0.0) }
    }
    @Test fun allSixServicesUseExactMethodsAndSignedValues() {
        val t = FixtureTransport(); val api = HeatingApi("https://controller.example:8451", "fixture-key", t)
        api.status(); api.policy(); api.automation(); api.history("2026-10-19")
        api.savePolicy(heatingPriceDraft(policyFixture(), -20.0, -10.0)); api.setAutomation(false)
        assertEquals(listOf("/v1/status", "/v1/policy", "/v1/automation", "/v1/history?week=2026-10-19", "/v1/policy", "/v1/automation"), t.calls.map { it.first })
        assertTrue(t.calls.take(4).all { it.second == null }); assertEquals(false, t.calls.last().second!!.getBoolean("enabled"))
    }
    @Test fun malformedHistoryCannotInventAnOffActionOrCrashWeekNavigation() {
        for (bad in listOf(historyFixture().put("week_end", "bad"), historyFixture().put("events", org.json.JSONArray().put(JSONObject().put("state", "interval"))))) {
            val api = HeatingApi("https://controller.example", "fixture-key", HeatingTransport { _, _, _, _ -> bad })
            assertThrows(Exception::class.java) { api.history() }
        }
    }
    @Test fun dstFoldDisplaysDistinctBstAndGmtAndLondonMonday() {
        assertTrue(HeatingDates.time("2026-10-25T00:30:00Z").endsWith("BST"))
        assertTrue(HeatingDates.time("2026-10-25T01:30:00Z").endsWith("GMT"))
        assertEquals("2026-10-19", HeatingDates.monday(Instant.parse("2026-10-25T23:59:59Z")).toString())
        assertEquals("2026-10-26", HeatingDates.monday(Instant.parse("2026-10-26T00:00:00Z")).toString())
        assertEquals("2026-03-30", HeatingDates.monday(Instant.parse("2026-03-29T23:15:00Z")).toString())
        assertThrows(IllegalArgumentException::class.java) { HeatingDates.week("2026-10-25") }
    }
    @Test fun staleOrMissingPricesNeverBecomeGreenPolicyOff() {
        val s = statusFixture()
        assertEquals(true, heatingPolicyState(s, fixedNow, fixedNow))
        assertEquals(false, heatingReportedState(s, fixedNow, fixedNow))
        assertNull(heatingPolicyState(s, fixedNow.minusSeconds(46), fixedNow))
        s.put("stale", true); assertNull(heatingPolicyState(s, fixedNow, fixedNow))
        s.put("stale", false).put("current", JSONObject.NULL); assertNull(heatingPolicyState(s, fixedNow, fixedNow))
        assertNull(heatingReportedState(s, fixedNow, fixedNow.plusSeconds(46)))
        assertNull(heatingPolicyState(statusFixture(), Instant.parse("2026-10-25T01:29:50Z"), Instant.parse("2026-10-25T01:30:00Z")))
    }
    @Test fun historyUsesServerSessionEstimatesWithoutRecomputingOrZeroFilling() {
        val session = historyFixture().rows("sessions").single()
        assertEquals("Estimated payment: £0.0750", heatingSessionCost(session))
        assertEquals(1800.0, session.numberOrNull("duration_seconds")!!, 0.0)
        session.put("estimated_cost_gbp", JSONObject.NULL)
        assertTrue(heatingSessionCost(session).contains("missing rate/load"))
        session.put("off_at", JSONObject.NULL); assertTrue(heatingSessionCost(session).contains("end unconfirmed"))
        val sameSessionInNextWeek = historyFixture().put("week_start", "2026-10-26").rows("sessions").single()
        assertEquals(session.getString("id"), sameSessionInNextWeek.getString("id"))
        assertEquals(1, historyFixture().rows("sessions").size) // Display each document; no cross-week accumulation.
    }
    @Test fun controllerLoadsAndSavesOnlyEditedPrices() = runTest {
        val t = FixtureTransport(); val c = HeatingController(MemoryConnectionStore(), t, StandardTestDispatcher(testScheduler)) { fixedNow }
        c.initialise(); c.reload(); c.selectPrices(-10.0, -5.0); c.savePolicy()
        val writes = t.calls.filter { it.second != null }
        assertEquals(1, writes.size); assertEquals(-10.0, writes.single().second!!.getJSONObject("policy").getDouble("on_price_p"), 0.0)
        assertFalse(c.state.value.needsReload)
    }
    @Test fun uncertainWriteCannotBeAutomaticallyReplayedOrSavedAgainUntilReload() = runTest {
        val t = FixtureTransport(); val c = HeatingController(MemoryConnectionStore(), t, StandardTestDispatcher(testScheduler)) { fixedNow }
        c.initialise(); c.reload(); t.failWrites = true; c.savePolicy(); c.savePolicy()
        assertEquals(1, t.calls.count { it.second != null }); assertTrue(c.state.value.needsReload)
        assertNull(c.state.value.status); assertNull(c.state.value.automation)
        t.failWrites = false; c.reload(); assertFalse(c.state.value.needsReload)
    }
    @Test fun networkFailureInvalidatesOldStateAndKeepsStopAvailable() = runTest {
        val t = FixtureTransport(); val c = HeatingController(MemoryConnectionStore(), t, StandardTestDispatcher(testScheduler)) { fixedNow }
        c.initialise(); c.reload(); t.failStatus = true; c.poll()
        assertNull(c.state.value.status); assertTrue(c.state.value.needsReload)
        c.setAutomation(false)
        assertEquals(false, t.calls.single { it.second?.has("enabled") == true }.second!!.getBoolean("enabled"))
    }
    @Test fun automationOnRequiresReadyStateAndOffDoesNotGrantActivation() = runTest {
        val t = FixtureTransport(); t.automation.put("can_enable", false)
        val c = HeatingController(MemoryConnectionStore(), t, StandardTestDispatcher(testScheduler)) { fixedNow }
        c.initialise(); c.reload(); c.setAutomation(true)
        assertTrue(t.calls.none { it.second != null })
        c.setAutomation(false); assertEquals(1, t.calls.count { it.second != null })
    }
    @Test fun switchingHostCannotReuseSavedKeyAndConnectionSurvivesRecreation() = runTest {
        val store = MemoryConnectionStore(); val dispatcher = StandardTestDispatcher(testScheduler)
        val c = HeatingController(store, FixtureTransport(), dispatcher) { fixedNow }
        c.initialise(); c.saveConnection("https://different.example", "")
        assertEquals("https://controller.example:8451", store.saved!!.address)
        c.saveConnection("https://controller.example:8451", "")
        val restored = HeatingController(store, FixtureTransport(), dispatcher) { fixedNow }; restored.initialise()
        assertTrue(restored.state.value.keyConfigured); assertEquals("https://controller.example:8451", restored.state.value.address)
    }
    @Test fun historyFailureIsSeparateFromControllerStatusAndDoesNotRetainWrongWeek() = runTest {
        val t = FixtureTransport(); val c = HeatingController(MemoryConnectionStore(), t, StandardTestDispatcher(testScheduler)) { fixedNow }
        c.initialise(); c.reload(); c.loadHistory(); assertNotNull(c.state.value.history)
        t.failHistory = true; c.loadHistory("2026-10-26")
        assertNull(c.state.value.history); assertNotNull(c.state.value.historyError); assertNotNull(c.state.value.status)
    }
    @Test fun externalPolicyRevisionBlocksStaleDraft() = runTest {
        val t = FixtureTransport(); val c = HeatingController(MemoryConnectionStore(), t, StandardTestDispatcher(testScheduler)) { fixedNow }
        c.initialise(); c.reload(); t.status.put("revision", 12); c.poll(); c.savePolicy()
        assertTrue(c.state.value.needsReload); assertTrue(t.calls.none { it.second != null })
    }
}

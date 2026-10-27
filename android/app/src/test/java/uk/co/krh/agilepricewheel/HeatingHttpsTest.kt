package uk.co.krh.agilepricewheel

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.net.URL
import java.security.cert.Certificate
import javax.net.ssl.HttpsURLConnection

private class FakeHttps(private val code: Int, private val reply: String = "{}") : HttpsURLConnection(URL("https://controller.example")) {
    var closed = false
    val sent = ByteArrayOutputStream()
    override fun getResponseCode() = code
    override fun getInputStream() = ByteArrayInputStream(reply.toByteArray())
    override fun getOutputStream() = sent
    override fun disconnect() { closed = true }
    override fun usingProxy() = false
    override fun connect() {}
    override fun getCipherSuite() = "TEST"
    override fun getLocalCertificates(): Array<Certificate>? = null
    override fun getServerCertificates(): Array<Certificate> = emptyArray()
}
class HeatingHttpsTest {
    @Test fun redirectsAreRefusedWithoutForwardingKey() {
        var opens = 0; val fake = FakeHttps(302)
        val t = HttpsHeatingTransport { opens++; fake }
        val failure = assertThrows(HeatingFailure::class.java) { t.exchange(heatingOrigin("https://controller.example"), "secret", "/v1/status", null) }
        assertTrue(failure.userMessage.contains("redirects")); assertFalse(fake.instanceFollowRedirects)
        assertEquals(1, opens); assertTrue(fake.closed)
    }
    @Test fun authenticationFailureDoesNotExposeTokenAndConflictDoesNotRetry() {
        for (code in listOf(401, 409, 500)) {
            var opens = 0; val fake = FakeHttps(code)
            val failure = assertThrows(HeatingFailure::class.java) {
                HttpsHeatingTransport { opens++; fake }.exchange(heatingOrigin("https://controller.example"), "never-show-this-token", "/v1/policy", policy())
            }
            assertFalse(failure.userMessage.contains("never-show")); assertEquals(1, opens); assertTrue(fake.closed)
            assertEquals(code == 500, failure.uncertainWrite)
        }
    }
    @Test fun bodyAndAuthorizationAreSentOnlyToExpectedOrigin() {
        val fake = FakeHttps(200, """{"enabled":false}""")
        val t = HttpsHeatingTransport { assertEquals("controller.example", it.host); assertEquals("/v1/automation", it.path); fake }
        assertFalse(t.exchange(heatingOrigin("https://controller.example"), "fixture", "/v1/automation", JSONObject().put("enabled", false)).getBoolean("enabled"))
        assertEquals("PUT", fake.requestMethod); assertEquals("Bearer fixture", fake.getRequestProperty("Authorization"))
        assertEquals(false, JSONObject(fake.sent.toString()).getBoolean("enabled"))
    }
    private fun policy() = JSONObject().put("revision", 11).put("policy", JSONObject())
}

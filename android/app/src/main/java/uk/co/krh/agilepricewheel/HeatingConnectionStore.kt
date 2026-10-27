package uk.co.krh.agilepricewheel

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import android.util.Base64
import org.json.JSONObject
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

// Not a data class: accidental toString/logging must not disclose the bearer key.
class HeatingConnection(val address: String, val token: String)
interface HeatingConnectionStore {
    fun load(): HeatingConnection?
    fun save(connection: HeatingConnection)
}

class KeystoreHeatingConnectionStore(context: Context) : HeatingConnectionStore {
    private val file = AtomicFile(File(context.noBackupFilesDir, "heating-connection.json"))
    private val alias = "AgilePriceWheel.HeatingController.AES.v1"
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }
    override fun load(): HeatingConnection? {
        if (!file.baseFile.exists()) return null
        val saved = JSONObject(String(file.readFully(), Charsets.UTF_8))
        val address = heatingOrigin(saved.getString("address")).toString()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, Base64.decode(saved.getString("iv"), Base64.NO_WRAP)))
        cipher.updateAAD(address.toByteArray(Charsets.UTF_8))
        val token = String(cipher.doFinal(Base64.decode(saved.getString("encrypted_key"), Base64.NO_WRAP)), Charsets.UTF_8)
        return HeatingConnection(address, token)
    }
    override fun save(connection: HeatingConnection) {
        val address = heatingOrigin(connection.address).toString()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key()); cipher.updateAAD(address.toByteArray(Charsets.UTF_8))
        val encrypted = cipher.doFinal(connection.token.toByteArray(Charsets.UTF_8))
        val json = JSONObject().put("address", address).put("iv", Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
            .put("encrypted_key", Base64.encodeToString(encrypted, Base64.NO_WRAP))
        val stream = file.startWrite()
        try { stream.write(json.toString().toByteArray(Charsets.UTF_8)); file.finishWrite(stream) }
        catch (e: Exception) { file.failWrite(stream); throw e }
    }
}

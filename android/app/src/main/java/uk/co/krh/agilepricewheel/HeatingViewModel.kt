package uk.co.krh.agilepricewheel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.launch

class HeatingViewModel(app: Application) : AndroidViewModel(app) {
    val controller = HeatingController(KeystoreHeatingConnectionStore(app))
    val state = controller.state
    init { viewModelScope.launch { controller.initialise() } }
    fun reload() { viewModelScope.launch { controller.reload() } }
    fun poll() { viewModelScope.launch { controller.poll() } }
    fun saveConnection(address: String, key: String) { viewModelScope.launch { controller.saveConnection(address, key) } }
    fun savePolicy() { viewModelScope.launch { controller.savePolicy() } }
    fun automation(enabled: Boolean) { viewModelScope.launch { controller.setAutomation(enabled) } }
    fun history(week: String? = null) { viewModelScope.launch { controller.loadHistory(week) } }
}

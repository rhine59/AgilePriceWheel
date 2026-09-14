package uk.co.krh.agilepricewheel

import android.app.Application
import android.location.Geocoder
import android.os.Build
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.util.Locale
import kotlin.coroutines.resume

class MainViewModel(app: Application) : AndroidViewModel(app) {
    private val _settings = MutableStateFlow(AppSettings())
    val settings: StateFlow<AppSettings> = _settings.asStateFlow()
    private val _rates = MutableStateFlow<List<AgileRate>>(emptyList())
    val rates = _rates.asStateFlow()
    private val _solar = MutableStateFlow<List<SolarPeriod>>(emptyList())
    val solar = _solar.asStateFlow()
    private val _loading = MutableStateFlow(false)
    val loading = _loading.asStateFlow()
    private val _error = MutableStateFlow<String?>(null)
    val error = _error.asStateFlow()

    fun updateSettings(transform: (AppSettings) -> AppSettings) { _settings.value = transform(_settings.value) }

    fun refresh() = viewModelScope.launch {
        _loading.value = true; _error.value = null
        try {
            val s = _settings.value
            _rates.value = AgileRepository.rates(s.productCode, s.tariffCode, s.selectedDate)
            if (s.latitude != null && s.longitude != null) _solar.value = SolarRepository.forecast(s.latitude, s.longitude, s.selectedDate)
        } catch (e: Exception) { _error.value = e.message ?: "Refresh failed" }
        finally { _loading.value = false }
    }

    fun setCurrentSite(latitude: Double, longitude: Double) = viewModelScope.launch {
        val name = reverseGeocode(latitude, longitude)
        _settings.value = _settings.value.copy(siteName = name, latitude = latitude, longitude = longitude)
        refresh()
    }

    private suspend fun reverseGeocode(lat: Double, lon: Double): String {
        val geocoder = Geocoder(getApplication(), Locale.UK)
        return if (Build.VERSION.SDK_INT >= 33) suspendCancellableCoroutine { cont ->
            geocoder.getFromLocation(lat, lon, 1) { addresses ->
                val a = addresses.firstOrNull()
                cont.resume(a?.locality ?: a?.subAdminArea ?: a?.adminArea ?: a?.featureName ?: "Current location")
            }
        } else withContext(Dispatchers.IO) {
            @Suppress("DEPRECATION")
            val a = geocoder.getFromLocation(lat, lon, 1)?.firstOrNull()
            a?.locality ?: a?.subAdminArea ?: a?.adminArea ?: a?.featureName ?: "Current location"
        }
    }
}

# Agile Price Wheel privacy policy

Last updated: 27 October 2026

Agile Price Wheel is maintained by Richard Hine. This policy describes the iPhone and iPad app, including its optional connection to a separately operated Homely heating controller.

## Information stored on your device

The app saves tariff, forecast-site, solar-system and display preferences on your device. It caches price and forecast data. A forecast site can include a name and precise latitude/longitude. Your heating-controller address is saved in app settings, and its access key is saved in Apple Keychain. Device backup and Keychain retention are governed by your Apple settings.

## Requests to external services

Octopus Energy supplies public tariff and price information. Requests include the selected product/tariff and normal network information such as your IP address; the app does not require your Octopus account credentials for those public prices.

Open-Meteo supplies forecast and place-search information. Forecast requests include the selected site's coordinates; place searches send the search text. The service also receives normal network information such as an IP address. Open-Meteo states that technical logs may contain coordinates and are deleted after 90 days. Its practices are described at https://open-meteo.com/en/terms.

When you choose Use Current Location and grant permission, Apple location services obtain a location fix. The app uses Apple MapKit to obtain a readable place label. You can use a manually selected site instead and change location permission in iOS Settings. The app does not continuously track your location.

If you configure a heating controller, the app sends authenticated HTTPS requests to the address you choose. Saving a controller policy sends tariff/site/solar/load settings to that service. Automation controls send your requested changes; status/history requests retrieve controller observations and heating sessions. That service can retain policy, status, action and session records independently of the phone. Its operator controls service access, retention and deletion. This policy does not promise deletion of data held by a separately operated controller.

## Advertising, tracking and analytics

The inspected iOS release contains no advertising or third-party analytics SDK and does not use an advertising identifier or cross-app tracking. Network services can maintain operational logs as described in their own policies. The developer does not operate a central app account or analytics backend for this release.

## Choices and deletion

Location use is optional. You can change the forecast site, revoke location permission, and stop using the controller connection. Removing the app removes its app-container settings/cache, subject to Apple backups. Keychain items can persist independently; removing the app alone must not be treated as deleting the controller key or server records. Ask the operator of your configured controller about deleting its data. Contact external providers for requests concerning their logs.

## Contact and changes

For privacy questions, use https://github.com/rhine59/AgilePriceWheel/issues. Do not post controller keys, precise home coordinates or account credentials in a public issue. This policy will be updated when app data practices change.



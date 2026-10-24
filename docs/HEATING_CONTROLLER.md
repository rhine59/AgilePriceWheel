# Heating controller

## Heating controller (iOS only)

The iOS **Heating** page connects to the separate always-running Synology
controller in `rhine59/Homely` ([service documentation](https://github.com/rhine59/Homely/blob/main/controller/README.md)).
Enter its private HTTPS origin and controller key, then connect. The key is kept
in iOS Keychain; redirects and insecure HTTP are refused. This page remains
available whether PV display pages are shown or hidden.

Load the controller policy, set **Switch on at or below** and **Switch off above**
(in effective p/kWh), plus room target and safety limit. Off must be >= on;
require 5 <= target <= limit <=25°C. The **Use this app's tariff, solar site and PV
settings** button copies the app's existing selected tariff, site coordinates,
capacity, losses, inverter limit and optimiser electrical load into the draft.
Review the draft and explicitly confirm saving to the controller. Configure the
load to represent heat-pump electrical consumption. On/off prices use the same
Agile + forecast-PV cost model as the Net Electricity Price page, calculated by
the controller independently of the phone. There is no automatic upload just
from opening the page. Policy updates are revision-checked; reload after a
conflict or an uncertain network response before saving again.

Status refreshes every 30 seconds while the page is open and labels its last
check. Source failure/staleness clears price permission at the controller. The
app displays a **price decision**, never an actual heating/room-temperature
measurement. Live heating is disabled; temperature settings are stored but no
room sensor or Homely control adapter is connected. Closing the app does not
stop the controller's worker. NAS HTTPS routing and on-device acceptance remain
separate deployment work; do not treat a simulator build as a phone-to-NAS test.

This feature is implemented for iOS only. Android navigation and functionality
are unchanged; no Android Heating screen or controller client is included.

Build verified in Xcode 27 with the iOS 26.5 simulator. No physical-device or deployed HTTPS connection claim is made.

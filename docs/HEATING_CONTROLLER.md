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
app distinguishes the **price decision** from the supervisor status. It shows
saved-recovery warnings and flags heating checks older than 45 seconds or dated
in the future. If the controller supplies optional Homely observations, the app
labels reported temperature and heating state separately and warns that the
sensor is not yet verified for automatic safety checks. Without an observer it
explicitly reports that live Homely readings are not connected.

After the first successful connection, returning to Heating reconnects using the
saved HTTPS address and Keychain key. Editing either connection field clears the
old connection and draft; requests completing for a previous connection are not
applied to the new one. Saving policy still requires confirmation. Live heating
remains disabled; the app has no activation switch or direct Homely commands.
Closing the app does not stop the NAS worker. Simulator tests and an app install
do not by themselves establish a physical phone-to-NAS acceptance test.

This feature is implemented for iOS only. Android navigation and functionality
are unchanged; no Android Heating screen or controller client is included.

Build and six focused tests verified in Xcode 27 with the iOS 26.5 simulator
(five API/model tests and one navigation test). The signed development app was
installed over the existing app and launched on a paired iPhone 13 Pro Max.
The original bundle identity was retained; the app was not uninstalled. A
physical phone-to-NAS authenticated connection is a separate acceptance step.

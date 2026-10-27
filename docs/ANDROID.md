# Android implementation and parity

Updated 27 October 2026. The native Kotlin/Jetpack Compose client now includes
Agile heating, using the same six controller HTTP services as iOS. The phone
contains no Homely login or direct Homely control transport. The Synology NAS
remains the always-running controller.

## Heating operation

1. In **Settings → Heating connection**, enter the controller HTTPS origin
   (including its external port) and bearer key. Save connection.
2. Open **Heating → Test connection / reload controller policy**.
3. Select **Heating on** and **Heating off**, review and confirm Save policy.
   Menus cover −20…+20 p/kWh, including zero. An existing price outside that range
   is retained as an extra choice. Off must be greater than or equal to on.
4. Enable **Automation** and confirm. This uses existing controller activation;
   the phone cannot grant administrative activation. OFF needs no confirmation
   and requests shutdown. **Stop automation** remains available after a read
   failure so an explicit OFF can still be attempted.
5. Open **Weekly heating log** for sessions, individual actions and UK weeks.

Heating policy is price permission; Heating state is Homely's last heating report.
ON is red, OFF green and UNKNOWN blue. Old/failed controller checks cannot display
a reassuring OFF. The app updates status every 30 seconds while Heating is in
view and the app is started; indicators age out after 45 seconds, and policy
permission also expires at its reported slot end. Old room samples are labelled.
Recovery, manual holds and shutdown pending are shown separately.

The owner requires heating enabled for qualifying half-hour slots with existing
Homely temperature settings. There are no temperature selectors. Homely can stop
actual heat production at its own target. Explicit OFF, manual changes, policy
edits or data/recovery failures can end permission early. The prepared 22°C
experiment was cancelled before heating writes; no temperature mode is enabled.

## Policy and connection integrity

Saves retain the complete latest policy document and its revision, including
legacy temperature fields. Only selected prices change unless the user explicitly
copies this app's tariff/site/PV/load into the draft. Copying is not a save.
HTTP 409 requires reload. An uncertain write is never retried automatically and
blocks another policy save/enable until successful reload. Operations are
serialized, and failed reads clear status/switch certainty rather than showing
old data as current. History errors do not disable the policy screen.

Only HTTPS origins without credentials, paths, queries or fragments are accepted.
All redirects are refused, normal certificate verification stays enabled, bearer
keys never enter URLs or logs. Android Keystore encrypts the bearer key using
AES-GCM with the canonical origin as associated data. The atomic connection file
is in `noBackupFilesDir`; the key is not backed up. App updates using the same
application ID/signature retain the connection. Reinstall, key loss or migration
to another phone requires re-entry. A changed origin needs an explicitly entered
key; leaving the field blank reuses a key only for the identical origin.

## Weekly session costs

Monday–Sunday boundaries and GMT/BST labels use Europe/London. The app displays
the server's paired sessions, durations, estimated energy, unit prices and costs.
Negative totals say **Estimated payment**. Missing cost/load/rate data or an
unconfirmed end remain unavailable. No estimate is recomputed from today's load,
no missing value becomes zero, and no manual action invents an OFF. A session
crossing weeks can appear under the same ID in each week; there is no summed
cross-week total. Do not add duplicate appearances. Warnings, pending writes,
retention and truncated history are visible.

## Other pages and layout

Prices, Solar, PV, Net, Save, Heating, Settings and Guide use scrollable tabs so
all destinations remain reachable on narrow screens. With PV off, only PV, Net
and Save disappear; Heating stays available. Phone/tablet content is centred and
width-limited. Now applies only to metric pages. See the root guide for the
existing pricing/solar calculations and location behaviour.

## Build, tests and distribution

See [Android README](../android/README.md), the reproducible
[verification script](../scripts/verify-android.sh), and
[verification evidence](ANDROID-HEATING-VERIFICATION.md).
The installable debug APK is for direct evaluation. Play Store signing, listing
and physical-device acceptance remain separate distribution work. The existing
iPhone app and live NAS image/policy are not replaced by this Android build.

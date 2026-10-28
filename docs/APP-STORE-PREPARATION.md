# App Store preparation — 27 October 2026

The intended iOS release is one combined app: AgilePriceWheel includes native energy planning and Homely heating controls. The separate Homely Python service runs independently of the phone; this release does not embed that server into iOS.

Version 2.1 build 2 uses bundle KRH.AgilePriceWheel, team VNQTGCW476, and minimum iOS 26.5. The existing App Store Connect app is 6820970865. Build 1 was already uploaded, so the release candidate increments the build number.

Release device build and signed archive succeeded with Xcode 27. All 22 iPhone simulator checks passed (15 Swift tests and 7 UI checks). The bundled privacy manifest declares CA92.1 for app-only saved settings. iPad/other-device screenshots and physical TestFlight validation remain to be completed.

Build generated products in a temporary folder outside Documents: Finder/iCloud metadata caused simulator signing failures in Documents. A clean temporary build resolved this.

Command-line distribution export reported No Accounts despite the account being visible in Xcode. Opening the signed archive in Xcode Organizer allowed the native App Store Connect distribution workflow to proceed to upload. Verify the final upload and processing state in Organizer and App Store Connect; starting an upload is not proof of completion.

The store description and subtitle explain the combined product and optional controller requirements. Release is set to manual so public availability waits for owner approval. The updated developer agreement was accepted as authorized. The owner approved the Apple-OS-only encryption declaration; existing build 1 now says Ready to Test. New builds require their own compliance check unless the approved declaration is embedded in Info.plist.

Privacy policy/labels and isolated controller review access remain prerequisites. Open-Meteo's published privacy terms describe retention of logs that can contain coordinates; do not assert Data Not Collected without reviewing all network handling. A policy draft is awaiting owner approval. Do not copy live home controller credentials into public documentation or a demo environment.

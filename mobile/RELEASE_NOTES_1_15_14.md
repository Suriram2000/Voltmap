# VoltMapEV 1.15.14 (46)

Fixes the expanded iPhone Duo navigation issue found during native fold testing of 1.15.13.

The narrow left navigation pane no longer consumes the system inset from the opposite screen edge. A regression test uses an expanded 951×669-point window with an 84-point right inset and opens every primary tab through hit-testable navigation controls.

The release retains the adaptive map/list layouts, safe areas and resize continuity from 1.15.13. It uses Flutter 3.47.7 and the iOS 27.1 SDK.

Validation and App Store submission are pending. Native verification will check actual hinge angles 0°, 180°, 90° and 0° again, require the same app process to survive, and capture each active display. The previous 1.15.13 release remains approved and intact.

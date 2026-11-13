# VoltMapEV 1.15.13 (45)

Universal iOS update using the existing `in.voltmap.voltmap` app identity.

- Adaptive side navigation for medium and large windows; bottom navigation in short landscape windows.
- Side-by-side charger map and scrollable station list when both panes have room.
- Compact embedded map controls based on their actual pane width.
- Landscape safe-area protection and continuity of trip input, tab selection and charger filters across resizing.

Validation covers representative compact, expanded, iPhone and iPad windows, accessibility text, safe-area insets and repeated resize transitions. These are Flutter widget scenarios, not physical iPhone Duo certification. Native pose-specific reserved-region behavior has not been implemented or verified.

Built with Xcode 27.1 and the iOS 27.1 SDK. The pipeline launches the app on the iPhone Duo simulator and captures a screenshot for visual review. Physical-device and pose-specific behavior remain unverified.

The Free Apps Agreement was confirmed Active on November 13, 2026, after an earlier agreement error.

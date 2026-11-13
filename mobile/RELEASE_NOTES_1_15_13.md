# VoltMapEV 1.15.13 (44)

Universal iOS update using the existing `in.voltmap.voltmap` app identity.

- Adaptive side navigation for medium and large windows; bottom navigation in short landscape windows.
- Side-by-side charger map and scrollable station list when both panes have room.
- Compact embedded map controls based on their actual pane width.
- Landscape safe-area protection and continuity of trip input, tab selection and charger filters across resizing.

Validation covers representative compact, expanded, iPhone and iPad windows, accessibility text, safe-area insets and repeated resize transitions. These are Flutter widget scenarios, not physical iPhone Duo certification. Native pose-specific reserved-region behavior has not been implemented or verified.

Apple currently blocks App Store API access with `FORBIDDEN.REQUIRED_AGREEMENTS_MISSING_OR_EXPIRED`. The Account Holder must resolve the required agreement before App Review submission can complete.

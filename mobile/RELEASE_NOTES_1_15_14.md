# VoltMapEV 1.15.14 (46)

**Submitted to Apple App Review on November 16, 2026.** Apple's acknowledgement is **WAITING_FOR_REVIEW**, with automatic release after approval.

The expanded iPhone Duo navigation controls now remain visible when the system reserves space at the opposite screen edge. The left navigation pane no longer consumes the screen's right inset.

Validation: static analysis clean; **159 tests passed with 2 conditional skips**, plus production checkout and 4 App Store access tests. A regression checks all six navigation targets in an expanded window with an 84-point right inset.

Native iPhone Duo / iOS 27.1 verification passed at hinge angles **0° → 180° → 90° → 0°**. The same app process survived all transitions. Actual captures were visually inspected: all six navigation controls are visible in open and partially open modes, and the app returns to the closed display. Physical-device testing remains outstanding.

- Signed build and native verification: https://github.com/Suriram2000/Voltmap/actions/runs/43771722154
- Final Apple acknowledgement: https://github.com/Suriram2000/Voltmap/actions/runs/43842538721
- Submission: `2e84c9cd-fa77-4b72-a3b5-c2996730666c`
- App Store version: `f2da10ed-2cae-4792-9adf-9f51832e628b`
- Build: `5535d77d-18c7-43e2-be44-c9174ccd87b1`
- Application source: `2d83e93b1ee9230ace5f9f29eadbef6867c0fd70`

Flutter 3.47.7 / Xcode 27.1. Existing 1.15.13 remains published while Apple reviews this update. No Android, website or WhatsApp deployment is included.

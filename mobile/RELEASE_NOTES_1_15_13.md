# VoltMapEV 1.15.13 (45)

Universal iOS update for the existing `in.voltmap.voltmap` app.

- Adaptive side navigation for medium and large windows, with bottom navigation in short landscape windows.
- Side-by-side charger map and scrollable station list where both panes fit.
- Embedded map controls based on their actual pane width.
- Landscape safe areas and preserved trip input, tab selection and charger filters during resizing.

The signed IPA uses the iOS 27.1 SDK. Static analysis was clean; 158 tests passed with 2 conditional skips, plus the production checkout test and 4 App Store reviewer-access tests. Apple accepted the upload, processed build 45, and received the App Review submission. Status: **Waiting for Review**, with automatic release after approval.

Submission: `161b7321-8677-4f5f-a0cc-61a63a447ad6`.
Successful verified upload run: `43495070555`.
Binary source commit: `8729203dd39e31fc1e52ae35d409c11f40ae8d77`.

The dedicated hosted iPhone Duo simulator validation remains incomplete. Simulator boot succeeded in the final retry, but the follow-on tool setup stalled. No dedicated Duo storefront screenshot was uploaded; physical-device and pose-specific behavior are unverified. The automated compact/expanded window and resize tests passed.

Release tooling pins Flutter 3.47.7, supports validated artifact upload without rebuilding, and keeps Duo simulator validation separate from signed release delivery.

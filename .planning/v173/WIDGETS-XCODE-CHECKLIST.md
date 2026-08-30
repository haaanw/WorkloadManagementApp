# Widget extension — HAN's Xcode checklist (v1.7.3 feature 3)

All the source files exist and are committed. This checklist is only the part that
must happen inside Xcode: target creation and capability signing. Do these steps in
order. Creating an extension target by hand in `.pbxproj` is the known serialization
death — that is why this list exists.

**What is already done (do not redo):**
- Extension sources: `TuwaWidgets/` at the repo root (5 Swift files, a local
  `Localizable.xcstrings`, an `Info.plist`).
- App-side writer: `WorkloadApp/Services/WidgetSnapshot.swift`,
  `WidgetSnapshotStore.swift`, `WidgetSnapshotWriter.swift` — already in the app
  target and wired into the pipelines. The writer is a silent no-op until the App
  Group capability exists, so the app runs unchanged today.
- Codec unit tests: `WorkloadAppTests/WidgetSnapshotTests.swift` (auto-included —
  the test target is file-synchronized).

## Steps

1. Open `workload management.xcodeproj`. File → New → Target… →
   **Widget Extension** (iOS). Set:
   - Product Name: **TuwaWidgets**
   - Bundle identifier will become `com.tonus.app.TuwaWidgets` — keep it.
   - UNCHECK "Include Configuration App Intent" (our widgets are static).
   - UNCHECK "Include Live Activity" if offered.
   - Finish. When Xcode asks to activate the new scheme, click **Cancel** (build
     through the app scheme as usual).

2. Xcode created a template folder `workload management/TuwaWidgets/` with sample
   files (`TuwaWidgets.swift`, maybe `TuwaWidgetsBundle.swift`, an asset catalog).
   **Delete the template `.swift` files** (Move to Trash). Keep the asset catalog if
   one was created (harmless).

3. Add the real sources: File → Add Files to "workload management"… → select ALL
   files inside the repo-root **`TuwaWidgets/`** folder EXCEPT `Info.plist`
   (5 × `.swift` + `Localizable.xcstrings`):
   - Target membership: **TuwaWidgets only** (uncheck the app target).
   - "Copy items if needed" OFF (they are already in the repo).

4. Point the target at the prepared Info.plist (it carries the widget extension
   point AND the `UIAppFonts` registration the design system needs):
   - Select the TuwaWidgets target → Build Settings → search "Info.plist".
   - Set **Generate Info.plist File = No**.
   - Set **Info.plist File** = `../TuwaWidgets/Info.plist`
     (path is relative to the `workload management/` project folder).

5. Shared file membership — select each file below in the navigator, open the File
   Inspector (⌥⌘1), and CHECK the **TuwaWidgets** box under Target Membership
   (leave the app target checked):
   - `WorkloadApp/Services/WidgetSnapshot.swift`
   - `WorkloadApp/Services/WidgetSnapshotStore.swift`
   - `WorkloadApp/Utilities/ColorTokens.swift`
   - `WorkloadApp/Utilities/FontTokens.swift`
   (NOT `WidgetSnapshotWriter.swift` — the extension never writes.)

6. Font resources — same File Inspector procedure, check **TuwaWidgets** on all
   five files in `WorkloadApp/Resources/Fonts/`:
   - `InstrumentSans-Regular.ttf`, `InstrumentSans-Medium.ttf`,
     `FragmentMono-Regular.ttf`, `NotoSansSC-Regular.otf`, `NotoSansSC-Medium.otf`
   (They must appear in the TuwaWidgets target's **Copy Bundle Resources** phase —
   Xcode does this when you tick the box.)

7. App Group capability, **both targets** (this is the signed part only you can do):
   - Select the **app** target → Signing & Capabilities → **+ Capability** →
     App Groups → **+** → add `group.com.tonus.app`.
   - Select the **TuwaWidgets** target → same → add the SAME group
     `group.com.tonus.app` (it will appear in the list once the app target created
     it; just tick it).
   - The group ID must match `WidgetSnapshotStore.appGroupID` exactly.

8. TuwaWidgets target → General: set **Minimum Deployment** to **iOS 17.0**
   (the template may default higher).

9. Build the app scheme (⌘B). Then run on a simulator, background the app, long-press
   the home screen → add the two Tuwa widgets. The readiness widget populates after
   the first dashboard load; the load widget after the first dashboard load or
   workout save.

10. Tell CLAUDE it is done — the session then runs the build + full suite
    verification and commits the `.pbxproj` state Xcode wrote.

## Notes

- Widget strings live in `TuwaWidgets/Localizable.xcstrings` (en + zh-Hans) — the
  app's catalog is untouched, so this does not collide with the other session's WIP.
- The snapshot carries composite values only (score, zones, verdict line, day-total
  loads). The raw-data law extends to the App Group container and
  `WidgetSnapshotTests.test_compositeOnly_noRawSignalFieldNames` fences it.
- Until step 7, the app writes nothing to the group (silent no-op by design) and the
  widgets show their empty state.

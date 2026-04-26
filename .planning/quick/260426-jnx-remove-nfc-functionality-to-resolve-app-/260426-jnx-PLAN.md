---
phase: quick
plan: 260426-jnx
type: execute
wave: 1
depends_on: []
files_modified:
  - WorkloadApp/Services/NFCSessionCoordinator.swift
  - WorkloadApp/Views/Profile/ProfileView.swift
  - WorkloadApp/Views/Profile/InviteConfirmationSheet.swift
  - WorkloadApp/Views/Subscription/UpgradeSheet.swift
  - workload management/workload management.xcodeproj/project.pbxproj
autonomous: true
requirements: []
must_haves:
  truths:
    - "App builds successfully with no NFC references in any compiled code"
    - "ProfileView coach-athlete linking still works via invite code and email (NFC option gone)"
    - "No NFCReaderUsageDescription in Info.plist keys (pbxproj)"
  artifacts:
    - path: "WorkloadApp/Services/NFCSessionCoordinator.swift"
      provides: "DELETED — must not exist after execution"
  key_links:
    - from: "ProfileView.swift"
      to: "NFCSessionCoordinator"
      via: "REMOVED — no import, no @State, no button, no startNFC function"
---

<objective>
Remove all NFC functionality from Tonus to resolve App Store rejection (Guideline 2.1 — Apple requires a demo video for NFC apps, which is disproportionate for a peripheral linking method).

Purpose: Unblock App Store approval by eliminating the NFC capability entirely. NFC was one of four coach-athlete linking methods (invite code, email, QR, NFC) — the remaining three are sufficient.

Output: Clean build with zero NFC references.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@WorkloadApp/Services/NFCSessionCoordinator.swift
@WorkloadApp/Views/Profile/ProfileView.swift
@WorkloadApp/Views/Profile/InviteConfirmationSheet.swift
@WorkloadApp/Views/Subscription/UpgradeSheet.swift
@workload management/workload management.xcodeproj/project.pbxproj
</context>

<tasks>

<task type="auto">
  <name>Task 1: Delete NFCSessionCoordinator and remove all NFC references from Swift source</name>
  <files>
    WorkloadApp/Services/NFCSessionCoordinator.swift,
    WorkloadApp/Views/Profile/ProfileView.swift,
    WorkloadApp/Views/Profile/InviteConfirmationSheet.swift,
    WorkloadApp/Views/Subscription/UpgradeSheet.swift
  </files>
  <action>
1. DELETE `WorkloadApp/Services/NFCSessionCoordinator.swift` entirely.

2. In `ProfileView.swift`:
   - Remove `@State private var nfcCoordinator = NFCSessionCoordinator()`.
   - Remove the "Link via NFC" `actionButton` call and its trailing `divider()` (around line 281-283).
   - Remove the entire `startNFC(athlete:)` private function (around line 531-541 and its error handling).
   - Remove any `import CoreNFC` if present.
   - Verify no remaining references to `nfcCoordinator`, `startNFC`, `NFCSessionCoordinator`, or `CoreNFC`.

3. In `InviteConfirmationSheet.swift`:
   - Update the comment on line 6 from `"coach entered a code or scanned NFC"` to `"coach entered a code"`.

4. In `UpgradeSheet.swift`:
   - Update the coach feature bullet (around line 357) from `"Link athletes via invite code, email, or NFC"` to `"Link athletes via invite code or email"`.
  </action>
  <verify>
    <automated>cd /Users/hanwen/Desktop/Tonus && grep -rn "NFC\|CoreNFC\|nfcCoordinator\|startNFC\|NFCSessionCoordinator" WorkloadApp/ --include="*.swift" | grep -v ".claude/" ; echo "EXIT:$?"</automated>
  </verify>
  <done>Zero NFC references in any Swift source file under WorkloadApp/. NFCSessionCoordinator.swift deleted.</done>
</task>

<task type="auto">
  <name>Task 2: Remove NFC from Xcode project file (pbxproj) and verify build</name>
  <files>workload management/workload management.xcodeproj/project.pbxproj</files>
  <action>
1. In `project.pbxproj`, remove these lines (4 distinct entries):
   - PBXBuildFile: `59881BC9C8890B491E7D3603 /* NFCSessionCoordinator.swift in Sources */` (build file reference)
   - PBXFileReference: `A2E3ECA23709AF06AC23972B /* NFCSessionCoordinator.swift */` (file reference)
   - PBXGroup children entry: `A2E3ECA23709AF06AC23972B /* NFCSessionCoordinator.swift */,` (in Services group)
   - PBXSourcesBuildPhase entry: `59881BC9C8890B491E7D3603 /* NFCSessionCoordinator.swift in Sources */,` (in sources build phase)

2. Remove BOTH `INFOPLIST_KEY_NFCReaderUsageDescription` lines (one in Debug, one in Release build settings) — the value is `"Tonus uses NFC to link athletes and coaches in person."`.

3. Verify no CoreNFC framework references exist (there should be none — confirmed during analysis).

4. Build the project:
   ```
   xcodebuild -project "workload management/workload management.xcodeproj" \
     -scheme "workload management" \
     -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
     -quiet build
   ```
  </action>
  <verify>
    <automated>cd /Users/hanwen/Desktop/Tonus && grep -n "NFC" "workload management/workload management.xcodeproj/project.pbxproj" ; echo "EXIT:$?"</automated>
  </verify>
  <done>Zero NFC references in pbxproj. Project builds cleanly with no NFC capability, no NFC usage description, and no NFCSessionCoordinator in the compile sources.</done>
</task>

</tasks>

<verification>
1. `grep -rn "NFC\|CoreNFC" WorkloadApp/ "workload management/workload management.xcodeproj/project.pbxproj" --include="*.swift" --include="*.pbxproj"` returns zero matches
2. `xcodebuild build` succeeds with no errors
3. ProfileView still shows invite code and email linking options (NFC button gone)
</verification>

<success_criteria>
- NFCSessionCoordinator.swift deleted from disk and from pbxproj
- Zero occurrences of "NFC" or "CoreNFC" in any Swift file or project file
- NFCReaderUsageDescription removed from both Debug and Release build settings
- Project builds successfully on iOS Simulator
- Coach-athlete linking via invite code and email remains functional
</success_criteria>

<output>
After completion, create `.planning/quick/260426-jnx-remove-nfc-functionality-to-resolve-app-/260426-jnx-SUMMARY.md`
</output>

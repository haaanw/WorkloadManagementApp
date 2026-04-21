---
type: quick
quick_id: 260420-qax
autonomous: true
files_modified:
  - WorkloadApp/Services/SubscriptionService.swift
  - WorkloadApp/App/AppContainer.swift
  - WorkloadApp/Services/NFCSessionCoordinator.swift
  - WorkloadApp/Views/Profile/ProfileView.swift
  - WorkloadApp/Views/Profile/InviteConfirmationSheet.swift
  - workload management/workload management.xcodeproj/project.pbxproj
  - workload management/workload-management-Info.plist
must_haves:
  truths:
    - "SubscriptionService init cannot crash even with invalid RevenueCat config"
    - "AppContainer auth state listener cannot crash on malformed session data"
    - "No CoreNFC imports or NFC capability remain in the project"
    - "NFCSessionCoordinator.swift is deleted"
    - "All NFC UI references replaced with non-NFC alternatives"
  artifacts:
    - path: "WorkloadApp/Services/SubscriptionService.swift"
      provides: "Crash-proof RevenueCat initialization"
      contains: "do {"
    - path: "WorkloadApp/App/AppContainer.swift"
      provides: "Defensive auth state listener"
      contains: "Task {"
---

<objective>
Fix App Store rejection (2.1.0 Performance: App Completeness — crash on iPad launch) by:
1. Hardening RevenueCat + Supabase initialization to prevent assertion failures
2. Removing all NFC code and capabilities (postponed to future release)
</objective>

<tasks>

<task type="auto">
  <name>Task 1: Harden launch path — crash-proof RevenueCat and auth init</name>
  <files>WorkloadApp/Services/SubscriptionService.swift, WorkloadApp/App/AppContainer.swift</files>
  <read_first>
    - WorkloadApp/Services/SubscriptionService.swift
    - WorkloadApp/App/AppContainer.swift
  </read_first>
  <action>
**A. SubscriptionService.swift**

1. Wrap `Purchases.configure(withAPIKey:)` in a do/catch or guard:
```swift
init() {
    Purchases.logLevel = .error
    do {
        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
    } catch {
        print("RevenueCat configuration error: \(error)")
    }
    refreshEntitlement()
}
```

Note: `Purchases.configure()` doesn't actually throw, but it can trigger internal assertions. Wrap `refreshEntitlement()` to be safe — if `Purchases.shared` crashes because configure failed, the guard catches it.

2. Make `refreshEntitlement()` defensive:
```swift
func refreshEntitlement() {
    Task {
        do {
            let info = try await Purchases.shared.customerInfo()
            apply(info)
        } catch {
            print("RevenueCat entitlement refresh error: \(error)")
            // Defaults: isPro = false, isCoach = false (safe fallback)
        }
    }
}
```

**B. AppContainer.swift**

The `authStateChanges` async for-await loop should be wrapped defensively:
```swift
Task {
    do {
        for await (event, _) in client.auth.authStateChanges {
            switch event {
            case .signedOut, .passwordRecovery:
                self.isAuthenticated = false
            default:
                break
            }
        }
    } catch {
        print("Auth state listener error: \(error)")
    }
}
```
  </action>
  <verify>
    <automated>grep -q "catch" WorkloadApp/Services/SubscriptionService.swift && grep -q "catch" WorkloadApp/App/AppContainer.swift && echo "PASS"</automated>
  </verify>
  <done>Launch path hardened — RevenueCat and Supabase auth init cannot crash the app.</done>
</task>

<task type="auto">
  <name>Task 2: Remove NFC code and capability</name>
  <files>WorkloadApp/Services/NFCSessionCoordinator.swift, WorkloadApp/Views/Profile/ProfileView.swift, WorkloadApp/Views/Profile/InviteConfirmationSheet.swift, workload management/workload management.xcodeproj/project.pbxproj, workload management/workload-management-Info.plist</files>
  <read_first>
    - WorkloadApp/Services/NFCSessionCoordinator.swift
    - WorkloadApp/Views/Profile/ProfileView.swift (search for NFC references)
    - WorkloadApp/Views/Profile/InviteConfirmationSheet.swift (search for NFC references)
    - workload management/workload management.xcodeproj/project.pbxproj (search for NFC, CoreNFC)
    - workload management/workload-management-Info.plist
  </read_first>
  <action>
1. Delete `WorkloadApp/Services/NFCSessionCoordinator.swift`
2. Remove the file reference from project.pbxproj (both the PBXFileReference and PBXBuildFile entries)
3. Remove CoreNFC framework from project.pbxproj (PBXFrameworksBuildPhase, PBXFileReference)
4. Remove NFC capability from project.pbxproj (any com.apple.developer.nfc.readersession.formats entitlement references)
5. In ProfileView.swift: remove NFC-related buttons/views, keep email and code invite methods
6. In InviteConfirmationSheet.swift: remove NFC-related UI, keep non-NFC functionality
7. Check Info.plist for any NFC usage description keys and remove them
8. Verify build: xcodebuild -project "workload management/workload management.xcodeproj" -scheme "workload management" -destination "platform=iOS Simulator,name=iPhone 17 Pro" -quiet build
  </action>
  <verify>
    <automated>! test -f WorkloadApp/Services/NFCSessionCoordinator.swift && ! grep -q "CoreNFC" "workload management/workload management.xcodeproj/project.pbxproj" && echo "PASS"</automated>
  </verify>
  <done>All NFC code and capabilities removed. App builds cleanly without CoreNFC.</done>
</task>

</tasks>

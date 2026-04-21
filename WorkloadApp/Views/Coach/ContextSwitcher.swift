import SwiftUI
import SwiftData

/// Single-button mode toggle placed in the leading navigation bar position.
/// Shows the mode you can switch TO. Tapping switches immediately.
/// Only visible when the local athlete has isCoach = true.
struct ContextSwitcher: ViewModifier {
    @Environment(AppContainer.self) private var container
    @Query private var athletes: [Athlete]
    @State private var showUpgrade = false

    private var athlete: Athlete? { athletes.first }

    func body(content: Content) -> some View {
        if athlete?.isCoach == true, athlete?.isCoachOnly != true {
            content
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            if container.currentMode == .athlete {
                                if !container.subscriptionService.isCoach {
                                    showUpgrade = true
                                } else {
                                    container.setMode(.coach)
                                }
                            } else {
                                container.setMode(.athlete)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: container.currentMode == .athlete
                                      ? "arrow.right.arrow.left"
                                      : "arrow.right.arrow.left")
                                    .font(.system(size: 12))
                                Text(switchLabel)
                                    .font(.Tokens.micro)
                            }
                            .foregroundStyle(ColorTokens.text2)
                        }
                    }
                }
                .sheet(isPresented: $showUpgrade) {
                    UpgradeSheet(trigger: .coach)
                }
        } else {
            content
        }
    }

    private var switchLabel: String {
        container.currentMode == .athlete ? "COACH" : "ATHLETE"
    }
}

extension View {
    func withContextSwitcher() -> some View {
        modifier(ContextSwitcher())
    }
}

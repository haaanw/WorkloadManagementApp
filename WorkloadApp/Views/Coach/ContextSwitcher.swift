import SwiftUI
import SwiftData

/// Deprecated adapter: context switching now lives in Profile and swaps the whole app shell.
struct ContextSwitcher: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

extension View {
    func withContextSwitcher() -> some View {
        modifier(ContextSwitcher())
    }
}

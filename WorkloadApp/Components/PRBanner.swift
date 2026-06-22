import SwiftUI

/// Inline, dismissible post-workout banner shown when a session set new personal records.
/// Mirrors SpikeAlertBanner: flat surfaceEl card, colored left border (zone optimal = PR),
/// hairline divider stroke, 0pt square corners, no shadow, tap-to-dismiss.
struct PRBanner: View {
    let prs: [PersonalRecord]
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Colored left border strip — zone optimal signals a PR.
            Rectangle()
                .fill(ColorTokens.zoneOptimal)
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 8) {
                Text(prs.count > 1
                    ? String(localized: "workout.pr.title.plural", defaultValue: "New PRs!")
                    : String(localized: "workout.pr.title.single", defaultValue: "New PR!"))
                    .font(.Tokens.micro)
                    .tracking(0.88)
                    .foregroundStyle(ColorTokens.zoneOptimal)

                ForEach(prs, id: \.id) { pr in
                    HStack(spacing: 16) {
                        Text(pr.exerciseName)
                            .font(.Tokens.smallLabel)
                            .foregroundStyle(ColorTokens.text1)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 8)

                        Text("\(pr.recordType.displayName): \(String(format: "%.1f", pr.value))")
                            .font(.Tokens.smallLabelMedium)
                            .monospacedDigit()
                            .foregroundStyle(ColorTokens.text2)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            Spacer()
        }
        .background(ColorTokens.surfaceEl)
        .overlay(
            Rectangle()
                .stroke(ColorTokens.divider, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { Haptics.tap(); onDismiss() }
        // A PR was detected and surfaced → the one sanctioned success cue.
        .onAppear { Haptics.success() }
    }
}

import Foundation
import UIKit

/// Pure PDF generation engine. No state, no side effects.
/// Generates athlete training reports and coach roster summaries using UIGraphicsPDFRenderer.
/// Uses hardcoded light-mode colors for print/share readability -- never references ColorTokens.
/// Excludes raw HealthKit data (HRV, RHR, sleep duration) per Apple guidelines -- only composite scores.
struct PDFReportEngine {

    // MARK: - Public Types

    /// Date range options for report generation.
    enum ReportDateRange: CaseIterable {
        case fourWeeks, eightWeeks, twelveWeeks

        var days: Int {
            switch self {
            case .fourWeeks: 28
            case .eightWeeks: 56
            case .twelveWeeks: 84
            }
        }

        var displayName: String {
            switch self {
            case .fourWeeks: "Last 4 weeks"
            case .eightWeeks: "Last 8 weeks"
            case .twelveWeeks: "Last 12 weeks"
            }
        }
    }

    /// Input data for a single athlete row in the coach roster report.
    struct RosterAthleteData {
        let name: String
        let recoveryScore: Double?
        let acwrZone: ACWRZone
        let sessionsCount: Int
        let streakCount: Int
        let isOverreaching: Bool
    }

    // MARK: - Page Constants

    private static let pageWidth: CGFloat = 612
    private static let pageHeight: CGFloat = 792
    private static let marginH: CGFloat = 48
    private static let marginV: CGFloat = 64
    private static let contentWidth: CGFloat = 516 // 612 - 48 - 48
    private static let headerHeight: CGFloat = 48
    private static let footerHeight: CGFloat = 24

    // MARK: - PDF Colors (hardcoded light-mode, never ColorTokens)

    private static let textPrimary = UIColor(red: 0.11, green: 0.10, blue: 0.08, alpha: 1)
    private static let textSecondary = UIColor(red: 0.41, green: 0.40, blue: 0.37, alpha: 1)
    private static let dividerColor = UIColor(red: 0.81, green: 0.80, blue: 0.77, alpha: 1)
    private static let accentMetric = UIColor(red: 0.48, green: 0.43, blue: 0.36, alpha: 1)
    private static let chartATL = UIColor(red: 0.42, green: 0.35, blue: 0.16, alpha: 1)
    private static let chartCTL = UIColor(red: 0.23, green: 0.29, blue: 0.36, alpha: 1)
    private static let zoneOptimal = UIColor(red: 0.24, green: 0.36, blue: 0.29, alpha: 1)
    private static let zoneCaution = UIColor(red: 0.42, green: 0.35, blue: 0.16, alpha: 1)
    private static let zoneDanger = UIColor(red: 0.43, green: 0.23, blue: 0.23, alpha: 1)
    private static let zoneLow = UIColor(red: 0.23, green: 0.29, blue: 0.36, alpha: 1)

    // MARK: - Font Helpers

    private static func fontRegular(_ size: CGFloat) -> UIFont {
        UIFont(name: "DMSans-Regular", size: size) ?? .systemFont(ofSize: size)
    }

    private static func fontMedium(_ size: CGFloat) -> UIFont {
        UIFont(name: "DMSans-Medium", size: size) ?? .systemFont(ofSize: size, weight: .medium)
    }

    // MARK: - Date Formatter

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    // MARK: - Athlete Report (EXPRT-01)

    /// Generates a PDF training report for a single athlete.
    ///
    /// Includes key metrics header, recovery overview chart, workload trends chart,
    /// session log table, and personal records table.
    ///
    /// - Parameters:
    ///   - athlete: The athlete whose data is being reported
    ///   - sessions: Workout sessions within the date range
    ///   - workloadSnapshots: Workload snapshots within the date range
    ///   - recoverySnapshots: Recovery snapshots within the date range
    ///   - personalRecords: Personal records achieved within the date range
    ///   - streakCount: Current training streak count
    ///   - dateRange: The reporting time window
    /// - Returns: PDF file data
    static func generateAthleteReport(
        athlete: Athlete,
        sessions: [WorkoutSession],
        workloadSnapshots: [WorkloadSnapshot],
        recoverySnapshots: [RecoverySnapshot],
        personalRecords: [PersonalRecord],
        streakCount: Int,
        dateRange: ReportDateRange
    ) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let endDate = Date.now
        let startDate = Calendar.current.date(byAdding: .day, value: -dateRange.days, to: endDate) ?? endDate
        let subtitleText = "\(athlete.displayName) | \(dateFormatter.string(from: startDate)) - \(dateFormatter.string(from: endDate))"
        let headerTitle = "Training Report"

        let sortedSessions = sessions.sorted { $0.sessionDate < $1.sessionDate }
        let sortedWorkload = workloadSnapshots.sorted { $0.snapshotDate < $1.snapshotDate }
        let sortedRecovery = recoverySnapshots.sorted { $0.date < $1.date }

        return renderer.pdfData { pdfContext in
            var pageNumber = 1
            var cursorY: CGFloat = marginV + headerHeight + 16

            // -- First page
            pdfContext.beginPage()
            let cgContext = pdfContext.cgContext
            drawHeader(context: cgContext, title: headerTitle, subtitle: subtitleText)

            // -- Key Metrics Header
            let metricColumnWidth = contentWidth / 5
            let metrics: [(value: String, label: String)] = [
                (sortedRecovery.last.map { String(format: "%.0f", $0.recoveryScore) } ?? "--", "RECOVERY"),
                (sortedWorkload.last?.zone.displayName ?? "--", "ACWR ZONE"),
                ("\(streakCount)", "STREAK"),
                ("\(sessions.count)", "SESSIONS"),
                ("\(personalRecords.count)", "PRS")
            ]

            for (index, metric) in metrics.enumerated() {
                let x = marginH + metricColumnWidth * CGFloat(index)
                let valueRect = CGRect(x: x, y: cursorY, width: metricColumnWidth, height: 32)
                let labelRect = CGRect(x: x, y: cursorY + 32, width: metricColumnWidth, height: 16)
                drawText(metric.value, in: valueRect, font: fontRegular(28), color: accentMetric, alignment: .center)
                drawText(metric.label, in: labelRect, font: fontRegular(11), color: textSecondary, alignment: .center)
            }
            cursorY += 56 + 8
            drawHairline(context: cgContext, y: cursorY)
            cursorY += 24

            // -- Recovery Overview
            drawText("RECOVERY OVERVIEW", in: CGRect(x: marginH, y: cursorY, width: contentWidth, height: 24), font: fontMedium(17), color: textPrimary)
            cursorY += 32

            if sortedRecovery.count >= 2 {
                let chartRect = CGRect(x: marginH, y: cursorY, width: contentWidth, height: 120)
                let dataPoints = sortedRecovery.map { (date: $0.date, value: $0.recoveryScore) }
                drawLineChart(context: cgContext, rect: chartRect, dataPoints: dataPoints, strokeColor: zoneOptimal.cgColor)
                cursorY += 128

                let currentScore = sortedRecovery.last.map { String(format: "%.0f", $0.recoveryScore) } ?? "--"
                let sleepText = sortedRecovery.last?.sleepScore.map { String(format: "%.0f", $0) } ?? "--"
                let summaryText = "Current: \(currentScore)/100 | Sleep: \(sleepText)/100"
                drawText(summaryText, in: CGRect(x: marginH, y: cursorY, width: contentWidth, height: 20), font: fontRegular(13), color: textPrimary)
                cursorY += 24
            } else {
                drawText("Not enough recovery data for trend chart.", in: CGRect(x: marginH, y: cursorY, width: contentWidth, height: 20), font: fontRegular(13), color: textSecondary)
                cursorY += 24
            }
            cursorY += 32

            // -- Workload Trends
            ensureSpace(200, context: pdfContext, cursorY: &cursorY, pageNumber: &pageNumber, headerTitle: headerTitle, headerSubtitle: subtitleText)
            drawText("WORKLOAD TRENDS", in: CGRect(x: marginH, y: cursorY, width: contentWidth, height: 24), font: fontMedium(17), color: textPrimary)
            cursorY += 32

            if sortedWorkload.count >= 2 {
                let chartRect = CGRect(x: marginH, y: cursorY, width: contentWidth, height: 120)
                let atlPoints = sortedWorkload.map { (date: $0.snapshotDate, value: $0.acuteLoad) }
                let ctlPoints = sortedWorkload.map { (date: $0.snapshotDate, value: $0.chronicLoad) }
                drawLineChart(context: cgContext, rect: chartRect, dataPoints: atlPoints, strokeColor: chartATL.cgColor)
                drawLineChart(context: cgContext, rect: chartRect, dataPoints: ctlPoints, strokeColor: chartCTL.cgColor)
                cursorY += 128

                // Legend
                let legendY = cursorY
                cgContext.setStrokeColor(chartATL.cgColor)
                cgContext.setLineWidth(1.5)
                cgContext.move(to: CGPoint(x: marginH, y: legendY + 8))
                cgContext.addLine(to: CGPoint(x: marginH + 24, y: legendY + 8))
                cgContext.strokePath()
                drawText("ATL (Acute)", in: CGRect(x: marginH + 32, y: legendY, width: 120, height: 16), font: fontRegular(11), color: textSecondary)

                cgContext.setStrokeColor(chartCTL.cgColor)
                cgContext.setLineWidth(1.5)
                cgContext.move(to: CGPoint(x: marginH + 160, y: legendY + 8))
                cgContext.addLine(to: CGPoint(x: marginH + 184, y: legendY + 8))
                cgContext.strokePath()
                drawText("CTL (Chronic)", in: CGRect(x: marginH + 192, y: legendY, width: 120, height: 16), font: fontRegular(11), color: textSecondary)
                cursorY += 24

                // Current zone
                if let latestZone = sortedWorkload.last?.zone {
                    drawText("Current zone: \(latestZone.displayName)", in: CGRect(x: marginH, y: cursorY, width: contentWidth, height: 20), font: fontRegular(13), color: textPrimary)
                    cursorY += 24
                }
            } else {
                drawText("Not enough workload data for trend chart.", in: CGRect(x: marginH, y: cursorY, width: contentWidth, height: 20), font: fontRegular(13), color: textSecondary)
                cursorY += 24
            }
            cursorY += 32

            // -- Session Log
            ensureSpace(80, context: pdfContext, cursorY: &cursorY, pageNumber: &pageNumber, headerTitle: headerTitle, headerSubtitle: subtitleText)
            drawText("SESSION LOG", in: CGRect(x: marginH, y: cursorY, width: contentWidth, height: 24), font: fontMedium(17), color: textPrimary)
            cursorY += 32

            let sessionColumns: [(text: String, width: CGFloat)] = [
                ("DATE", 90),
                ("SPORT", 150),
                ("DURATION", 70),
                ("RPE", 50),
                ("LOAD", 70),
                ("ACWR", 86)
            ]

            if sortedSessions.isEmpty {
                drawText("No sessions logged in this period.", in: CGRect(x: marginH, y: cursorY, width: contentWidth, height: 20), font: fontRegular(13), color: textSecondary)
                cursorY += 24
            } else {
                drawTableRow(context: cgContext, columns: sessionColumns, y: cursorY, font: fontMedium(11), color: textSecondary)
                cursorY += 24

                for session in sortedSessions {
                    ensureSpace(24, context: pdfContext, cursorY: &cursorY, pageNumber: &pageNumber, headerTitle: headerTitle, headerSubtitle: subtitleText)

                    // Repeat header after page break
                    if cursorY <= marginV + headerHeight + 24 {
                        drawTableRow(context: cgContext, columns: sessionColumns, y: cursorY, font: fontMedium(11), color: textSecondary)
                        cursorY += 24
                    }

                    let dateStr = shortDateFormatter.string(from: session.sessionDate)
                    let sport = session.sportType.displayName
                    let duration = String(format: "%.0f min", session.durationMinutes)
                    let rpe = session.sessionRPE.map { String(format: "%.0f", $0) } ?? "--"
                    let load = String(format: "%.0f", session.internalLoad)
                    let acwr: String
                    if session.chronicLoad > 0 {
                        acwr = String(format: "%.2f", session.acuteLoad / session.chronicLoad)
                    } else {
                        acwr = "--"
                    }

                    let rowData: [(text: String, width: CGFloat)] = [
                        (dateStr, 90),
                        (sport, 150),
                        (duration, 70),
                        (rpe, 50),
                        (load, 70),
                        (acwr, 86)
                    ]
                    drawTableRow(context: cgContext, columns: rowData, y: cursorY, font: fontRegular(13), color: textPrimary)
                    cursorY += 24
                }
            }
            cursorY += 32

            // -- Personal Records
            ensureSpace(80, context: pdfContext, cursorY: &cursorY, pageNumber: &pageNumber, headerTitle: headerTitle, headerSubtitle: subtitleText)
            drawText("PERSONAL RECORDS", in: CGRect(x: marginH, y: cursorY, width: contentWidth, height: 24), font: fontMedium(17), color: textPrimary)
            cursorY += 32

            let prColumns: [(text: String, width: CGFloat)] = [
                ("EXERCISE", 200),
                ("TYPE", 80),
                ("VALUE", 120),
                ("DATE", 116)
            ]

            if personalRecords.isEmpty {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: fontRegular(13),
                    .foregroundColor: textSecondary,
                    .obliqueness: 0.15
                ]
                let fallback = NSAttributedString(string: "No personal records achieved in this period.", attributes: attrs)
                fallback.draw(in: CGRect(x: marginH, y: cursorY, width: contentWidth, height: 20))
                cursorY += 24
            } else {
                drawTableRow(context: cgContext, columns: prColumns, y: cursorY, font: fontMedium(11), color: textSecondary)
                cursorY += 24

                let sortedPRs = personalRecords.sorted { $0.achievedAt < $1.achievedAt }
                for pr in sortedPRs {
                    ensureSpace(24, context: pdfContext, cursorY: &cursorY, pageNumber: &pageNumber, headerTitle: headerTitle, headerSubtitle: subtitleText)

                    if cursorY <= marginV + headerHeight + 24 {
                        drawTableRow(context: cgContext, columns: prColumns, y: cursorY, font: fontMedium(11), color: textSecondary)
                        cursorY += 24
                    }

                    let rowData: [(text: String, width: CGFloat)] = [
                        (pr.exerciseName, 200),
                        (pr.recordType.displayName, 80),
                        (String(format: "%.1f", pr.value), 120),
                        (shortDateFormatter.string(from: pr.achievedAt), 116)
                    ]
                    drawTableRow(context: cgContext, columns: rowData, y: cursorY, font: fontRegular(13), color: textPrimary)
                    cursorY += 24
                }
            }

            // -- Footer on final page
            drawFooter(context: cgContext, pageNumber: pageNumber)
        }
    }

    // MARK: - Coach Roster Report (EXPRT-02)

    /// Generates a PDF roster summary for a coach showing all linked athletes.
    ///
    /// Includes a table with each athlete's recovery score, ACWR zone, session count,
    /// streak, and overreaching flag.
    ///
    /// - Parameters:
    ///   - coachName: The coach's display name
    ///   - athletes: Array of roster data for each athlete
    ///   - dateRange: The reporting time window
    /// - Returns: PDF file data
    static func generateCoachRosterReport(
        coachName: String,
        athletes: [RosterAthleteData],
        dateRange: ReportDateRange
    ) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let endDate = Date.now
        let startDate = Calendar.current.date(byAdding: .day, value: -dateRange.days, to: endDate) ?? endDate
        let subtitleText = "\(coachName) | \(dateFormatter.string(from: startDate)) - \(dateFormatter.string(from: endDate))"
        let headerTitle = "Roster Summary"

        let rosterColumns: [(text: String, width: CGFloat)] = [
            ("ATHLETE", 140),
            ("RECOVERY", 80),
            ("ZONE", 70),
            ("SESSIONS", 80),
            ("STREAK", 70),
            ("FLAG", 76)
        ]

        return renderer.pdfData { pdfContext in
            var pageNumber = 1
            var cursorY: CGFloat = marginV + headerHeight + 16

            pdfContext.beginPage()
            let cgContext = pdfContext.cgContext
            drawHeader(context: cgContext, title: headerTitle, subtitle: subtitleText)

            // Table header
            drawTableRow(context: cgContext, columns: rosterColumns, y: cursorY, font: fontMedium(11), color: textSecondary)
            cursorY += 24

            if athletes.isEmpty {
                drawText("No athletes linked to this account.", in: CGRect(x: marginH, y: cursorY, width: contentWidth, height: 20), font: fontRegular(13), color: textSecondary)
                cursorY += 24
            } else {
                for athlete in athletes {
                    ensureSpace(24, context: pdfContext, cursorY: &cursorY, pageNumber: &pageNumber, headerTitle: headerTitle, headerSubtitle: subtitleText)

                    if cursorY <= marginV + headerHeight + 24 {
                        drawTableRow(context: cgContext, columns: rosterColumns, y: cursorY, font: fontMedium(11), color: textSecondary)
                        cursorY += 24
                    }

                    let recoveryText = athlete.recoveryScore.map { String(format: "%.0f", $0) } ?? "--"
                    let zoneText = athlete.acwrZone.displayName

                    let rowData: [(text: String, width: CGFloat)] = [
                        (athlete.name, 140),
                        (recoveryText, 80),
                        (zoneText, 70),
                        ("\(athlete.sessionsCount)", 80),
                        ("\(athlete.streakCount)", 70),
                        (athlete.isOverreaching ? "!" : "", 76)
                    ]

                    let rowColor = athlete.isOverreaching ? zoneDanger : textPrimary
                    drawTableRow(context: cgContext, columns: rowData, y: cursorY, font: fontRegular(13), color: rowColor)

                    cursorY += 24
                }
            }

            drawFooter(context: cgContext, pageNumber: pageNumber)
        }
    }

    // MARK: - Private Drawing Helpers

    /// Draws text using NSAttributedString with paragraph style.
    private static func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attrs)
        attributedString.draw(in: rect)
    }

    /// Draws a 0.5pt horizontal hairline across the content width.
    private static func drawHairline(context: CGContext, y: CGFloat) {
        context.setStrokeColor(dividerColor.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: marginH, y: y))
        context.addLine(to: CGPoint(x: marginH + contentWidth, y: y))
        context.strokePath()
    }

    /// Draws the branded page header with title left and subtitle right.
    private static func drawHeader(context: CGContext, title: String, subtitle: String) {
        // "Faros" wordmark top-left
        drawText("Tutrice", in: CGRect(x: marginH, y: marginV, width: 200, height: 24), font: fontMedium(15), color: textPrimary)

        // Title below wordmark
        drawText(title, in: CGRect(x: marginH, y: marginV + 20, width: 200, height: 24), font: fontMedium(24), color: textPrimary)

        // Subtitle top-right
        drawText(subtitle, in: CGRect(x: marginH + 200, y: marginV + 8, width: contentWidth - 200, height: 20), font: fontRegular(13), color: textSecondary, alignment: .right)

        // Hairline below header
        drawHairline(context: context, y: marginV + headerHeight)
    }

    /// Draws page footer with page number left and branding right.
    private static func drawFooter(context: CGContext, pageNumber: Int) {
        let footerY = pageHeight - marginV - footerHeight
        drawHairline(context: context, y: footerY)
        drawText("Page \(pageNumber)", in: CGRect(x: marginH, y: footerY + 4, width: 100, height: 20), font: fontRegular(11), color: textSecondary)
        drawText("Generated by Tutrice", in: CGRect(x: marginH + 100, y: footerY + 4, width: contentWidth - 100, height: 20), font: fontRegular(11), color: textSecondary, alignment: .right)
    }

    /// Checks remaining page space and begins a new page if needed.
    private static func ensureSpace(
        _ needed: CGFloat,
        context: UIGraphicsPDFRendererContext,
        cursorY: inout CGFloat,
        pageNumber: inout Int,
        headerTitle: String,
        headerSubtitle: String
    ) {
        let maxY = pageHeight - marginV - footerHeight
        guard cursorY + needed > maxY else { return }

        // Draw footer on current page
        drawFooter(context: context.cgContext, pageNumber: pageNumber)

        // Begin new page
        context.beginPage()
        pageNumber += 1
        drawHeader(context: context.cgContext, title: headerTitle, subtitle: headerSubtitle)
        cursorY = marginV + headerHeight + 16
    }

    /// Draws a simple line chart within the given rect using Core Graphics.
    private static func drawLineChart(
        context: CGContext,
        rect: CGRect,
        dataPoints: [(date: Date, value: Double)],
        strokeColor: CGColor,
        lineWidth: CGFloat = 1.5
    ) {
        guard dataPoints.count >= 2 else { return }

        let minValue = dataPoints.map(\.value).min() ?? 0
        let maxValue = dataPoints.map(\.value).max() ?? 100
        let valueRange = max(maxValue - minValue, 1)

        guard let firstDate = dataPoints.first?.date,
              let lastDate = dataPoints.last?.date else { return }

        let dateRange = lastDate.timeIntervalSince(firstDate)
        guard dateRange > 0 else { return }

        let chartPadding: CGFloat = 8
        let drawableWidth = rect.width - chartPadding * 2
        let drawableHeight = rect.height - chartPadding * 2

        context.saveGState()
        context.setStrokeColor(strokeColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        let path = CGMutablePath()
        for (index, point) in dataPoints.enumerated() {
            let xFraction = CGFloat(point.date.timeIntervalSince(firstDate) / dateRange)
            let yFraction = CGFloat((point.value - minValue) / valueRange)
            let x = rect.minX + chartPadding + xFraction * drawableWidth
            let y = rect.maxY - chartPadding - yFraction * drawableHeight

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.addPath(path)
        context.strokePath()
        context.restoreGState()
    }

    /// Draws a single table row with column data and a bottom hairline.
    private static func drawTableRow(
        context: CGContext,
        columns: [(text: String, width: CGFloat)],
        y: CGFloat,
        font: UIFont,
        color: UIColor,
        rowHeight: CGFloat = 24
    ) {
        var x = marginH
        for column in columns {
            let cellRect = CGRect(x: x, y: y, width: column.width, height: rowHeight)
            drawText(column.text, in: cellRect, font: font, color: color)
            x += column.width
        }
        drawHairline(context: context, y: y + rowHeight)
    }
}

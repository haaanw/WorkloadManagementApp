import Foundation

/// Handles weight unit display conversion.
/// Internal storage is always in kg; display converts to user preference.
/// Locale-aware via `MeasurementFormatter` — pass `@Environment(\.locale)` from Views.
struct WeightFormatter {
    private static let kgToLbs = 2.20462

    /// Format weight in user's preferred unit. The numeric portion is locale-aware
    /// (decimal separator, digit grouping); the unit *symbol* is rendered by
    /// `MeasurementFormatter` with `.providedUnit`, which on zh-Hans typically
    /// produces "千克"/"磅" rather than "kg"/"lb". If product wants stable
    /// "kg"/"lb" everywhere, append the unit manually instead.
    static func display(_ kg: Double, unit: WeightUnit, locale: Locale) -> String {
        let measurement: Measurement<UnitMass>
        switch unit {
        case .kg:  measurement = Measurement(value: kg, unit: .kilograms)
        case .lbs: measurement = Measurement(value: kg, unit: .pounds)
        }
        let mf = MeasurementFormatter()
        mf.locale = locale
        mf.unitStyle = .medium
        mf.unitOptions = .providedUnit
        mf.numberFormatter.maximumFractionDigits = 1
        mf.numberFormatter.minimumFractionDigits = 1
        return mf.string(from: measurement)
    }

    /// Convert from display unit to kg for storage (no locale needed; numeric only).
    static func toKg(_ value: Double, from unit: WeightUnit) -> Double {
        switch unit {
        case .kg: return value
        case .lbs: return value / kgToLbs
        }
    }

    /// Snap a numeric value to the nearest multiple of `step` (pure, locale-free).
    /// Used by the weight block picker so display values land on clean increments
    /// (e.g. 2.5 kg / 5 lb). Operates in whatever unit the caller passes; storage
    /// conversion to kg happens separately via `toKg`.
    static func snapToIncrement(_ value: Double, to step: Double) -> Double {
        guard step > 0 else { return value }
        return (value / step).rounded() * step
    }

    /// Snap a numeric value DOWN to a multiple of `step` (floor; pure, locale-free).
    /// Used when the value is a hard upper bound (e.g. a trimmed/capped top-set weight):
    /// nearest-snapping could round back UP past the bound, floor-snapping never can.
    /// The tiny epsilon absorbs float error so a value mathematically ON a plate multiple
    /// (e.g. 100 × 0.95 = 95.0) never drops a whole step.
    static func floorToIncrement(_ value: Double, to step: Double) -> Double {
        guard step > 0 else { return value }
        return ((value / step) + 1e-9).rounded(.down) * step
    }

    /// Display value without unit label (no locale needed; numeric only).
    static func displayValue(_ kg: Double, unit: WeightUnit) -> Double {
        switch unit {
        case .kg: return kg
        case .lbs: return kg * kgToLbs
        }
    }

    /// The bare numeral in the athlete's unit — no unit symbol, a trailing `.0` dropped.
    /// The set-spec strings ("5 × 5 @ 100 kg") carry ONE unit symbol for a whole list of
    /// numerals, so they need the numeral alone.
    static func displayNumeral(_ kg: Double, unit: WeightUnit) -> String {
        let value = displayValue(kg, unit: unit)
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    /// Format volume (load × reps) for display, locale-aware and CONVERTED into the
    /// athlete's unit — an lb athlete reads pounds, not a kilogram number relabelled.
    static func displayVolume(_ volumeKg: Double, unit: WeightUnit, locale: Locale) -> String {
        let value = displayValue(volumeKg, unit: unit)
        let measurement: Measurement<UnitMass>
        switch unit {
        case .kg:  measurement = Measurement(value: value, unit: .kilograms)
        case .lbs: measurement = Measurement(value: value, unit: .pounds)
        }
        let mf = MeasurementFormatter()
        mf.locale = locale
        mf.unitStyle = .medium
        mf.unitOptions = .providedUnit
        mf.numberFormatter.maximumFractionDigits = 0
        mf.numberFormatter.minimumFractionDigits = 0
        return mf.string(from: measurement)
    }

    /// Format a distance STORED IN METRES in the athlete's system — kilometres for a metric
    /// athlete, miles for an imperial one (v1.7.3 · UAT round 3 · U22).
    ///
    /// `WeightUnit` is the only unit preference the athlete has on file, so it carries the
    /// choice of measurement system for distance too. Inventing a second preference would
    /// be a settings screen for a question the athlete has already answered.
    static func displayDistance(_ meters: Double, unit: WeightUnit, locale: Locale) -> String {
        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        let converted: Measurement<UnitLength>
        switch unit {
        case .kg:  converted = measurement.converted(to: .kilometers)
        case .lbs: converted = measurement.converted(to: .miles)
        }
        let mf = MeasurementFormatter()
        mf.locale = locale
        mf.unitStyle = .medium
        mf.unitOptions = .providedUnit
        mf.numberFormatter.maximumFractionDigits = 1
        mf.numberFormatter.minimumFractionDigits = 1
        return mf.string(from: converted)
    }
}

// MARK: - Session work reading (v1.7.3 · UAT round 3 · U22)

/// The ONE honest label for what a session's work was.
///
/// `WorkoutSession.totalVolume` means two different things depending on the session
/// (`WorkoutSession.volumeIsDistance`), and a third kind of session — a bare watch skill
/// import with no sets at all — has no external work on file but does carry an sRPE load.
/// Three meanings, one stored field: every render site asked the field directly and two of
/// them printed a literal " kg", so a 1.1 km walk read "1106 kg" in history (U22).
///
/// Sites call `label(for:unit:locale:)` and print what comes back. There is no path from a
/// view to the raw number any more, which is what stops the unit from drifting back.
enum SessionWorkReading {

    /// The reading, or `nil` when the session carries no external work AND no sRPE load —
    /// in which case the row simply shows no work cell rather than a zero.
    static func label(for session: WorkoutSession, unit: WeightUnit, locale: Locale) -> String? {
        if session.totalVolume > 0 {
            if session.volumeIsDistance {
                return WeightFormatter.displayDistance(session.totalVolume, unit: unit, locale: locale)
            }
            return WeightFormatter.displayVolume(session.totalVolume, unit: unit, locale: locale)
        }
        guard session.internalLoad > 0 else { return nil }
        return String(
            format: String(localized: "session.reading.load", defaultValue: "LOAD %lld AU"),
            Int(session.internalLoad.rounded())
        )
    }

    /// The key that NAMES the reading — "Volume", "Distance" or "Load". A number whose unit
    /// changes with the session needs its name to change with it too.
    static func title(for session: WorkoutSession) -> String {
        guard session.totalVolume > 0 else {
            return String(localized: "metric.load", defaultValue: "Load")
        }
        return session.volumeIsDistance
            ? String(localized: "metric.distance", defaultValue: "Distance")
            : String(localized: "metric.volume", defaultValue: "Volume")
    }
}

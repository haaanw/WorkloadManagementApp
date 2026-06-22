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

    /// Display value without unit label (no locale needed; numeric only).
    static func displayValue(_ kg: Double, unit: WeightUnit) -> Double {
        switch unit {
        case .kg: return kg
        case .lbs: return kg * kgToLbs
        }
    }

    /// Format volume (kg × reps) for display, locale-aware.
    static func displayVolume(_ volumeKg: Double, unit: WeightUnit, locale: Locale) -> String {
        let measurement: Measurement<UnitMass>
        switch unit {
        case .kg:  measurement = Measurement(value: volumeKg, unit: .kilograms)
        case .lbs: measurement = Measurement(value: volumeKg, unit: .pounds)
        }
        let mf = MeasurementFormatter()
        mf.locale = locale
        mf.unitStyle = .medium
        mf.unitOptions = .providedUnit
        mf.numberFormatter.maximumFractionDigits = 0
        mf.numberFormatter.minimumFractionDigits = 0
        return mf.string(from: measurement)
    }
}

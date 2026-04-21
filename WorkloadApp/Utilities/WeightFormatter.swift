import Foundation

/// Handles weight unit display conversion.
/// Internal storage is always in kg; display converts to user preference.
struct WeightFormatter {
    private static let kgToLbs = 2.20462

    /// Convert kg to the user's preferred display unit
    static func display(_ kg: Double, unit: WeightUnit) -> String {
        switch unit {
        case .kg:
            return String(format: "%.1f kg", kg)
        case .lbs:
            return String(format: "%.1f lbs", kg * kgToLbs)
        }
    }

    /// Convert from display unit to kg for storage
    static func toKg(_ value: Double, from unit: WeightUnit) -> Double {
        switch unit {
        case .kg: return value
        case .lbs: return value / kgToLbs
        }
    }

    /// Display value without unit label
    static func displayValue(_ kg: Double, unit: WeightUnit) -> Double {
        switch unit {
        case .kg: return kg
        case .lbs: return kg * kgToLbs
        }
    }

    /// Format volume (kg × reps) for display
    static func displayVolume(_ volumeKg: Double, unit: WeightUnit) -> String {
        switch unit {
        case .kg:
            return String(format: "%.0f kg", volumeKg)
        case .lbs:
            return String(format: "%.0f lbs", volumeKg * kgToLbs)
        }
    }
}

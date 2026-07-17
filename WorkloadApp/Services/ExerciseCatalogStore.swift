import Foundation

// MARK: - CatalogExercise

/// One record of the bundled movement-bank catalog (`ExerciseCatalog.json`).
///
/// `muscleGroup` / `category` are kept as raw strings so a future catalog
/// revision with unknown values still decodes; the typed accessors below
/// apply safe fallbacks.
struct CatalogExercise: Codable, Identifiable, Hashable {
    /// Bilingual instruction steps.
    struct Steps: Codable, Hashable {
        let en: [String]
        let zh: [String]
    }

    let id: String
    let name: String
    let bodyPart: String
    let equipment: String
    let target: String
    let muscleGroup: String
    let category: String
    let secondaryMuscles: [String]
    let steps: Steps

    /// Decoded `MuscleGroup`; unknown rawValues fall back to `.fullBody`.
    var muscleGroupValue: MuscleGroup? {
        MuscleGroup(rawValue: muscleGroup) ?? .fullBody
    }

    /// Decoded `ExerciseCategory`; unknown rawValues fall back to `.compound`.
    var categoryValue: ExerciseCategory {
        ExerciseCategory(rawValue: category) ?? .compound
    }

    /// Instruction steps in the app's active language (zh when the app runs
    /// Chinese, else en).
    func localizedSteps() -> [String] {
        ExerciseCatalogStore.prefersChinese ? steps.zh : steps.en
    }
}

// MARK: - ExerciseCatalogStore

/// Loads and indexes the bundled exercise catalog (1,324 gym movements).
///
/// Pure static store: the JSON is decoded exactly once (Swift `static let`
/// is lazy and thread-safe), and every search pass runs over a precomputed
/// case/diacritic-folded index — never re-decoding per keystroke or view init.
enum ExerciseCatalogStore {

    // MARK: - Catalog loading (one-time)

    /// The full decoded catalog. Decoded once on first access.
    static let catalog: [CatalogExercise] = {
        guard let url = Bundle.main.url(forResource: "ExerciseCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([CatalogExercise].self, from: data) else {
            #if DEBUG
            print("ExerciseCatalogStore: failed to load ExerciseCatalog.json from bundle")
            #endif
            return []
        }
        return decoded
    }()

    // MARK: - Search index (precomputed)

    private struct IndexEntry {
        let exercise: CatalogExercise
        /// Folded "name equipment target" — the string search scans.
        let key: String
        let region: MuscleRegion?
        /// Folded equipment for facet filtering.
        let equipmentKey: String
    }

    private static let index: [IndexEntry] = catalog.map { exercise in
        IndexEntry(
            exercise: exercise,
            key: fold("\(exercise.name) \(exercise.equipment) \(exercise.target)"),
            region: exercise.muscleGroupValue?.region,
            equipmentKey: fold(exercise.equipment)
        )
    }

    /// Case-insensitive name → record lookup table (first record wins on duplicates).
    private static let byFoldedName: [String: CatalogExercise] = {
        var map: [String: CatalogExercise] = [:]
        map.reserveCapacity(catalog.count)
        for exercise in catalog where map[fold(exercise.name)] == nil {
            map[fold(exercise.name)] = exercise
        }
        return map
    }()

    // MARK: - Facets

    /// Distinct equipment values ordered by descending frequency
    /// (ties broken alphabetically for stable ordering).
    static let equipmentFacets: [String] = {
        var counts: [String: Int] = [:]
        var display: [String: String] = [:]
        for exercise in catalog {
            let key = fold(exercise.equipment)
            counts[key, default: 0] += 1
            if display[key] == nil { display[key] = exercise.equipment }
        }
        return counts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .compactMap { display[$0.key] }
    }()

    /// Catalog grouped by muscle region via `MuscleGroup.region`.
    static let byRegion: [MuscleRegion: [CatalogExercise]] = {
        Dictionary(grouping: catalog) { $0.muscleGroupValue?.region ?? .fullBody }
    }()

    // MARK: - Search

    /// Case/diacritic-insensitive catalog search.
    ///
    /// All whitespace-separated query tokens must be contained in the record's
    /// prebuilt index string (token AND-match), so "bench barbell" finds
    /// "Barbell Bench Press". An empty query returns the (facet-filtered)
    /// catalog unchanged.
    static func search(
        query: String,
        region: MuscleRegion? = nil,
        equipment: String? = nil
    ) -> [CatalogExercise] {
        let equipmentKey = equipment.map(fold)
        let tokens = fold(query)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        var results: [CatalogExercise] = []
        for entry in index {
            if let region, entry.region != region { continue }
            if let equipmentKey, entry.equipmentKey != equipmentKey { continue }
            if !tokens.allSatisfy({ entry.key.contains($0) }) { continue }
            results.append(entry.exercise)
        }
        return results
    }

    /// Case-insensitive lookup of a catalog record by exercise name, so detail
    /// views can find instructions for a picked name.
    static func entry(named name: String) -> CatalogExercise? {
        byFoldedName[fold(name)]
    }

    // MARK: - Picker integration

    /// The full catalog converted into picker `ExerciseDefinition`s (built once).
    static let catalogDefinitions: [ExerciseDefinition] = catalog.map { exercise in
        ExerciseDefinition(
            name: exercise.name,
            category: exercise.categoryValue,
            muscleGroup: exercise.muscleGroupValue,
            isCustom: false,
            equipment: exercise.equipment,
            catalogID: exercise.id
        )
    }

    /// Applies user overrides to a built definition list: drops hidden entries
    /// and swaps remapped muscle group / category. Name match is case-insensitive.
    static func applying(
        overrides: [ExerciseOverride],
        to defs: [ExerciseDefinition]
    ) -> [ExerciseDefinition] {
        guard !overrides.isEmpty else { return defs }
        var overrideMap: [String: ExerciseOverride] = [:]
        for override in overrides {
            overrideMap[fold(override.exerciseName)] = override
        }
        var results: [ExerciseDefinition] = []
        results.reserveCapacity(defs.count)
        for def in defs {
            guard let override = overrideMap[fold(def.name)] else {
                results.append(def)
                continue
            }
            if override.isHidden { continue }
            var updated = def
            if let muscleGroup = override.muscleGroup { updated.muscleGroup = muscleGroup }
            if let category = override.exerciseCategory { updated.category = category }
            results.append(updated)
        }
        return results
    }

    // MARK: - Locale

    /// Whether the app is running in Chinese. Mirrors `LocaleManager`'s
    /// resolution order (explicit user pick persisted in UserDefaults first,
    /// then system language) without requiring main-actor access.
    static var prefersChinese: Bool {
        if let stored = UserDefaults.standard.string(forKey: "selectedLocaleIdentifier") {
            return stored.hasPrefix("zh")
        }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("zh-Hans") || preferred.hasPrefix("zh-CN")
    }

    // MARK: - Helpers

    /// Case + diacritic folding with a stable locale so the index and every
    /// query normalize identically.
    private static func fold(_ string: String) -> String {
        string.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }
}

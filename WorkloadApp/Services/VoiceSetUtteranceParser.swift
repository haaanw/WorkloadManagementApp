import Foundation

/// Fast, deterministic, local parse of a single spoken set-logging utterance
/// ("bench press eight reps at eighty", "same weight", "八次八十公斤").
///
/// This is the LOCAL fast path for live incremental voice logging: no network,
/// no LLM. When the utterance is not confidently understood, `parse` returns
/// `nil` and the caller falls back to the LLM-backed parser. It never guesses
/// a value it is not confident about — silence (`nil`) beats a wrong number.
enum VoiceSetUtteranceParser {

    // MARK: - Public API

    struct Result: Equatable {
        var exerciseName: String?     // leading exercise words if spoken, else nil (caller resolves/routes)
        var reps: Int?
        var weightKg: Double?         // ALWAYS kilograms after conversion
        var durationSeconds: Int?
        var rpe: Double?
        var sameWeight: Bool          // "same weight" / "same as last" / "一样" / "同样重量" spoken
        var repeatLast: Bool          // "add a set" / "another set" / "same again" / "再来一组" / "再一组"
    }

    /// - Parameter weightUnit: the athlete's display preference — a spoken bare number with
    ///   NO unit word is interpreted in this unit and converted to kg. An explicit spoken
    ///   unit (kg/lbs/公斤/磅) always wins over this preference.
    static func parse(_ utterance: String, weightUnit: WeightUnit) -> Result? {
        let trimmedRaw = utterance.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRaw.isEmpty else { return nil }

        let normalized = normalize(trimmedRaw)
        guard !normalized.isEmpty else { return nil }

        // Multi-set shorthand is the LLM path's job, never guess a sets×reps split locally.
        if firstMatch(multiSetOfRegex, in: normalized) != nil { return nil }
        if firstMatch(ambiguousByXRegex, in: normalized) != nil { return nil }

        var result = Result(
            exerciseName: nil,
            reps: nil,
            weightKg: nil,
            durationSeconds: nil,
            rpe: nil,
            sameWeight: containsAny(normalized, sameWeightKeywords),
            repeatLast: containsAny(normalized, repeatLastKeywords)
        )

        let earliestLocation = earliestTriggerLocation(in: normalized)

        var working = normalized

        // RPE — extracted (and removed) first so its digits are never mistaken for reps/weight.
        if let groups = extractFirstMatch(rpeRegex, from: &working) {
            if let value = Double(groups[0]), rpeRange.contains(value) { result.rpe = value }
        } else if let groups = extractFirstMatch(feltLikeRegex, from: &working) {
            if let value = Double(groups[0]), rpeRange.contains(value) { result.rpe = value }
        }

        // Duration
        if let groups = extractFirstMatch(durationEnRegex, from: &working) {
            if let value = Double(groups[0]) {
                result.durationSeconds = seconds(forValue: value, englishUnitWord: groups[1])
            }
        } else if let groups = extractFirstMatch(durationZhRegex, from: &working) {
            if let value = Double(groups[0]) {
                result.durationSeconds = seconds(forValue: value, chineseUnitWord: groups[1])
            }
        }

        // Weight with an explicit unit — always wins over the athlete's display preference.
        if let groups = extractFirstMatch(weightExplicitEnRegex, from: &working) {
            if let value = Double(groups[0]) {
                result.weightKg = kilograms(forValue: value, unitWord: groups[1])
            }
        } else if let groups = extractFirstMatch(weightExplicitZhRegex, from: &working) {
            if let value = Double(groups[0]) {
                result.weightKg = kilograms(forValue: value, unitWord: groups[1])
            }
        }

        // Reps
        if let groups = extractFirstMatch(repsExplicitEnRegex, from: &working) {
            result.reps = Int(groups[0])
        } else if let groups = extractFirstMatch(repsExplicitZhRegex, from: &working) {
            result.reps = Int(groups[0])
        } else if let groups = extractFirstMatch(repsForRegex, from: &working) {
            result.reps = Int(groups[0])
        }

        // Weight with no unit word — interpret in the athlete's display preference.
        if result.weightKg == nil, let groups = extractFirstMatch(weightImplicitRegex, from: &working) {
            if let value = Double(groups[0]) {
                result.weightKg = value * weightUnit.conversionToKg
            }
        }

        if let location = earliestLocation, location > 0 {
            let leading = (normalized as NSString).substring(to: location)
            let cleaned = leading.trimmingCharacters(in: .whitespaces)
            result.exerciseName = cleaned.isEmpty ? nil : cleaned
        }

        let hasQuantity = result.reps != nil
            || result.weightKg != nil
            || result.durationSeconds != nil
            || result.rpe != nil
        guard hasQuantity || result.sameWeight || result.repeatLast else { return nil }

        return result
    }

    // MARK: - Normalization

    /// Lowercases, folds diacritics, strips filler words/punctuation, and converts
    /// every spoken number (English words or Chinese numerals) to plain digits so
    /// every later regex only ever has to deal with arabic numbers.
    private static func normalize(_ input: String) -> String {
        var s = input
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()

        for filler in chineseFillerCharacters {
            s = s.replacingOccurrences(of: filler, with: "")
        }

        s = s.replacingOccurrences(of: #"[,，、！!?？；;:：]"#, with: " ", options: .regularExpression)
        // Drop stray sentence-ending periods, but never a decimal point flanked by digits.
        s = s.replacingOccurrences(of: #"(?<!\d)\.(?!\d)"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "-", with: " ")
        s = s.replacingOccurrences(of: #"\b(uh|um|er)\b"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        guard !s.isEmpty else { return "" }

        s = convertChineseNumerals(in: s)
        s = convertEnglishNumberWords(in: s)
        return s
    }

    private static let chineseFillerCharacters = ["了", "的", "呃", "嗯"]

    // MARK: - Chinese Numeral Conversion

    /// Converts runs of 零一二三四五六七八九十百千 to digits, e.g. "八十" → "80", "一百零五" → "105".
    private static func convertChineseNumerals(in text: String) -> String {
        let matches = chineseNumeralRunRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard !matches.isEmpty else { return text }

        var result = text
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let run = String(result[range])
            if let value = parseChineseNumeralRun(run) {
                result.replaceSubrange(range, with: String(value))
            }
        }
        return result
    }

    private static let chineseDigitMap: [Character: Int] = [
        "零": 0, "一": 1, "二": 2, "三": 3, "四": 4,
        "五": 5, "六": 6, "七": 7, "八": 8, "九": 9
    ]
    private static let chineseUnitMap: [Character: Int] = ["十": 10, "百": 100, "千": 1000]

    private static func parseChineseNumeralRun(_ run: String) -> Int? {
        var total = 0
        var section = 0
        var matchedAny = false

        for char in run {
            if let digit = chineseDigitMap[char] {
                section = digit
                matchedAny = true
            } else if let unit = chineseUnitMap[char] {
                section = section == 0 ? 1 : section
                total += section * unit
                section = 0
                matchedAny = true
            }
        }
        total += section
        return matchedAny ? total : nil
    }

    // MARK: - English Number Word Conversion

    private static let onesWords: [String: Int] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
        "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13,
        "fourteen": 14, "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19
    ]
    private static let tensWords: [String: Int] = [
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
        "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90
    ]

    /// Replaces runs of English number words ("twenty five", "a hundred", "eight") with digits.
    private static func convertEnglishNumberWords(in text: String) -> String {
        let tokens = text.split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return text }

        var output: [String] = []
        var index = 0
        while index < tokens.count {
            if let (value, length) = numberWordRun(tokens, startingAt: index) {
                output.append(String(value))
                index += length
            } else {
                output.append(tokens[index])
                index += 1
            }
        }
        return output.joined(separator: " ")
    }

    /// Greedily consumes a maximal run of number words starting at `index`, e.g.
    /// ["one", "hundred", "five"] → (105, 3). Returns `nil` when `index` is not
    /// the start of a number word (bare "a"/"an" is only a number start when
    /// immediately followed by "hundred", so "add a set" is never misread as "1 set").
    private static func numberWordRun(_ tokens: [String], startingAt index: Int) -> (value: Int, length: Int)? {
        guard index < tokens.count else { return nil }
        let first = tokens[index]
        let isArticleHundred = (first == "a" || first == "an")
            && index + 1 < tokens.count
            && tokens[index + 1] == "hundred"
        guard onesWords[first] != nil || tensWords[first] != nil || isArticleHundred else { return nil }

        var i = index
        var current = 0
        while i < tokens.count {
            let token = tokens[i]
            if let value = onesWords[token] {
                current += value
                i += 1
            } else if let value = tensWords[token] {
                current += value
                i += 1
            } else if token == "hundred" {
                current = current == 0 ? 100 : current * 100
                i += 1
            } else if (token == "a" || token == "an"), i + 1 < tokens.count, tokens[i + 1] == "hundred" {
                current += 1
                i += 1
            } else {
                break
            }
        }
        return (current, i - index)
    }

    // MARK: - Regex Patterns

    private static let rpeRegex = try! NSRegularExpression(pattern: #"rpe\s*(\d+(?:\.\d+)?)"#)
    private static let feltLikeRegex = try! NSRegularExpression(pattern: #"felt\s*like\s*a?\s*(\d+(?:\.\d+)?)"#)

    private static let durationEnRegex = try! NSRegularExpression(
        pattern: #"(\d+(?:\.\d+)?)\s*(seconds|second|secs|sec|minutes|minute|mins|min)\b"#
    )
    private static let durationZhRegex = try! NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*(分钟|秒)"#)

    private static let weightExplicitEnRegex = try! NSRegularExpression(
        pattern: #"(\d+(?:\.\d+)?)\s*(kilograms|kilogram|kilos|kilo|kgs|kg|pounds|pound|lbs|lb)\b"#
    )
    private static let weightExplicitZhRegex = try! NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*(公斤|千克|磅)"#)
    private static let weightImplicitRegex = try! NSRegularExpression(pattern: #"\b(?:at|with)\s+(\d+(?:\.\d+)?)\b"#)

    private static let repsExplicitEnRegex = try! NSRegularExpression(pattern: #"\b(\d+)\s*reps?\b"#)
    private static let repsExplicitZhRegex = try! NSRegularExpression(pattern: #"(\d+)\s*(?:次|个)"#)
    private static let repsForRegex = try! NSRegularExpression(pattern: #"\bfor\s+(\d+)\b"#)

    // Reject: local parser only handles a single set. "3 sets of 8", "3x8", "8 by 80" all
    // read as sets×reps ambiguity and are handed to the LLM path instead of guessed at.
    private static let multiSetOfRegex = try! NSRegularExpression(pattern: #"\d+\s*sets?\s*of\s*\d+"#)
    private static let ambiguousByXRegex = try! NSRegularExpression(pattern: #"\b\d+\s*(?:x|by)\s*\d+\b"#)

    private static let chineseNumeralRunRegex = try! NSRegularExpression(pattern: "[零一二三四五六七八九十百千]+")

    private static let rpeRange = 1.0...10.0

    // MARK: - Keyword Vocabularies

    // Chinese numeral conversion runs before keyword matching, so any keyword containing a
    // bare 一 must be spelled in its post-conversion ("1") form here.
    private static let sameWeightKeywords: [String] = [
        "same weight",
        "same as last",
        "同样重量",
        "1样重量",
        "1样"
    ]
    private static let repeatLastKeywords: [String] = [
        "add a set",
        "another set",
        "same again",
        "再来1组",
        "再1组"
    ]

    private static let kgUnitWords: Set<String> = ["kilogram", "kilograms", "kilo", "kilos", "kg", "kgs", "公斤", "千克"]
    private static let lbUnitWords: Set<String> = ["pound", "pounds", "lb", "lbs", "磅"]

    // MARK: - Extraction Helpers

    private static func firstMatch(_ regex: NSRegularExpression, in text: String) -> NSTextCheckingResult? {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    }

    /// Finds the first match of `regex` in `text`, captures its groups, then removes the
    /// whole matched span from `text` so later extraction passes never re-read the same digits.
    private static func extractFirstMatch(_ regex: NSRegularExpression, from text: inout String) -> [String]? {
        guard let match = firstMatch(regex, in: text) else { return nil }

        var groups: [String] = []
        for i in 1..<match.numberOfRanges {
            if let range = Range(match.range(at: i), in: text) {
                groups.append(String(text[range]))
            } else {
                groups.append("")
            }
        }
        if let whole = Range(match.range, in: text) {
            text.removeSubrange(whole)
        }
        return groups
    }

    /// Earliest starting offset (UTF-16, matching `NSRange`) among every quantity/keyword
    /// trigger in `text` — everything before it is the spoken exercise name, if any.
    private static func earliestTriggerLocation(in text: String) -> Int? {
        var earliest: Int?
        func track(_ location: Int?) {
            guard let location else { return }
            if earliest == nil || location < earliest! { earliest = location }
        }

        track(firstMatch(rpeRegex, in: text)?.range.location)
        track(firstMatch(feltLikeRegex, in: text)?.range.location)
        track(firstMatch(durationEnRegex, in: text)?.range.location)
        track(firstMatch(durationZhRegex, in: text)?.range.location)
        track(firstMatch(weightExplicitEnRegex, in: text)?.range.location)
        track(firstMatch(weightExplicitZhRegex, in: text)?.range.location)
        track(firstMatch(repsExplicitEnRegex, in: text)?.range.location)
        track(firstMatch(repsExplicitZhRegex, in: text)?.range.location)
        track(firstMatch(repsForRegex, in: text)?.range.location)
        track(firstMatch(weightImplicitRegex, in: text)?.range.location)

        let ns = text as NSString
        for keyword in sameWeightKeywords + repeatLastKeywords {
            let range = ns.range(of: keyword)
            if range.location != NSNotFound { track(range.location) }
        }

        return earliest
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private static func kilograms(forValue value: Double, unitWord: String) -> Double {
        lbUnitWords.contains(unitWord) ? value * WeightUnit.lbs.conversionToKg : value
    }

    private static func seconds(forValue value: Double, englishUnitWord: String) -> Int {
        let isMinutes = englishUnitWord.hasPrefix("min")
        return Int((value * (isMinutes ? 60 : 1)).rounded())
    }

    private static func seconds(forValue value: Double, chineseUnitWord: String) -> Int {
        let isMinutes = chineseUnitWord == "分钟"
        return Int((value * (isMinutes ? 60 : 1)).rounded())
    }
}

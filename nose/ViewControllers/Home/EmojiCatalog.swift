import Foundation

/// Emoji picker data: single scalars bucketed by heuristic ranges, plus full regional flag pairs.
/// Category assignment is approximate (not CLDR-perfect).
///
/// `category(for:)` priority (first matching rule wins):
/// 1. **Travel** — narrow subranges (places, vehicles, transit, lodging); *not* the full U+1F680…U+1F6FF block.
/// 2. **Activities** — sports & games (overlaps with U+1F3xx shared with travel avoided by ordering).
/// 3. **Food** — food & drink (evaluated before Nature so fruit/drink scalars win).
/// 4. **Nature** — animals, plants, weather (no ranges duplicated under Food above).
/// 5. **People** — people, hands, body.
/// 6. **Smileys** — faces & emotion.
/// 7. **Transport & map remainder** — any U+1F680…U+1F6FF scalar not classified as Travel → **Objects** (signs, restrooms, shopping, etc.).
/// 8. **Symbols** — `isLikelySymbol` (arrows, dingbats, misc technical).
/// 9. **Default** — **Objects**.
enum EmojiCategory: String, CaseIterable, Identifiable {
    case smileys
    case people
    case nature
    case food
    case travel
    case activities
    case objects
    case symbols
    case flags

    var id: String { rawValue }

    /// Short English labels; swap for String(localized:) if you add strings to the catalog.
    var title: String {
        switch self {
        case .smileys: return "Smileys"
        case .people: return "People"
        case .nature: return "Nature"
        case .food: return "Food"
        case .travel: return "Places"
        case .activities: return "Activities"
        case .objects: return "Objects"
        case .symbols: return "Symbols"
        case .flags: return "Flags"
        }
    }
}

struct EmojiCategorySection {
    let category: EmojiCategory
    let emojis: [String]
}

enum EmojiCatalog {
    /// Lazily computed once; first access may take a short moment.
    static var categorizedSections: [EmojiCategorySection] {
        _lock.lock()
        defer { _lock.unlock() }
        if let cached = _cachedSections {
            return cached
        }
        let built = buildCategorizedSections()
        _cachedSections = built
        return built
    }

    private static var _cachedSections: [EmojiCategorySection]?
    private static let _lock = NSLock()

    private static func buildCategorizedSections() -> [EmojiCategorySection] {
        var buckets: [EmojiCategory: Set<String>] = Dictionary(uniqueKeysWithValues: EmojiCategory.allCases.map { ($0, Set()) })

        for codePoint in 0..<0x110000 {
            let u = UInt32(codePoint)
            guard let scalar = UnicodeScalar(u) else { continue }
            let props = scalar.properties
            guard props.isEmoji else { continue }
            if (0x1F1E6...0x1F1FF).contains(u) { continue }
            if (0x1F3FB...0x1F3FF).contains(u) { continue }

            let s = String(scalar)
            let cat = category(for: u)
            buckets[cat]?.insert(s)
        }

        buckets[.flags] = Set(buildFlagEmojis())

        return EmojiCategory.allCases.map { cat in
            let sorted = (buckets[cat] ?? []).sorted { a, b in
                let va = a.unicodeScalars.first?.value ?? 0
                let vb = b.unicodeScalars.first?.value ?? 0
                if va != vb { return va < vb }
                return a < b
            }
            return EmojiCategorySection(category: cat, emojis: sorted)
        }
    }

    /// Heuristic category; first matching rule wins (order matters). See file-level priority list above.
    private static func category(for codePoint: UInt32) -> EmojiCategory {
        // Travel & places (narrow — not full U+1F680…U+1F6FF; before activities — shared 0x1F3xx block)
        if isTravelCategory(codePoint) {
            return .travel
        }

        // Activities & sports
        if (0x1F3C0...0x1F3D3).contains(codePoint)
            || (0x1F396...0x1F397).contains(codePoint)
            || (0x26BD...0x26BE).contains(codePoint)
            || codePoint == 0x26F3
            || (0x26F8...0x26F9).contains(codePoint)
            || (0x1FA70...0x1FA7C).contains(codePoint) {
            return .activities
        }

        // Food & drink (before Nature — fruit/veg U+1F337…U+1F34C live here)
        if (0x1F32D...0x1F37F).contains(codePoint)
            || (0x1F950...0x1F96F).contains(codePoint)
            || codePoint == 0x2615
            || codePoint == 0x1F330 {
            return .food
        }

        // Nature (do not duplicate Food ranges — e.g. no U+1F337…U+1F34C here)
        if (0x1F400...0x1F43F).contains(codePoint)
            || (0x1F980...0x1F9AE).contains(codePoint)
            || (0x1FAB0...0x1FABD).contains(codePoint)
            || (0x1F332...0x1F335).contains(codePoint)
            || (0x1F384...0x1F393).contains(codePoint)
            || (0x1F30D...0x1F321).contains(codePoint)
            || (0x1F324...0x1F32C).contains(codePoint)
            || codePoint == 0x1F331
            || codePoint == 0x2618
            || (0x1F342...0x1F343).contains(codePoint)
            || codePoint == 0x1F308 {
            return .nature
        }

        // People & body
        if (0x1F466...0x1F469).contains(codePoint)
            || (0x1F474...0x1F475).contains(codePoint)
            || codePoint == 0x1F476 || codePoint == 0x1F477 || codePoint == 0x1F47C
            || (0x1F481...0x1F483).contains(codePoint)
            || (0x1F485...0x1F487).contains(codePoint)
            || (0x1F574...0x1F575).contains(codePoint)
            || codePoint == 0x1F57A
            || codePoint == 0x1F590
            || (0x1F595...0x1F596).contains(codePoint)
            || (0x1F645...0x1F647).contains(codePoint)
            || (0x1F64B...0x1F64F).contains(codePoint)
            || (0x1F918...0x1F91F).contains(codePoint)
            || codePoint == 0x1F926
            || (0x1F930...0x1F939).contains(codePoint)
            || (0x1F9B5...0x1F9B9).contains(codePoint)
            || (0x1F9CD...0x1F9DD).contains(codePoint)
            || (0x1F464...0x1F465).contains(codePoint)
            || (0x1F46A...0x1F46D).contains(codePoint)
            || (0x1F442...0x1F443).contains(codePoint)
            || (0x1F933...0x1F937).contains(codePoint)
            || (0x1F446...0x1F450).contains(codePoint)
            || (0x1F46E...0x1F47B).contains(codePoint)
            || codePoint == 0x1F47F {
            return .people
        }

        // Smileys & emotion
        if (0x1F600...0x1F64F).contains(codePoint)
            || (0x2639...0x263A).contains(codePoint)
            || (0x1F910...0x1F92F).contains(codePoint)
            || (0x1F970...0x1F976).contains(codePoint)
            || codePoint == 0x1F9D0
            || (0x1FAE0...0x1FAFF).contains(codePoint) {
            return .smileys
        }

        // Transport & map symbols block: everything not classified as Travel → Objects (signs, facilities, shopping, etc.)
        if (0x1F680...0x1F6FF).contains(codePoint) {
            return .objects
        }

        // Symbols (misc dingbats & arrows not caught above)
        if isLikelySymbol(codePoint) {
            return .symbols
        }

        return .objects
    }

    /// Narrow “travel / places” — vehicles, movement, airports, lodging & landmark buildings; excludes signage & restroom run.
    private static func isTravelCategory(_ u: UInt32) -> Bool {
        // Scenic places & buildings (Unicode “miscellaneous symbols and pictographs” / place subranges)
        if (0x1F3D4...0x1F3DF).contains(u) || (0x1F3E0...0x1F3F0).contains(u) || u == 0x1F5FA {
            return true
        }
        // Umbrella / ferry / motorboat (beach & water transport)
        if (0x26F1...0x26F2).contains(u) || (0x26F4...0x26F5).contains(u) {
            return true
        }
        // Vehicles & door through U+1F6AA (ends before NO ENTRY U+1F6AB)
        if (0x1F680...0x1F6AA).contains(u) {
            return true
        }
        // Bicycle, bus stop, mountain bike, person biking
        if (0x1F6B2...0x1F6B6).contains(u) {
            return true
        }
        // Airport: passport control, customs, baggage (not bath U+1F6C0 nor warning U+1F6C5)
        if (0x1F6C1...0x1F6C4).contains(u) {
            return true
        }
        // Lodging & places of worship (excludes shopping bags U+1F6CD, carts U+1F6D1–U+1F6D2)
        if u == 0x1F6CB || u == 0x1F6CC || u == 0x1F6CE || u == 0x1F6CF || u == 0x1F6D0
            || (0x1F6D3...0x1F6D7).contains(u) {
            return true
        }
        // Newer transport / construction vehicles (Unicode 14+)
        if (0x1F6DD...0x1F6DF).contains(u) || (0x1F6E0...0x1F6FC).contains(u) {
            return true
        }
        return false
    }

    private static func isLikelySymbol(_ codePoint: UInt32) -> Bool {
        switch codePoint {
        case 0x203C, 0x2049, 0x2122, 0x2139,
             0x2194...0x2199,
             0x21A9...0x21AA,
             0x231A...0x231B,
             0x2328,
             0x23CF,
             0x23E9...0x23F3,
             0x23F8...0x23FA,
             0x24C2,
             0x25AA...0x25AB,
             0x25B6,
             0x25C0,
             0x25FB...0x25FE,
             0x2600...0x2604,
             0x2611,
             0x2614,
             0x261D,
             0x2620,
             0x2622...0x2623,
             0x2626,
             0x262A,
             0x262E...0x262F,
             0x2638,
             0x2640, 0x2642,
             0x2648...0x2653,
             0x2660, 0x2663, 0x2665...0x2666,
             0x2668,
             0x267B,
             0x267E...0x267F,
             0x2692...0x2697,
             0x2699,
             0x269B...0x269C,
             0x26A0...0x26A1,
             0x26A7,
             0x26AA...0x26AB,
             0x26B0...0x26B1,
             0x26C4...0x26C5,
             0x26C8,
             0x26CE...0x26CF,
             0x26D1,
             0x26D3...0x26D4,
             0x26E9...0x26EA,
             0x26F0...0x26F5,
             0x26F7...0x26FA,
             0x26FD,
             0x2702,
             0x2705,
             0x2708...0x270D,
             0x270F,
             0x2712,
             0x2714,
             0x2716,
             0x271D,
             0x2721,
             0x2728,
             0x2733...0x2734,
             0x2744,
             0x2747,
             0x274C,
             0x274E,
             0x2753...0x2755,
             0x2757,
             0x2763...0x2764,
             0x2795...0x2797,
             0x27A1,
             0x27B0,
             0x27BF,
             0x2934...0x2935,
             0x2B05...0x2B07,
             0x2B1B...0x2B1C,
             0x2B50,
             0x2B55,
             0x3030,
             0x303D,
             0x3297,
             0x3299,
             0x1F500...0x1F53D,
             0x1F549...0x1F54E,
             0x1F5A4:
            return true
        default:
            return false
        }
    }

    private static func buildFlagEmojis() -> [String] {
        var out: [String] = []
        out.reserveCapacity(iso3166Alpha2Codes.count)
        for code in iso3166Alpha2Codes {
            guard code.count == 2 else { continue }
            let upper = code.uppercased()
            let scalars = upper.unicodeScalars
            guard let a = scalars.first, let b = scalars.dropFirst().first else { continue }
            guard let ra = regionalIndicator(from: a), let rb = regionalIndicator(from: b) else { continue }
            out.append(String(ra) + String(rb))
        }
        return Array(Set(out)).sorted()
    }

    private static func regionalIndicator(from letter: UnicodeScalar) -> UnicodeScalar? {
        let v = letter.value
        guard (0x41...0x5A).contains(v) else { return nil }
        return UnicodeScalar(0x1F1E6 + (v - 0x41))
    }

    /// ISO 3166-1 alpha-2 codes (official; no network).
    private static let iso3166Alpha2Codes: [String] = [
        "AD", "AE", "AF", "AG", "AI", "AL", "AM", "AO", "AQ", "AR", "AS", "AT", "AU", "AW", "AX", "AZ",
        "BA", "BB", "BD", "BE", "BF", "BG", "BH", "BI", "BJ", "BL", "BM", "BN", "BO", "BQ", "BR", "BS", "BT", "BV", "BW", "BY", "BZ",
        "CA", "CC", "CD", "CF", "CG", "CH", "CI", "CK", "CL", "CM", "CN", "CO", "CR", "CU", "CV", "CW", "CX", "CY", "CZ",
        "DE", "DJ", "DK", "DM", "DO", "DZ",
        "EC", "EE", "EG", "EH", "ER", "ES", "ET",
        "FI", "FJ", "FK", "FM", "FO", "FR",
        "GA", "GB", "GD", "GE", "GF", "GG", "GH", "GI", "GL", "GM", "GN", "GP", "GQ", "GR", "GS", "GT", "GU", "GW", "GY",
        "HK", "HM", "HN", "HR", "HT", "HU",
        "ID", "IE", "IL", "IM", "IN", "IO", "IQ", "IR", "IS", "IT",
        "JE", "JM", "JO", "JP",
        "KE", "KG", "KH", "KI", "KM", "KN", "KP", "KR", "KW", "KY", "KZ",
        "LA", "LB", "LC", "LI", "LK", "LR", "LS", "LT", "LU", "LV", "LY",
        "MA", "MC", "MD", "ME", "MF", "MG", "MH", "MK", "ML", "MM", "MN", "MO", "MP", "MQ", "MR", "MS", "MT", "MU", "MV", "MW", "MX", "MY", "MZ",
        "NA", "NC", "NE", "NF", "NG", "NI", "NL", "NO", "NP", "NR", "NU", "NZ",
        "OM",
        "PA", "PE", "PF", "PG", "PH", "PK", "PL", "PM", "PN", "PR", "PS", "PT", "PW", "PY",
        "QA",
        "RE", "RO", "RS", "RU", "RW",
        "SA", "SB", "SC", "SD", "SE", "SG", "SH", "SI", "SJ", "SK", "SL", "SM", "SN", "SO", "SR", "SS", "ST", "SV", "SX", "SY", "SZ",
        "TC", "TD", "TF", "TG", "TH", "TJ", "TK", "TL", "TM", "TN", "TO", "TR", "TT", "TV", "TW", "TZ",
        "UA", "UG", "UM", "US", "UY", "UZ",
        "VA", "VC", "VE", "VG", "VI", "VN", "VU",
        "WF", "WS",
        "YE", "YT",
        "ZA", "ZM", "ZW"
    ]
}

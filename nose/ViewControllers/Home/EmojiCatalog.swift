import Foundation

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

    /// Tab label; localized via `Localizable.xcstrings` (`emoji_category_*`).
    var title: String {
        switch self {
        case .smileys: return String(localized: "emoji_category_smileys")
        case .people: return String(localized: "emoji_category_people")
        case .nature: return String(localized: "emoji_category_nature")
        case .food: return String(localized: "emoji_category_food")
        case .travel: return String(localized: "emoji_category_travel")
        case .activities: return String(localized: "emoji_category_activities")
        case .objects: return String(localized: "emoji_category_objects")
        case .symbols: return String(localized: "emoji_category_symbols")
        case .flags: return String(localized: "emoji_category_flags")
        }
    }
}

struct EmojiCategorySection {
    let category: EmojiCategory
    let emojis: [String]
}

enum EmojiCatalog {
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

    // MARK: - Curated emoji lists (Apple keyboard order)

    private static let smileyEmojis: [String] = [
        // Faces — smiling
        "😀", "😃", "😄", "😁", "😆", "🥹", "😅", "🤣", "😂", "🙂", "🙃", "😉", "😊", "😇",
        // Faces — affection
        "🥰", "😍", "🤩", "😘", "😗", "☺", "😚", "😙", "🥲",
        // Faces — tongue
        "😋", "😛", "😜", "🤪", "😝",
        // Faces — hand / money
        "🤑", "🤗", "🤭", "🫢", "🫣", "🤫", "🤔", "🫡",
        // Faces — neutral / skeptical
        "🤐", "🤨", "😐", "😑", "😶", "🫥", "😏", "😒", "🙄", "😬", "🤥", "🫨",
        // Faces — sleepy
        "😌", "😔", "😪", "🤤", "😴",
        // Faces — unwell
        "😷", "🤒", "🤕", "🤢", "🤮", "🤧", "🥵", "🥶", "🥴", "😵", "🤯",
        // Faces — hat / glasses
        "🤠", "🥳", "🥸", "😎", "🤓", "🧐",
        // Faces — concerned
        "😕", "🫤", "😟", "🙁", "☹", "😮", "😯", "😲", "😳", "🥺",
        "😦", "😧", "😨", "😰", "😥", "😢", "😭", "😱", "😖", "😣", "😞", "😓", "😩", "😫", "🥱",
        // Faces — negative
        "😤", "😡", "😠", "🤬",
        // Faces — costume
        "😈", "👿", "💀", "☠", "💩", "🤡", "👹", "👺", "👻", "👽", "👾", "🤖",
        // Cat faces
        "😺", "😸", "😹", "😻", "😼", "😽", "🙀", "😿", "😾",
        // Monkey faces
        "🙈", "🙉", "🙊",
        // Hearts
        "💌", "💘", "💝", "💖", "💗", "💓", "💞", "💕", "💟", "❣", "💔",
        "❤️‍🔥", "❤️‍🩹", "❤", "🩷", "🧡", "💛", "💚", "💙", "🩵", "💜", "🤎", "🖤", "🩶", "🤍",
        // Emotion
        "💋", "💯", "💢", "💥", "💫", "💦", "💨", "🕳", "💬", "👁‍🗨", "🗨", "🗯", "💭", "💤",
    ]

    private static let peopleEmojis: [String] = [
        // Hand — fingers open
        "👋", "🤚", "🖐", "✋", "🖖", "🫱", "🫲", "🫳", "🫴", "🫷", "🫸",
        // Hand — fingers partial
        "👌", "🤌", "🤏", "✌", "🤞", "🫰", "🤟", "🤘", "🤙",
        // Hand — single finger
        "👈", "👉", "👆", "🖕", "👇", "☝", "🫵",
        // Hand — fingers closed
        "👍", "👎", "✊", "👊", "🤛", "🤜",
        // Hands
        "👏", "🙌", "🫶", "👐", "🤲", "🤝", "🙏",
        // Hand — prop
        "✍", "💅", "🤳",
        // Body parts
        "💪", "🦾", "🦿", "🦵", "🦶", "👂", "🦻", "👃",
        "🧠", "🫀", "🫁", "🦷", "🦴", "👀", "👁", "👅", "👄", "🫦",
        // Person
        "👶", "🧒", "👦", "👧", "🧑", "👱", "👨", "🧔", "👩", "🧓", "👴", "👵",
        // Person — gesture
        "🙍", "🙎", "🙅", "🙆", "💁", "🙋", "🧏", "🙇", "🤦", "🤷",
        // Person — role
        "👮", "🕵", "💂", "🥷", "👷", "🫅", "🤴", "👸", "👳", "👲", "🧕",
        "🤵", "👰", "🤰", "🫃", "🫄", "🤱", "👼", "🎅", "🤶",
        // Person — fantasy
        "🦸", "🦹", "🧙", "🧚", "🧛", "🧜", "🧝", "🧞", "🧟",
        // Person — activity
        "💆", "💇", "🚶", "🧍", "🧎", "🏃", "💃", "🕺", "🕴", "👯", "🧖", "🧗", "🤸",
        // Person — sport
        "🏌", "🏇", "⛷", "🏂", "🏋", "🤼", "🤽", "🤾", "🤺", "⛹", "🏊", "🚣", "🧘",
        // Person — resting
        "🛀", "🛌",
        // Family & couples
        "👭", "👫", "👬", "💏", "💑", "👪",
        "👨‍👩‍👦", "👨‍👩‍👧", "👨‍👩‍👧‍👦", "👨‍👩‍👦‍👦", "👨‍👩‍👧‍👧",
        "👨‍👦", "👨‍👦‍👦", "👨‍👧", "👨‍👧‍👦", "👨‍👧‍👧",
        "👩‍👦", "👩‍👦‍👦", "👩‍👧", "👩‍👧‍👦", "👩‍👧‍👧",
        // Person — symbol
        "🗣", "👤", "👥", "🫂", "👣",
    ]

    private static let natureEmojis: [String] = [
        // Animal — mammal (small / face)
        "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐻‍❄", "🐨", "🐯", "🦁", "🐮", "🐷", "🐽", "🐸",
        // Animal — primate
        "🐵", "🐒",
        // Animal — bird
        "🐔", "🐧", "🐦", "🐤", "🐣", "🐥", "🦆", "🦅", "🦉", "🦇",
        // Animal — other mammal
        "🐺", "🐗", "🐴", "🦄",
        // Animal — bug
        "🐝", "🪱", "🐛", "🦋", "🐌", "🐞", "🐜", "🪰", "🪲", "🪳", "🦟", "🦗", "🕷", "🕸", "🦂",
        // Animal — reptile
        "🐢", "🐍", "🦎", "🦖", "🦕",
        // Animal — marine
        "🐙", "🦑", "🦐", "🦞", "🦀", "🐡", "🐠", "🐟", "🐬", "🐳", "🐋", "🦈", "🦭",
        // Animal — large mammal
        "🐊", "🐅", "🐆", "🦓", "🫏", "🦍", "🦧", "🐘", "🦣", "🦛", "🦏",
        "🐪", "🐫", "🦒", "🦘", "🦬", "🐃", "🐂", "🐄", "🐎", "🐖", "🐏", "🐑", "🦙", "🐐", "🦌", "🫎",
        // Animal — domestic / other
        "🐕", "🐩", "🦮", "🐕‍🦺", "🐈", "🐈‍⬛", "🪽", "🪿",
        "🐓", "🦃", "🦤", "🦚", "🦜", "🦢", "🦩", "🕊", "🐇",
        "🦝", "🦨", "🦡", "🦫", "🦦", "🦥", "🐁", "🐀", "🐿", "🦔",
        // Animal — misc
        "🐾", "🐉", "🐲",
        // Plant — flower
        "💐", "🌸", "💮", "🏵", "🌹", "🥀", "🌺", "🌻", "🌼", "🌷", "🪻", "🪷",
        // Plant — other
        "🌱", "🪴", "🌲", "🌳", "🌴", "🌵", "🌾", "🌿", "☘", "🍀",
        "🎍", "🎋", "🍃", "🍂", "🍁", "🪹", "🪺", "🪵", "🍄", "🪸",
    ]

    private static let foodEmojis: [String] = [
        // Fruit
        "🍇", "🍈", "🍉", "🍊", "🍋", "🍌", "🍍", "🥭", "🍎", "🍏",
        "🍐", "🍑", "🍒", "🍓", "🫐", "🥝", "🍅", "🫒", "🥥",
        // Vegetable
        "🥑", "🍆", "🥔", "🥕", "🌽", "🌶", "🫑", "🥒", "🥬", "🥦",
        "🧄", "🧅", "🥜", "🫘", "🌰", "🫚", "🫛", "🍠",
        // Food — prepared
        "🍞", "🥐", "🥖", "🫓", "🥨", "🥯", "🥞", "🧇", "🧀",
        "🍖", "🍗", "🥩", "🥓", "🍔", "🍟", "🍕", "🌭", "🥪",
        "🌮", "🌯", "🫔", "🥙", "🧆", "🥚", "🍳", "🥘", "🍲", "🫕", "🥣", "🥗", "🍿", "🧈", "🧂", "🥫",
        // Food — asian
        "🍱", "🍘", "🍙", "🍚", "🍛", "🍜", "🍝", "🍢", "🍣", "🍤", "🍥", "🥮", "🍡", "🥟", "🥠", "🥡",
        // Food — sweet
        "🍦", "🍧", "🍨", "🍩", "🍪", "🎂", "🍰", "🧁", "🥧", "🍫", "🍬", "🍭", "🍮", "🍯",
        // Drink
        "🍼", "🥛", "☕", "🫖", "🍵", "🍶", "🍾", "🍷", "🍸", "🍹", "🍺", "🍻", "🥂", "🥃", "🫗", "🥤", "🧋", "🧃", "🧉",
        // Dishware
        "🥢", "🍽", "🍴", "🥄", "🔪", "🫙", "🏺",
    ]

    private static let travelEmojis: [String] = [
        // Place — map
        "🌍", "🌎", "🌏", "🌐", "🗺", "🧭",
        // Place — geographic
        "🏔", "⛰", "🌋", "🗻", "🏕", "🏖", "🏜", "🏝", "🏞",
        // Place — building
        "🏟", "🏛", "🏗", "🧱", "🪨", "🛖", "🏘", "🏚", "🏠", "🏡",
        "🏢", "🏣", "🏤", "🏥", "🏦", "🏨", "🏩", "🏪", "🏫", "🏬", "🏭", "🏯", "🏰", "💒", "🗼", "🗽",
        // Place — religious
        "⛪", "🕌", "🛕", "🕍", "⛩", "🕋",
        // Place — other
        "⛲", "⛺", "🌁", "🌃", "🏙", "🌄", "🌅", "🌆", "🌇", "🌉",
        "♨", "🎠", "🛝", "🎡", "🎢", "💈", "🎪",
        // Transport — ground
        "🚂", "🚃", "🚄", "🚅", "🚆", "🚇", "🚈", "🚉", "🚊", "🚝", "🚞",
        "🚋", "🚌", "🚍", "🚎", "🚐", "🚑", "🚒", "🚓", "🚔", "🚕", "🚖", "🚗", "🚘", "🚙",
        "🛻", "🚚", "🚛", "🚜", "🏎", "🏍", "🛵", "🦽", "🦼", "🛺",
        "🚲", "🛴", "🛹", "🛼", "🚏", "🛣", "🛤", "🛢", "⛽", "🛞", "🚨", "🚥", "🚦", "🛑", "🚧",
        // Transport — water
        "⛵", "🛶", "🚤", "🛳", "⛴", "🛥", "🚢",
        // Transport — air
        "✈", "🛩", "🛫", "🛬", "🪂", "💺", "🚁", "🚟", "🚠", "🚡", "🛰", "🚀", "🛸",
        // Hotel
        "🛎", "🧳",
        // Time
        "⌛", "⏳", "⌚", "⏰", "⏱", "⏲",
        "🕐", "🕑", "🕒", "🕓", "🕔", "🕕", "🕖", "🕗", "🕘", "🕙", "🕚", "🕛",
        "🕜", "🕝", "🕞", "🕟", "🕠", "🕡", "🕢", "🕣", "🕤", "🕥", "🕦", "🕧",
        // Sky & weather
        "🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘", "🌙", "🌚", "🌛", "🌜", "🌡",
        "☀", "🌝", "🌞", "🪐", "⭐", "🌟", "🌠", "🌌",
        "☁", "⛅", "⛈", "🌤", "🌥", "🌦", "🌧", "🌨", "🌩", "🌪", "🌫", "🌬",
        "🌀", "🌈", "🌂", "☂", "☔", "⛱", "⚡", "❄", "☃", "⛄", "☄", "🔥", "💧", "🌊",
    ]

    private static let activityEmojis: [String] = [
        // Event
        "🎃", "🎄", "🎆", "🎇", "🧨", "✨", "🎈", "🎉", "🎊", "🎋", "🎍", "🎎", "🎏", "🎐", "🎑", "🧧",
        "🎀", "🎁", "🎗", "🎟", "🎫",
        // Award & medal
        "🎖", "🏆", "🏅", "🥇", "🥈", "🥉",
        // Sport
        "⚽", "⚾", "🥎", "🏀", "🏐", "🏈", "🏉", "🎾", "🥏", "🎳",
        "🏏", "🏑", "🏒", "🥍", "🏓", "🏸", "🥊", "🥋", "🥅", "⛳", "⛸", "🎣", "🤿", "🎽", "🎿", "🛷", "🥌",
        // Game
        "🎯", "🪀", "🪁", "🔫", "🎱", "🔮", "🪄", "🧿", "🪬",
        "🎮", "🕹", "🎰", "🎲", "🧩", "🧸", "🪅", "🪩", "🪆",
        "♠", "♥", "♦", "♣", "♟", "🃏", "🀄", "🎴",
        // Arts & crafts
        "🎭", "🖼", "🎨", "🧵", "🪡", "🧶", "🪢",
    ]

    private static let objectEmojis: [String] = [
        // Clothing
        "👓", "🕶", "🥽", "🥼", "🦺", "👔", "👕", "👖", "🧣", "🧤", "🧥", "🧦",
        "👗", "👘", "🥻", "🩱", "🩲", "🩳", "👙", "👚", "🪭",
        "👛", "👜", "👝", "🛍", "🎒", "🩴", "👞", "👟", "🥾", "🥿", "👠", "👡", "🩰", "👢",
        "🪮", "👑", "👒", "🎩", "🪖", "⛑", "📿", "💄", "💍", "💎",
        // Sound
        "🔇", "🔈", "🔉", "🔊", "📢", "📣", "📯", "🔔", "🔕",
        // Music
        "🎼", "🎵", "🎶", "🎙", "🎚", "🎛",
        // Musical instrument
        "🎷", "🪗", "🎸", "🎹", "🎺", "🎻", "🪕", "🥁", "🪘", "🪇", "🪈",
        // Phone
        "📱", "📲", "☎", "📞", "📟", "📠",
        // Computer
        "🔋", "🪫", "🔌", "💻", "🖥", "🖨", "⌨", "🖱", "🖲", "💽", "💾", "💿", "📀", "🧮",
        // Light & video
        "🎥", "🎞", "📽", "🎬", "📺", "📷", "📸", "📹", "📼", "🔍", "🔎", "🕯", "💡", "🔦", "🏮", "🪔",
        // Book & paper
        "📔", "📕", "📖", "📗", "📘", "📙", "📚", "📓", "📒", "📃", "📜", "📄", "📰", "🗞", "📑", "🔖", "🏷",
        // Money
        "💰", "🪙", "💴", "💵", "💶", "💷", "💸", "💳", "🧾", "💹",
        // Mail
        "✉", "📧", "📨", "📩", "📤", "📥", "📦", "📫", "📪", "📬", "📭", "📮", "🗳",
        // Writing
        "✏", "✒", "🖋", "🖊", "🖌", "🖍", "📝",
        // Office
        "💼", "📁", "📂", "🗂", "📅", "📆", "🗒", "🗓", "📇", "📈", "📉", "📊", "📋",
        "📌", "📍", "📎", "🖇", "📏", "📐", "✂", "🗃", "🗄", "🗑",
        // Lock
        "🔒", "🔓", "🔏", "🔐", "🔑", "🗝",
        // Tool
        "🔨", "🪓", "⛏", "⚒", "🛠", "🗡", "⚔", "💣", "🪃", "🏹", "🛡", "🪚",
        "🔧", "🪛", "🔩", "⚙", "🗜", "⚖", "🦯", "🔗", "⛓", "🪝", "🧰", "🧲", "🪜",
        // Science
        "⚗", "🧪", "🧫", "🧬", "🔬", "🔭", "📡",
        // Medical
        "💉", "🩸", "💊", "🩹", "🩼", "🩺", "🩻",
        // Household
        "🚪", "🛗", "🪞", "🪟", "🛏", "🛋", "🪑", "🚽", "🪠", "🚿", "🛁",
        "🪤", "🪒", "🧴", "🧷", "🧹", "🧺", "🧻", "🪣", "🧼", "🫧", "🪥", "🧽", "🧯", "🛒",
        // Other object
        "🚬", "⚰", "🪦", "⚱", "🗿", "🪧", "🪪",
    ]

    private static let symbolEmojis: [String] = [
        // Transport sign
        "🏧", "🚮", "🚰", "♿", "🚹", "🚺", "🚻", "🚼", "🚾", "🛂", "🛃", "🛄", "🛅",
        // Warning
        "⚠", "🚸", "⛔", "🚫", "🚳", "🚭", "🚯", "🚱", "🚷", "📵", "🔞", "☢", "☣",
        // Arrow
        "⬆", "↗", "➡", "↘", "⬇", "↙", "⬅", "↖", "↕", "↔",
        "↩", "↪", "⤴", "⤵", "🔃", "🔄", "🔙", "🔚", "🔛", "🔜", "🔝",
        // Religion
        "🛐", "⚛", "🕉", "✡", "☸", "☯", "✝", "☦", "☪", "☮", "🕎", "🔯", "🪯",
        // Zodiac
        "♈", "♉", "♊", "♋", "♌", "♍", "♎", "♏", "♐", "♑", "♒", "♓", "⛎",
        // AV symbol
        "🔀", "🔁", "🔂", "▶", "⏩", "⏭", "⏯", "◀", "⏪", "⏮",
        "🔼", "⏫", "🔽", "⏬", "⏸", "⏹", "⏺", "⏏", "🎦", "🔅", "🔆", "📶", "🛜", "📳", "📴",
        // Gender
        "♀", "♂", "⚧",
        // Math
        "✖", "➕", "➖", "➗", "🟰",
        // Punctuation
        "‼", "⁉", "❓", "❔", "❕", "❗", "〰",
        // Currency
        "💱", "💲",
        // Other symbol
        "⚕", "♻", "⚜", "🔱", "📛", "🔰", "⭕", "✅", "☑", "✔", "❌", "❎",
        "➰", "➿", "〽", "✳", "✴", "❇", "©", "®", "™",
        // Keycap
        "#️⃣", "*️⃣", "0️⃣", "1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣", "7️⃣", "8️⃣", "9️⃣", "🔟",
        // Alphanum
        "🔠", "🔡", "🔢", "🔣", "🔤",
        "🅰", "🆎", "🅱", "🆑", "🆒", "🆓", "ℹ", "🆔", "Ⓜ", "🆕", "🆖", "🅾", "🆗", "🅿", "🆘", "🆙", "🆚",
        "🈁", "🈂", "🈷", "🈶", "🈯", "🉐", "🈹", "🈚", "🈲", "🉑", "🈸", "🈴", "🈳", "㊗", "㊙", "🈺", "🈵",
        // Geometric
        "🔴", "🟠", "🟡", "🟢", "🔵", "🟣", "🟤", "⚫", "⚪",
        "🟥", "🟧", "🟨", "🟩", "🟦", "🟪", "🟫", "⬛", "⬜", "◼", "◻", "◾", "◽", "▪", "▫",
        "🔶", "🔷", "🔸", "🔹", "🔺", "🔻", "💠", "🔘", "🔳", "🔲",
    ]

    // MARK: - Build sections

    private static func buildCategorizedSections() -> [EmojiCategorySection] {
        [
            EmojiCategorySection(category: .smileys, emojis: smileyEmojis),
            EmojiCategorySection(category: .people, emojis: peopleEmojis),
            EmojiCategorySection(category: .nature, emojis: natureEmojis),
            EmojiCategorySection(category: .food, emojis: foodEmojis),
            EmojiCategorySection(category: .travel, emojis: travelEmojis),
            EmojiCategorySection(category: .activities, emojis: activityEmojis),
            EmojiCategorySection(category: .objects, emojis: objectEmojis),
            EmojiCategorySection(category: .symbols, emojis: symbolEmojis),
            EmojiCategorySection(category: .flags, emojis: buildFlagEmojis()),
        ]
    }

    // MARK: - Flag generation

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

    /// ISO 3166-1 alpha-2 codes.
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
        "ZA", "ZM", "ZW",
    ]
}

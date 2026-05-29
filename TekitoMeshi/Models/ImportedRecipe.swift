import Foundation

struct ImportedRecipe: Identifiable, Codable {
    let id: UUID
    var name: String
    var ingredients: [String]
    var steps: [String]
    var cookTime: Int           // 分
    var servings: Int           // 人数
    var category: Recipe.Category
    var sourceURL: String
    var sourceName: String      // サイト名
    var thumbnailURL: String?   // OGP画像URL
    var stepsImageURL: String?  // 作り方画像（ローカル保存）
    var tags: [String]          // ユーザー定義タグ
    var note: String
    let importedAt: Date

    // タンパク質種別（インポート時に自動判定、手動修正可）
    var mainProteinType: MainProteinType

    // PFC（パース or 推定）
    var protein: Double
    var fat: Double
    var carb: Double

    // MARK: - Codable（旧データ互換: mainProteinType がなければ .any）
    enum CodingKeys: String, CodingKey {
        case id, name, ingredients, steps, cookTime, servings, category
        case sourceURL, sourceName, thumbnailURL, stepsImageURL, tags, note, importedAt
        case mainProteinType
        case protein, fat, carb
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(UUID.self,             forKey: .id)
        name            = try c.decode(String.self,           forKey: .name)
        ingredients     = try c.decode([String].self,         forKey: .ingredients)
        steps           = try c.decode([String].self,         forKey: .steps)
        cookTime        = try c.decode(Int.self,              forKey: .cookTime)
        servings        = try c.decode(Int.self,              forKey: .servings)
        category        = try c.decode(Recipe.Category.self,  forKey: .category)
        sourceURL       = try c.decode(String.self,           forKey: .sourceURL)
        sourceName      = try c.decode(String.self,           forKey: .sourceName)
        thumbnailURL    = try c.decodeIfPresent(String.self,  forKey: .thumbnailURL)
        stepsImageURL   = try c.decodeIfPresent(String.self,  forKey: .stepsImageURL)
        tags            = (try? c.decode([String].self,       forKey: .tags)) ?? []
        note            = try c.decode(String.self,           forKey: .note)
        importedAt      = try c.decode(Date.self,             forKey: .importedAt)
        mainProteinType = try c.decodeIfPresent(MainProteinType.self, forKey: .mainProteinType) ?? .any
        protein         = try c.decode(Double.self,           forKey: .protein)
        fat             = try c.decode(Double.self,           forKey: .fat)
        carb            = try c.decode(Double.self,           forKey: .carb)
    }

    var calorie: Double { protein * 4 + fat * 9 + carb * 4 }

    // MARK: - Recipe変換（献立生成プールに混ぜるため）
    func toRecipe() -> Recipe {
        // UUID → Int（衝突回避のため大きい値域）
        let recipeId = abs(id.hashValue % 800_000) + 100_000

        // 料理名＋材料名を結合したテキストで推定
        let text = (name + ingredients.joined()).lowercased()

        // ── タンパク質種別（保存済み値を使用）──────────────────
        let proteinType = mainProteinType

        // ── 難易度推定（調理時間ベース）────────────────────
        // 疲れたモードは difficulty == 1 のみ対象なのでここが重要
        let difficulty: Int = {
            if cookTime <= 20 { return 1 }  // 20分以内 → 簡単
            if cookTime <= 40 { return 2 }  // 40分以内 → ふつう
            return 3                         // 40分超 → 手間
        }()

        // ── 気分タグ推定 ─────────────────────────────────
        var moodTags: [RecipeMood] = []

        // hearty（野菜たっぷり）
        let heartyWords = ["野菜", "ほうれん草", "小松菜", "ブロッコリー", "にんじん",
                           "かぼちゃ", "きのこ", "なす", "ピーマン", "大根", "ごぼう",
                           "れんこん", "白菜", "キャベツ", "もやし", "豆苗", "春菊",
                           "水菜", "アスパラ", "セロリ", "ズッキーニ"]
        if heartyWords.contains(where: { text.contains($0) }) { moodTags.append(.hearty) }

        // healthy（さっぱり・ヘルシー）
        let healthyWords = ["サラダ", "和え", "浸し", "ポン酢", "蒸し", "おひたし",
                            "ヘルシー", "さっぱり", "低カロリー", "ごまだれ", "梅", "酢",
                            "豆腐", "塩麹", "塩昆布", "レモン"]
        if healthyWords.contains(where: { text.contains($0) }) { moodTags.append(.healthy) }

        // comfort（ほっこり・家庭的）
        let comfortWords = ["煮物", "煮込み", "おでん", "シチュー", "肉じゃが", "炊き込み",
                            "おかゆ", "鍋", "汁物", "みそ汁", "豚汁", "ほっこり",
                            "根菜", "里芋", "南蛮漬け", "西京焼き", "あんかけ"]
        if comfortWords.contains(where: { text.contains($0) }) { moodTags.append(.comfort) }

        // quick（時短）
        let quickWords = ["時短", "レンジ", "電子レンジ", "さっと", "簡単", "ずぼら", "スピード",
                          "炒め", "丼", "焼き"]
        if quickWords.contains(where: { text.contains($0) }) || cookTime <= 15 {
            moodTags.append(.quick)
        }

        // fancy（ちょっと特別）
        let fancyWords = ["グラタン", "ムニエル", "ソテー", "アクアパッツァ", "リゾット",
                          "テリーヌ", "カルパッチョ", "ロールキャベツ", "ハンバーグ",
                          "ビーフシチュー", "ポトフ", "南蛮"]
        if fancyWords.contains(where: { text.contains($0) }) { moodTags.append(.fancy) }

        // indulgent（こってり・ご褒美）
        let indulgentWords = ["チーズ", "クリーム", "バター", "ラーメン", "カレー",
                              "揚げ", "天ぷら", "フライ", "カツ", "餃子", "ピザ",
                              "から揚げ", "唐揚げ", "回鍋肉", "麻婆", "マーボー"]
        if indulgentWords.contains(where: { text.contains($0) }) { moodTags.append(.indulgent) }

        // international（エスニック・洋食）
        let intlWords = ["パスタ", "ピザ", "リゾット", "タコス", "カレー", "エスニック",
                         "チャーハン", "ビビンバ", "キンパ", "餃子", "麻婆", "春巻き",
                         "フォー", "ガパオ", "キーマ", "アジアン", "イタリアン"]
        if intlWords.contains(where: { text.contains($0) }) { moodTags.append(.international) }

        // 重複除去
        let uniqueTags = Array(Set(moodTags))

        return Recipe(
            id:              recipeId,
            name:            name,
            ingredients:     ingredients,
            protein:         protein > 0 ? protein : 15,
            fat:             fat     > 0 ? fat     : 10,
            carb:            carb    > 0 ? carb    : 15,
            cookTime:        cookTime,
            difficulty:      difficulty,
            category:        category,
            country:         .japan,
            moodTags:        uniqueTags,
            isFusion:        false,
            mainProteinType: proteinType
        )
    }

    init(
        id: UUID = UUID(),
        name: String,
        ingredients: [String] = [],
        steps: [String] = [],
        cookTime: Int = 30,
        servings: Int = 2,
        category: Recipe.Category = .main,
        sourceURL: String,
        sourceName: String = "",
        thumbnailURL: String? = nil,
        stepsImageURL: String? = nil,
        tags: [String] = [],
        note: String = "",
        importedAt: Date = Date(),
        mainProteinType: MainProteinType = .any,
        protein: Double = 0,
        fat: Double = 0,
        carb: Double = 0
    ) {
        self.id              = id
        self.name            = name
        self.ingredients     = ingredients
        self.steps           = steps
        self.cookTime        = cookTime
        self.servings        = servings
        self.category        = category
        self.sourceURL       = sourceURL
        self.sourceName      = sourceName
        self.thumbnailURL    = thumbnailURL
        self.stepsImageURL   = stepsImageURL
        self.tags            = tags
        self.note            = note
        self.importedAt      = importedAt
        self.mainProteinType = mainProteinType
        self.protein         = protein
        self.fat             = fat
        self.carb            = carb
    }
}

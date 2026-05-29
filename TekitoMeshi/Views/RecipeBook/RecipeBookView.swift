import SwiftUI

// MARK: - RecipeBookView

struct RecipeBookView: View {

    // ── Store ────────────────────────────────────────────────────
    @ObservedObject private var importStore = ImportedRecipeStore.shared

    // ── フィルタ ─────────────────────────────────────────────────
    @State private var searchText        = ""
    @State private var categoryFilter: Recipe.Category? = nil
    @State private var timeFilter:     Int?              = nil  // nil=全て, 15, 30
    @State private var tagFilter:      String?           = nil
    @State private var showFavoritedOnly = false

    // ── プレミアム ───────────────────────────────────────────────
    private let freeLimit = 5
    private var isPremium: Bool { SubscriptionManager.shared.isPremium }
    @State private var showPaywall = false

    // ── シート ───────────────────────────────────────────────────
    @State private var showImport           = false
    @State private var selectedImported:    ImportedRecipe?
    @State private var generatedMenu:       DailyMenu?
    @State private var generatedThumbnailURL: String? = nil
    @State private var regenImportedRecipe: ImportedRecipe? = nil
    @State private var favoritedImported: Set<UUID> = RecipeBookView.loadFavoritedImported()

    // ── 計算プロパティ ────────────────────────────────────────────
    var filteredImported: [ImportedRecipe] {
        var r = importStore.recipes
        if !searchText.isEmpty {
            r = r.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.ingredients.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                $0.sourceName.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        if let cat = categoryFilter  { r = r.filter { $0.category == cat } }
        if let t   = timeFilter      { r = r.filter { $0.cookTime <= t } }
        if let tag = tagFilter       { r = r.filter { $0.tags.contains(tag) } }
        if showFavoritedOnly         { r = r.filter { favoritedImported.contains($0.id) } }
        return r
    }

    var allTags: [String] {
        Array(Set(importStore.recipes.flatMap { $0.tags })).sorted()
    }

    // ── Body ─────────────────────────────────────────────────────
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                headerView
                myRecipesContent
            }
        }
        .sheet(isPresented: $showImport) {
            ImportRecipeView()
                .onDisappear { importStore.objectWillChange.send() }
        }
        .sheet(isPresented: $showPaywall) {
            PremiumPaywallView(trigger: .myRecipes)
        }
        .sheet(item: $selectedImported) { recipe in
            ImportedRecipeDetailView(recipe: recipe)
        }
        .sheet(item: $generatedMenu) { menu in
            FavoriteMenuPreviewView(
                menu: menu,
                mainThumbnailURL: generatedThumbnailURL,
                onRegenerate: regenImportedRecipe.map { r in { generateMenuFromImported(r) } }
            )
        }
    }

    // MARK: - ヘッダー

    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("保存済み")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.appPrimary)
                    .kerning(1.2)
                Text("レシピ帳")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
            }
            Spacer()
            // インポートボタン（上限チェック）
            Button {
                if !isPremium && importStore.recipes.count >= freeLimit {
                    showPaywall = true
                } else {
                    showImport = true
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("追加")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Color.appPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color(hex: "F5EDE2"))
                .cornerRadius(20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - マイレシピ コンテンツ

    private var myRecipesContent: some View {
        VStack(spacing: 0) {
            // 検索バー
            searchBar(text: $searchText, placeholder: "レシピ名・材料・タグで検索")
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            // フィルタ行
            filterRow

            if importStore.recipes.isEmpty {
                myRecipesEmpty
            } else if filteredImported.isEmpty {
                noResultsView
            } else {
                importedGrid
            }
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // お気に入りのみ
                FilterChip(label: "", systemImage: showFavoritedOnly ? "heart.fill" : "heart",
                           isActive: showFavoritedOnly) {
                    showFavoritedOnly.toggle()
                }

                Divider().frame(height: 20)

                // カテゴリ
                FilterChip(label: "全て", isActive: categoryFilter == nil) {
                    categoryFilter = nil
                }
                FilterChip(label: "主菜", isActive: categoryFilter == .main) {
                    categoryFilter = categoryFilter == .main ? nil : .main
                }
                FilterChip(label: "副菜", isActive: categoryFilter == .side) {
                    categoryFilter = categoryFilter == .side ? nil : .side
                }
                FilterChip(label: "汁物", isActive: categoryFilter == .soup) {
                    categoryFilter = categoryFilter == .soup ? nil : .soup
                }

                Divider().frame(height: 20)

                // 時間
                FilterChip(label: "15分以内", isActive: timeFilter == 15) {
                    timeFilter = timeFilter == 15 ? nil : 15
                }
                FilterChip(label: "30分以内", isActive: timeFilter == 30) {
                    timeFilter = timeFilter == 30 ? nil : 30
                }

                // タグ（あれば表示）
                if !allTags.isEmpty {
                    Divider().frame(height: 20)
                    ForEach(allTags, id: \.self) { tag in
                        FilterChip(label: "#\(tag)", isActive: tagFilter == tag) {
                            tagFilter = tagFilter == tag ? nil : tag
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .padding(.bottom, 8)
    }

    // MARK: - マイレシピ グリッド

    private var importedGrid: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                // 残り枠バナー（フリーのみ）
                if !isPremium {
                    remainingSlotsBanner
                        .padding(.horizontal, 16)
                }

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(filteredImported) { recipe in
                        RecipeGridCard(
                            recipe: recipe,
                            isFavorited: favoritedImported.contains(recipe.id),
                            onTap: { selectedImported = recipe },
                            onFavorite: { toggleImportedFavorite(recipe.id) },
                            onGenerateMenu: {
                                if let menu = generateMenuFromImported(recipe) {
                                    generatedThumbnailURL = recipe.thumbnailURL
                                    regenImportedRecipe   = recipe
                                    generatedMenu         = menu
                                }
                            },
                            onDelete: { importStore.delete(recipe) }
                        )
                    }

                    // ロックカード（フリーかつ上限到達）
                    if !isPremium && importStore.recipes.count >= freeLimit {
                        LockedRecipeCard { showPaywall = true }
                        LockedRecipeCard { showPaywall = true }
                    }
                }
                .padding(.horizontal, 16)

                // プレミアムアップセルバナー
                if !isPremium && importStore.recipes.count >= freeLimit {
                    Button { showPaywall = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Premiumでレシピ無制限")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                Text("URLを貼るだけで何件でも保存できます")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
            .padding(.bottom, 20)
        }
    }

    private var remainingSlotsBanner: some View {
        let remaining = max(0, freeLimit - importStore.recipes.count)
        let atLimit   = remaining == 0
        return HStack(spacing: 8) {
            Image(systemName: atLimit ? "lock.fill" : "tray.and.arrow.down")
                .font(.system(size: 12))
                .foregroundColor(atLimit ? .red : .appPrimary)
            Text(atLimit ? "無料プランの上限（\(freeLimit)件）です" : "あと\(remaining)件追加できます（無料枠）")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(atLimit ? .red : .appTextSecondary)
            Spacer()
            if atLimit {
                Text("Premium解除")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.appPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.appPrimaryPale)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(atLimit ? Color.red.opacity(0.06) : Color.appPrimaryPale.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var myRecipesEmpty: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("📖")
                .font(.system(size: 64))
            Text("マイレシピがありません")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Color.appTextPrimary)
            Text("お気に入りのレシピURLを追加して\n自分だけのレシピ帳を作りましょう")
                .font(.system(size: 14))
                .foregroundColor(Color.appTextTertiary)
                .multilineTextAlignment(.center)
            Button { showImport = true } label: {
                Label("レシピをインポートする", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.appPrimary)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13))
                Text("ブラウザのシェアボタンからも追加できます")
                    .font(.system(size: 13))
            }
            .foregroundColor(Color.appTextTertiary)
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(Color.appTextTertiary.opacity(0.5))
            Text("該当するレシピがありません")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.appTextSecondary)
            Button {
                searchText = ""; categoryFilter = nil; timeFilter = nil; tagFilter = nil
            } label: {
                Text("フィルタをリセット")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.appPrimary)
            }
            Spacer()
        }
    }

    // MARK: - 共通パーツ

    @ViewBuilder
    private func searchBar(text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.appTextTertiary)
                .font(.system(size: 14))
            TextField(placeholder, text: text)
                .font(.system(size: 15))
                .foregroundColor(Color.appTextPrimary)
            if !text.wrappedValue.isEmpty {
                Button { text.wrappedValue = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.appTextTertiary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appSeparator, lineWidth: 1))
    }

    // MARK: - お気に入りトグル（インポートレシピ）

    private func toggleImportedFavorite(_ id: UUID) {
        withAnimation(.spring(response: 0.3)) {
            if favoritedImported.contains(id) {
                favoritedImported.remove(id)
            } else {
                favoritedImported.insert(id)
            }
        }
        RecipeBookView.saveFavoritedImported(favoritedImported)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func generateMenuFromImported(_ recipe: ImportedRecipe) -> DailyMenu? {
        guard recipe.category == .main else { return nil }
        let mainRecipe  = recipe.toRecipe()
        let ingredients = StorageService.shared.loadIngredients()
        let family      = StorageService.shared.loadFamilyMembers()
        let allRecipes = SampleRecipes.all + ImportedRecipeStore.shared.recipes.map { $0.toRecipe() }
        return FavoriteManager.shared.generateMenuFromFavoriteMain(
            mainRecipe:  mainRecipe,
            allRecipes:  allRecipes,
            fridgeItems: ingredients,
            family:      family
        )
    }

    static func loadFavoritedImported() -> Set<UUID> {
        guard let data = UserDefaults.standard.data(forKey: "favoritedImportedRecipes"),
              let ids  = try? JSONDecoder().decode([UUID].self, from: data)
        else { return [] }
        return Set(ids)
    }

    static func saveFavoritedImported(_ ids: Set<UUID>) {
        if let data = try? JSONEncoder().encode(Array(ids)) {
            UserDefaults.standard.set(data, forKey: "favoritedImportedRecipes")
        }
    }
}

// MARK: - RecipeGridCard

struct RecipeGridCard: View {
    let recipe: ImportedRecipe
    let isFavorited: Bool
    let onTap: () -> Void
    let onFavorite: () -> Void
    let onGenerateMenu: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // サムネイル
                thumbnailView
                    .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
                    .clipped()

                // テキスト部
                VStack(alignment: .leading, spacing: 5) {
                    Text(recipe.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.appTextPrimary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)

                    HStack(spacing: 4) {
                        Text(recipe.category.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(categoryColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(categoryColor.opacity(0.12))
                            .clipShape(Capsule())
                        Spacer()
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundColor(Color.appTextTertiary)
                        Text("\(recipe.cookTime)分")
                            .font(.system(size: 10))
                            .foregroundColor(Color.appTextTertiary)
                    }
                }
                .padding(10)
            }
        }
        .buttonStyle(.plain)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appSeparator, lineWidth: 0.5)
        )
        // ハートバッジ
        .overlay(alignment: .topTrailing) {
            if isFavorited {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.appMeat)
                    .padding(6)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Circle())
                    .padding(8)
            }
        }
        .contextMenu {
            if recipe.category == .main {
                Button { onGenerateMenu() } label: {
                    Label("この料理で献立を組む", systemImage: "fork.knife")
                }
            }
            Button { onFavorite() } label: {
                Label(
                    isFavorited ? "お気に入りを外す" : "お気に入りに追加",
                    systemImage: isFavorited ? "heart.slash" : "heart"
                )
            }
            Button(role: .destructive) { onDelete() } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let localImg = UIImage(named: "dish_\(recipe.name)") {
            Image(uiImage: localImg).resizable().scaledToFill()
                .frame(maxWidth: .infinity)
        } else if let urlStr = recipe.thumbnailURL,
                  let path = resolveLocalImagePath(urlStr),
                  let uiImage = UIImage(contentsOfFile: path) {
            Image(uiImage: uiImage).resizable().scaledToFill()
                .frame(maxWidth: .infinity)
        } else if let urlStr = recipe.thumbnailURL,
                  let url = URL(string: urlStr),
                  url.scheme == "https" || url.scheme == "http" {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                        .frame(maxWidth: .infinity)
                default: placeholderView
                }
            }
            .frame(maxWidth: .infinity)
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        ZStack {
            LinearGradient(
                colors: [categoryColor.opacity(0.18), categoryColor.opacity(0.06)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(spacing: 6) {
                Image(systemName: recipe.category.sfSymbol)
                    .font(.system(size: 30))
                    .foregroundColor(categoryColor.opacity(0.4))
                Text(recipe.name)
                    .font(.system(size: 10))
                    .foregroundColor(categoryColor.opacity(0.6))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
    }

    private var categoryColor: Color {
        switch recipe.category {
        case .main:   return .appPrimary
        case .side:   return .appGreen
        case .soup:   return .appFish
        case .staple: return .appSaving
        case .sweets: return Color(hex: "C97BB0")
        }
    }
}

// MARK: - LockedRecipeCard

struct LockedRecipeCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // ロックエリア
                ZStack {
                    LinearGradient(
                        colors: [Color.appPrimary.opacity(0.10), Color.appPrimary.opacity(0.04)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    VStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Color.appPrimary.opacity(0.5))
                        Text("Premium")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.appPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Color.appPrimary.opacity(0.10))
                            .clipShape(Capsule())
                    }
                }
                .frame(height: 120)

                // テキスト部
                VStack(alignment: .leading, spacing: 5) {
                    Text("レシピを追加する")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.appTextTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Premiumで無制限")
                        .font(.system(size: 10))
                        .foregroundColor(Color.appTextTertiary.opacity(0.7))
                }
                .padding(10)
            }
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .foregroundColor(Color.appPrimary.opacity(0.3))
        )
    }
}

// MARK: - AnimatedRecipesEmpty

struct AnimatedRecipesEmpty: View {
    @State private var shakeX: CGFloat = 0
    @State private var shakeRot: Double = 0

    var body: some View {
        Image("recipes_empty")
            .resizable()
            .scaledToFit()
            .frame(width: 110, height: 110)
            .offset(x: shakeX)
            .rotationEffect(.degrees(shakeRot), anchor: .bottom)
            .onAppear { shake() }
    }

    private func shake() {
        withAnimation(.easeInOut(duration: 0.075))               { shakeX = -4; shakeRot = -4 }
        withAnimation(.easeInOut(duration: 0.075).delay(0.075))  { shakeX =  4; shakeRot =  4 }
        withAnimation(.easeInOut(duration: 0.075).delay(0.15))   { shakeX = -4; shakeRot = -4 }
        withAnimation(.easeInOut(duration: 0.075).delay(0.225))  { shakeX =  4; shakeRot =  4 }
        withAnimation(.easeInOut(duration: 0.06).delay(0.30))    { shakeX = -2; shakeRot = -2 }
        withAnimation(.easeInOut(duration: 0.07).delay(0.36))    { shakeX =  2; shakeRot =  2 }
        withAnimation(.easeInOut(duration: 0.07).delay(0.43))    { shakeX =  0; shakeRot =  0 }
    }
}

// MARK: - FilterChip

struct FilterChip: View {
    let label:       String
    var systemImage: String? = nil
    let isActive:    Bool
    let action:      () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = systemImage {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                }
                if !label.isEmpty {
                    Text(label)
                        .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                }
            }
            .foregroundColor(isActive ? .white : Color.appTextSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? Color.appPrimary : Color.white)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isActive ? Color.appPrimary : Color.appSeparator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

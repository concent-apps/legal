import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - ImportedRecipesListView

struct ImportedRecipesListView: View {
    @ObservedObject private var store = ImportedRecipeStore.shared
    @State private var showImport       = false
    @State private var selectedRecipe: ImportedRecipe?
    @State private var bounceY: CGFloat = 0
    @State private var iconOpacity: Double = 1.0
    @State private var animTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                headerView
                if store.recipes.isEmpty {
                    emptyView
                } else {
                    listView
                }
            }
        }
        .sheet(isPresented: $showImport) {
            ImportRecipeView()
        }
        .sheet(item: $selectedRecipe) { recipe in
            ImportedRecipeDetailView(recipe: recipe)
        }
    }

    // MARK: - ヘッダー

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("インポート")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.appPrimary)
                    .kerning(1.2)
                Text("マイレシピ")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
            }
            Spacer()
            Button {
                showImport = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "F5EDE2"))
                        .frame(width: 36, height: 36)
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.appPrimary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    // MARK: - 空状態

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image("recipe_empty")
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
                .padding(.bottom, 8)
                .offset(y: bounceY)
                .opacity(iconOpacity)
                .onAppear { startBounce() }
                .onDisappear { animTask?.cancel() }
            Text("まだレシピがありません")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Color.appTextPrimary)
            Text("レシピサイトのURLを貼り付けて\n自分だけのレシピ帳を作ろう")
                .font(.system(size: 14))
                .foregroundColor(Color.appTextTertiary)
                .multilineTextAlignment(.center)
            Button {
                showImport = true
            } label: {
                Text("レシピを追加する")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.appPrimary)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 4)

            VStack(spacing: 0) {
                ImportHowToRow(icon: "square.and.arrow.up", text: "ブラウザのシェアボタンからも追加できます")
            }
            .background(Color.white)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appSeparator, lineWidth: 1))
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.vertical)
    }

    // MARK: - リスト

    private var listView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(store.recipes) { recipe in
                    ImportedRecipeRow(recipe: recipe)
                        .onTapGesture { selectedRecipe = recipe }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.delete(recipe)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    // MARK: - アニメーション

    private func startBounce() {
        animTask?.cancel()
        bounceY = 0; iconOpacity = 1.0
        animTask = Task {
            while !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.15)) { bounceY = -22 }
                try? await Task.sleep(nanoseconds: 150_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.interpolatingSpring(stiffness: 220, damping: 10)) { bounceY = 0 }
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.6)) { iconOpacity = 0 }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.4)) { iconOpacity = 1.0 }
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
            }
        }
    }
}

// MARK: - ImportedRecipeRow

struct ImportedRecipeRow: View {
    let recipe: ImportedRecipe
    var isFavorited: Bool = false
    var onFavorite: (() -> Void)? = nil
    var onGenerateMenu: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // サムネイル
                Group {
                    if let thumbURL = recipe.thumbnailURL,
                       let path = resolveLocalImagePath(thumbURL),
                       let uiImage = UIImage(contentsOfFile: path) {
                        Image(uiImage: uiImage).resizable().scaledToFill()
                    } else if let thumbURL = recipe.thumbnailURL,
                              let url = URL(string: thumbURL),
                              url.scheme == "https" || url.scheme == "http" {
                        AsyncImage(url: url) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                            } else {
                                placeholderThumb
                            }
                        }
                    } else {
                        placeholderThumb
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 6) {
                    Text(recipe.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.appTextPrimary)
                        .lineLimit(2)

                    // ソース・時間
                    HStack(spacing: 8) {
                        if !recipe.sourceName.isEmpty {
                            Text(recipe.sourceName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.appPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.appPrimary.opacity(0.08))
                                .cornerRadius(4)
                        }
                        Label("\(recipe.cookTime)分", systemImage: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(Color.appTextSecondary)
                    }

                    // 材料数・手順数
                    HStack(spacing: 8) {
                        if !recipe.ingredients.isEmpty {
                            Label("材料\(recipe.ingredients.count)品", systemImage: "list.bullet")
                                .font(.system(size: 11))
                                .foregroundColor(Color.appTextSecondary)
                        }
                        if !recipe.steps.isEmpty {
                            Label("\(recipe.steps.count)ステップ", systemImage: "text.alignleft")
                                .font(.system(size: 11))
                                .foregroundColor(Color.appTextSecondary)
                        }
                    }
                }

                Spacer()

                if let onFavorite {
                    Button {
                        onFavorite()
                    } label: {
                        Image(systemName: isFavorited ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                            .foregroundColor(isFavorited ? Color.appPrimary : Color(hex: "C0B8B0"))
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "C0B8B0"))
                }
            }

            if recipe.category == .main, let onGenerateMenu {
                Button(action: onGenerateMenu) {
                    HStack(spacing: 6) {
                        Image(systemName: "fork.knife").font(.system(size: 12))
                        Text("この料理で献立を組む").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(Color.appPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.appPrimaryLight)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appSeparator))
    }

    private var placeholderThumb: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(hex: "F5EDE2"))
            .overlay(
                Image(systemName: "fork.knife")
                    .font(.system(size: 22))
                    .foregroundColor(Color.appPrimary.opacity(0.4))
            )
    }
}

// MARK: - ImportedRecipeDetailView

struct ImportedRecipeDetailView: View {
    let recipe: ImportedRecipe
    @Environment(\.dismiss) private var dismiss

    @State private var proteinType: MainProteinType
    @State private var protein: Double
    @State private var fat: Double
    @State private var carb: Double
    @State private var pfcSaved          = false
    @State private var showDeleteConfirm = false
    @State private var thumbURL: String?
    @State private var isRefreshingThumb = false
    @State private var photosPickerItem: PhotosPickerItem?

    @State private var editingName: String
    @State private var editingCategory: Recipe.Category
    @State private var editingSourceURL: String
    @FocusState private var nameFieldFocused: Bool
    @State private var editingNote: String
    @State private var tags: [String]
    @State private var newTagText    = ""
    @State private var showTagInput  = false

    private let tagSuggestions = ["時短", "魚", "肉", "野菜", "豆腐", "揚げ物",
                                   "作り置き", "ヘルシー", "子ども向け", "がっつり", "あっさり"]

    init(recipe: ImportedRecipe) {
        self.recipe  = recipe
        _proteinType = State(initialValue: recipe.mainProteinType)
        _protein     = State(initialValue: recipe.protein)
        _fat         = State(initialValue: recipe.fat)
        _carb        = State(initialValue: recipe.carb)
        _editingName      = State(initialValue: recipe.name)
        _editingCategory  = State(initialValue: recipe.category)
        _editingSourceURL = State(initialValue: recipe.sourceURL)
        _editingNote      = State(initialValue: recipe.note)
        _tags        = State(initialValue: recipe.tags)
        _thumbURL    = State(initialValue: recipe.thumbnailURL)
    }

    private var calorie: Double { protein * 4 + fat * 9 + carb * 4 }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // ── ヒーロー画像 ───────────────────────────
                    heroSection

                    VStack(alignment: .leading, spacing: 16) {

                        // タイトル（タップで編集可）
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("料理名")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.appTextSecondary)
                                Image(systemName: "pencil")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color.appTextSecondary)
                            }
                            TextField("料理名を入力", text: $editingName)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Color.appTextPrimary)
                                .focused($nameFieldFocused)
                                .onSubmit { saveNameIfChanged() }
                                .onChange(of: nameFieldFocused) { _, focused in
                                    if !focused { saveNameIfChanged() }
                                }
                        }

                        // メタ情報チップ
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                infoChip(icon: "clock",     text: "\(recipe.cookTime)分")
                                infoChip(icon: "person.2",  text: "\(recipe.servings)人分")
                                SwiftUI.Menu {
                                    ForEach([Recipe.Category.main, .side, .soup, .staple], id: \.self) { cat in
                                        Button {
                                            editingCategory = cat
                                            saveToStore { $0.category = cat }
                                        } label: {
                                            Label(cat.label, systemImage: editingCategory == cat ? "checkmark" : cat.sfSymbol)
                                        }
                                    }
                                } label: {
                                    infoChip(icon: editingCategory.sfSymbol, text: editingCategory.label)
                                }
                                if !recipe.sourceName.isEmpty {
                                    infoChip(icon: "globe", text: recipe.sourceName)
                                }
                            }
                        }

                        // 材料
                        if !recipe.ingredients.isEmpty {
                            ingredientsSection
                        }

                        // 作り方
                        if !recipe.steps.isEmpty {
                            stepsSection
                        }

                        // メモ
                        noteSection

                        // タンパク質種別
                        proteinTypeSection

                        // PFC栄養素
                        pfcSection

                        // タグ
                        tagSection

                        // 参照URL
                        sourceURLSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .task { if thumbURL == nil { refreshThumbnail() } }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash").foregroundColor(.red)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(Color.appTextSecondary)
                }
            }
            .confirmationDialog("このレシピを削除しますか？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("削除する", role: .destructive) {
                    ImportedRecipeStore.shared.delete(recipe)
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            }
            .onDisappear {
                saveNameIfChanged()
                saveSourceURL()
                saveNote()
            }
        }
    }

    // MARK: - ヒーロー画像

    @ViewBuilder
    private var heroSection: some View {
        ZStack(alignment: .bottomTrailing) {
            if let urlStr = thumbURL {
                RecipeThumbnailView(urlStr: urlStr, height: 260) {
                    thumbnailRefreshButton
                }
            } else {
                thumbnailRefreshButton
            }

            PhotosPicker(selection: $photosPickerItem, matching: .images) {
                HStack(spacing: 4) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 13, weight: .semibold))
                    Text("写真を変更")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.5))
                .clipShape(Capsule())
            }
            .padding(12)
        }
        .task(id: photosPickerItem) {
            guard let item = photosPickerItem else { return }
            // Data として読み込み、失敗したら JPEG 変換を試みる
            let imageData: Data?
            if let raw = try? await item.loadTransferable(type: Data.self) {
                imageData = raw
            } else {
                imageData = nil
            }
            guard let data = imageData,
                  let saved = saveImageToDocuments(data: data, id: recipe.id.uuidString) else {
                photosPickerItem = nil
                return
            }
            thumbURL = saved
            saveToStore { $0.thumbnailURL = saved }
            photosPickerItem = nil
        }
    }

    // MARK: - 材料セクション

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(icon: "list.bullet", title: "材料", badge: "\(recipe.servings)人分")

            VStack(spacing: 0) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { i, ing in
                    let (ingName, amount) = splitIngredient(ing)
                    HStack(spacing: 12) {
                        Text(ingName)
                            .font(.system(size: 14))
                            .foregroundColor(Color.appTextPrimary)
                        Spacer()
                        if !amount.isEmpty {
                            Text(amount)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.appTextSecondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(i.isMultiple(of: 2) ? Color.white : Color(hex: "FAFAF8"))

                    if i < recipe.ingredients.count - 1 {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .cornerRadius(0)
        }
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appSeparator))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // 材料名と分量を分割するヘルパー
    private func splitIngredient(_ text: String) -> (String, String) {
        let measureWords = ["大さじ", "小さじ", "カップ", "少々", "適量", "適宜", "ひとつまみ", "少量"]
        for word in measureWords {
            if let range = text.range(of: word) {
                let name = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let amount = String(text[range.lowerBound...]).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { return (name, amount) }
            }
        }
        let parts = text.components(separatedBy: " ")
        if parts.count >= 2 {
            let last = parts.last!
            let measurePattern = #"[\d½⅓⅔¼¾]|[gmlGML]$|個$|本$|枚$|切れ$|尾$|匹$|杯$|袋$|缶$|片$|束$"#
            if last.range(of: measurePattern, options: .regularExpression) != nil {
                return (parts.dropLast().joined(separator: " "), last)
            }
        }
        return (text, "")
    }

    // MARK: - 作り方セクション

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(icon: "text.alignleft", title: "作り方", badge: "\(recipe.steps.count)ステップ")

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 14) {
                        // ステップ番号
                        ZStack {
                            Circle()
                                .fill(Color.appPrimary)
                                .frame(width: 26, height: 26)
                            Text("\(i + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 0) {
                            Text(step)
                                .font(.system(size: 14))
                                .foregroundColor(Color.appTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.bottom, i < recipe.steps.count - 1 ? 16 : 0)

                            if i < recipe.steps.count - 1 {
                                Divider()
                                    .padding(.bottom, 16)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, i == 0 ? 14 : 0)
                    .padding(.bottom, i == recipe.steps.count - 1 ? 14 : 0)
                }
            }
        }
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appSeparator))
    }

    // MARK: - セクションヘッダー

    private func sectionHeader(icon: String, title: String, badge: String? = nil) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.appPrimary)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.appTextPrimary)
            if let badge {
                Text(badge)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.appPrimary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.appPrimary.opacity(0.1))
                    .cornerRadius(6)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(hex: "F7F3EF"))
    }

    private func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11))
            Text(text).font(.system(size: 12))
        }
        .foregroundColor(Color.appTextSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appSeparator))
    }

    // MARK: - タンパク質種別

    private var proteinTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("主なタンパク質")
            HStack(spacing: 8) {
                ForEach(MainProteinType.allCases, id: \.self) { type in
                    Button {
                        proteinType = type
                    } label: {
                        Text(type.label)
                            .font(.system(size: 13, weight: proteinType == type ? .semibold : .regular))
                            .foregroundColor(proteinType == type ? Color.appPrimary : Color.appTextSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(proteinType == type ? Color.appPrimary.opacity(0.12) : Color(hex: "F7F3EF"))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(proteinType == type ? Color.appPrimary : Color.clear, lineWidth: 1.2))
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: proteinType)
                }
            }
        }
        .sectionCard()
    }

    // MARK: - 参照URL

    private var sourceURLSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("参照URL")
            HStack(spacing: 8) {
                TextField("https://", text: $editingSourceURL)
                    .font(.system(size: 14))
                    .foregroundColor(Color.appTextPrimary)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(10)
                    .background(Color.appBackground)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appSeparator))
                    .onSubmit { saveSourceURL() }
                    .onChange(of: editingSourceURL) { _, _ in saveSourceURL() }

                if let url = URL(string: editingSourceURL), !editingSourceURL.isEmpty,
                   url.scheme == "https" || url.scheme == "http" {
                    Link(destination: url) {
                        Image(systemName: "safari.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.appPrimary)
                    }
                }
            }
        }
        .sectionCard()
    }

    private func saveSourceURL() {
        let trimmed = editingSourceURL.trimmingCharacters(in: .whitespaces)
        saveToStore { $0.sourceURL = trimmed }
    }

    // MARK: - メモ

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("メモ・工程メモ")
            TextEditor(text: $editingNote)
                .font(.system(size: 14))
                .foregroundColor(Color.appTextPrimary)
                .frame(minHeight: 100)
                .padding(10)
                .background(Color.appBackground)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.appSeparator, lineWidth: 1)
                )
                .onChange(of: editingNote) { _, _ in
                    saveNote()
                }
            if editingNote.isEmpty {
                Text("工程が省略されたレシピはここに貼り付けて保存できます")
                    .font(.system(size: 12))
                    .foregroundColor(Color.appTextTertiary)
                    .padding(.horizontal, 2)
            }
        }
        .sectionCard()
    }

    private func saveNote() {
        saveToStore { $0.note = editingNote }
    }

    // MARK: - PFC

    private var pfcSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("栄養素（1人分）")
                Spacer()
                Text("\(Int(calorie)) kcal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appPrimary)
            }

            HStack(spacing: 4) {
                let total = protein + fat + carb
                let p = total > 0 ? protein / total : 0.33
                let f = total > 0 ? fat / total : 0.33
                let c = total > 0 ? carb / total : 0.34
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 3).fill(Color(hex: "4A90D9")).frame(width: geo.size.width * p)
                        RoundedRectangle(cornerRadius: 3).fill(Color(hex: "E8A838")).frame(width: geo.size.width * f)
                        RoundedRectangle(cornerRadius: 3).fill(Color(hex: "6DB56B")).frame(width: geo.size.width * c)
                    }
                }
                .frame(height: 6)
            }

            HStack(spacing: 8) {
                pfcField(label: "P", color: Color(hex: "4A90D9"), value: $protein)
                pfcField(label: "F", color: Color(hex: "E8A838"), value: $fat)
                pfcField(label: "C", color: Color(hex: "6DB56B"), value: $carb)
            }

            Button {
                saveToStore {
                    $0.mainProteinType = proteinType
                    $0.protein = protein
                    $0.fat    = fat
                    $0.carb   = carb
                }
                pfcSaved = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { pfcSaved = false }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: pfcSaved ? "checkmark" : "square.and.arrow.down")
                        .font(.system(size: 13, weight: .semibold))
                    Text(pfcSaved ? "保存しました" : "栄養素を保存")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(pfcSaved ? Color(hex: "4A90D9") : Color.appPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(pfcSaved ? Color(hex: "EDF4FC") : Color(hex: "F5EDE2"))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: pfcSaved)
        }
        .sectionCard()
    }

    private func pfcField(label: String, color: Color, value: Binding<Double>) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
            HStack(spacing: 0) {
                TextField("0", value: value, format: .number)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 52)
                Text("g").font(.system(size: 12)).foregroundColor(Color.appTextSecondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(hex: "F7F3EF"))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - タグ

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("タグ")
                Spacer()
                Button {
                    withAnimation { showTagInput.toggle() }
                } label: {
                    Image(systemName: showTagInput ? "xmark" : "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.appPrimary)
                }
                .buttonStyle(.plain)
            }

            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text("#\(tag)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.appPrimary)
                            Button {
                                withAnimation { removeTag(tag) }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color.appPrimary.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.appPrimary.opacity(0.1))
                        .cornerRadius(20)
                    }
                }
            }

            if showTagInput {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("タグを入力...", text: $newTagText)
                            .font(.system(size: 14))
                            .submitLabel(.done)
                            .onSubmit { addTag(newTagText) }
                        if !newTagText.isEmpty {
                            Button { addTag(newTagText) } label: {
                                Text("追加")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.appPrimary)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(hex: "F7F3EF"))
                    .cornerRadius(8)

                    Text("よく使うタグ")
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextTertiary)
                    FlowLayout(spacing: 6) {
                        ForEach(tagSuggestions.filter { !tags.contains($0) }, id: \.self) { s in
                            Button { addTag(s) } label: {
                                Text(s)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color.appTextSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(hex: "F7F3EF"))
                                    .cornerRadius(20)
                                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appSeparator, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if tags.isEmpty && !showTagInput {
                Text("タグを追加して整理できます")
                    .font(.system(size: 13))
                    .foregroundColor(Color.appTextTertiary)
            }
        }
        .sectionCard()
    }

    private func addTag(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { newTagText = ""; return }
        tags.append(trimmed)
        newTagText = ""
        saveTagsToStore()
    }

    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
        saveTagsToStore()
    }

    private func saveTagsToStore() {
        saveToStore { $0.tags = tags }
    }

    // MARK: - サムネリフレッシュ

    private var thumbnailRefreshButton: some View {
        ZStack {
            Color(hex: "F5EDE2")
                .frame(maxWidth: .infinity).frame(height: 140)
            if isRefreshingThumb {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("画像を取得中...")
                        .font(.system(size: 12))
                        .foregroundColor(Color.appTextTertiary)
                }
            } else {
                Button {
                    refreshThumbnail()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.system(size: 28))
                            .foregroundColor(Color.appPrimary)
                        Text("画像を取得する")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.appPrimary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// ストアから最新を取得して更新する（各保存が他の変更を上書きしない）
    private func saveToStore(_ modify: (inout ImportedRecipe) -> Void) {
        var current = ImportedRecipeStore.shared.recipes.first { $0.id == recipe.id } ?? recipe
        modify(&current)
        ImportedRecipeStore.shared.update(current)
    }

    private func saveNameIfChanged() {
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        saveToStore { $0.name = trimmed }
    }

    private func saveImageToDocuments(data: Data, id: String) -> String? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("recipe_images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("\(id).jpg")
        // UIImage 経由で HEIC・WebP・PNG どの形式でも JPEG に変換
        guard let image = UIImage(data: data) else { return nil }
        let jpegData = image.jpegData(compressionQuality: 0.82)
            ?? image.pngData().flatMap { UIImage(data: $0)?.jpegData(compressionQuality: 0.82) }
        guard let jpeg = jpegData else { return nil }
        do {
            try jpeg.write(to: fileURL, options: .atomic)
        } catch {
            return nil
        }
        return "recipe_images/\(id).jpg"
    }

    private func refreshThumbnail() {
        guard !isRefreshingThumb else { return }
        isRefreshingThumb = true
        Task {
            do {
                let fetched = try await RecipeImportService.shared.importRecipe(from: recipe.sourceURL)
                await MainActor.run {
                    thumbURL = fetched.thumbnailURL
                    saveToStore { $0.thumbnailURL = fetched.thumbnailURL }
                    isRefreshingThumb = false
                }
            } catch {
                await MainActor.run { isRefreshingThumb = false }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color.appTextSecondary)
    }
}

// MARK: - View Extension

private extension View {
    func sectionCard() -> some View {
        self
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appSeparator))
    }
}

// MARK: - Local image path helper

/// アップデートでコンテナUUIDが変わっても画像を参照できるよう、
/// 絶対パス・相対パスの両方を現在のDocumentsディレクトリで解決する。
func resolveLocalImagePath(_ stored: String) -> String? {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    if stored.contains("recipe_images/") {
        // "recipe_images/UUID.jpg" 部分を取り出して現在のDocumentsに連結
        if let range = stored.range(of: "recipe_images/") {
            let relative = String(stored[range.lowerBound...])
            return docs.appendingPathComponent(relative).path
        }
    }
    // フォールバック: file:// スキームそのまま
    if stored.hasPrefix("file://") {
        return URL(string: stored)?.path
    }
    return nil
}

// MARK: - BackupEnvelope

private struct BackupEnvelope: Codable {
    var version: Int = 1
    var recipes: [ImportedRecipe]
    var images: [String: String]  // recipeId -> base64 JPEG
}

// MARK: - RecipeBackupDocument

struct RecipeBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(recipes: [ImportedRecipe]) {
        // file:// サムネイルをbase64に変換
        var images: [String: String] = [:]
        for recipe in recipes {
            guard let urlStr = recipe.thumbnailURL,
                  urlStr.hasPrefix("file://"),
                  let path = URL(string: urlStr)?.path,
                  let imgData = try? Data(contentsOf: URL(fileURLWithPath: path)) else { continue }
            images[recipe.id.uuidString] = imgData.base64EncodedString()
        }
        let envelope = BackupEnvelope(version: 1, recipes: recipes, images: images)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.data = (try? encoder.encode(envelope)) ?? Data()
    }

    init(configuration: ReadConfiguration) throws {
        guard let d = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = d
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    /// 復元処理: BackupEnvelope → [ImportedRecipe]（画像はDocumentsに書き戻し）
    static func restore(from data: Data) -> (recipes: [ImportedRecipe], count: Int)? {
        // 新形式（BackupEnvelope）を試みる
        if let envelope = try? JSONDecoder().decode(BackupEnvelope.self, from: data) {
            let restored = envelope.recipes.map { recipe -> ImportedRecipe in
                guard let b64 = envelope.images[recipe.id.uuidString],
                      let imgData = Data(base64Encoded: b64),
                      let saved = saveRestoredImage(data: imgData, id: recipe.id.uuidString)
                else { return recipe }
                var r = recipe; r.thumbnailURL = saved; return r
            }
            return (restored, restored.count)
        }
        // 旧形式（[ImportedRecipe]直列）にフォールバック
        if let recipes = try? JSONDecoder().decode([ImportedRecipe].self, from: data) {
            return (recipes, recipes.count)
        }
        return nil
    }

    private static func saveRestoredImage(data: Data, id: String) -> String? {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recipe_images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("\(id).jpg")
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.8) else { return nil }
        try? jpeg.write(to: fileURL)
        return fileURL.absoluteString
    }
}

// MARK: - RecipeThumbnailView

struct RecipeThumbnailView<Placeholder: View>: View {
    let urlStr: String
    let height: CGFloat
    let placeholder: () -> Placeholder

    var body: some View {
        Group {
            if let path = resolveLocalImagePath(urlStr),
               let uiImage = UIImage(contentsOfFile: path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .clipped()
            } else if let url = URL(string: urlStr), url.scheme == "https" || url.scheme == "http" {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: height)
                            .clipped()
                    default:
                        placeholder()
                    }
                }
            } else {
                placeholder()
            }
        }
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0; var y: CGFloat = 0; var maxH: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += maxH + spacing; maxH = 0 }
            maxH = max(maxH, size.height); x += size.width + spacing
        }
        return CGSize(width: width, height: y + maxH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var maxH: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += maxH + spacing; maxH = 0 }
            sub.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            maxH = max(maxH, size.height); x += size.width + spacing
        }
    }
}

// MARK: - AnimatedDownloadIcon

struct AnimatedDownloadIcon: View {
    var size: CGFloat = 110
    var color: Color = Color.primary

    @State private var arrowY: CGFloat = 0
    @State private var animTask: Task<Void, Never>?

    private var s:      CGFloat { size / 24 }
    private var sw:     CGFloat { 1.8 * s }
    private var boxTop: CGFloat { 11 * s }

    var body: some View {
        ZStack {
            Path { p in
                p.move(to: pt(12, 1)); p.addLine(to: pt(12, 14))
                p.move(to: pt(7, 9.5)); p.addLine(to: pt(12, 14.5)); p.addLine(to: pt(17, 9.5))
            }
            .stroke(color, style: StrokeStyle(lineWidth: sw, lineCap: .round, lineJoin: .round))
            .offset(y: arrowY)
            .mask {
                VStack(spacing: 0) {
                    Color.black.frame(height: boxTop)
                    Color.clear.frame(height: size - boxTop)
                }
                .frame(width: size, height: size)
            }

            Path { p in
                p.move(to: pt(3, 11)); p.addLine(to: pt(3, 20))
                p.addCurve(to: pt(5, 22), control1: pt(3, 21.1), control2: pt(3.9, 22))
                p.addLine(to: pt(19, 22))
                p.addCurve(to: pt(21, 20), control1: pt(20.1, 22), control2: pt(21, 21.1))
                p.addLine(to: pt(21, 11))
            }
            .stroke(color, style: StrokeStyle(lineWidth: sw, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .onAppear { startAnimation() }
        .onDisappear { animTask?.cancel() }
    }

    private func startAnimation() {
        animTask?.cancel(); arrowY = 0
        let d = 9 * s
        animTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 700_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeIn(duration: 0.4)) { arrowY = d }
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                arrowY = 0
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
            }
        }
    }

    private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
}

// MARK: - ImportHowToRow

struct ImportHowToRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appTextSecondary)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

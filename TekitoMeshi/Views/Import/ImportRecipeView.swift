import SwiftUI

struct ImportRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = RecipeImportService.shared
    @ObservedObject private var store  = ImportedRecipeStore.shared

    @ObservedObject private var bookmarkStore = URLBookmarkStore.shared

    @State private var importMode:          ImportMode = .url
    @State private var urlText:             String
    @State private var captionText:         String = ""
    @State private var preview:             ImportedRecipe? = nil
    @State private var errorMessage:        String?
    @State private var savedName            = ""
    @State private var showAddBookmarkAlert = false
    @State private var bookmarkLabelDraft   = ""
    @State private var editingBookmark:     URLBookmark? = nil
    @State private var editingLabelDraft    = ""

    enum ImportMode { case url, text }

    init(initialURL: String = "") {
        _urlText = State(initialValue: initialURL)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    modePicker

                    if importMode == .url {
                        urlInputSection
                    } else {
                        textInputSection
                    }

                    if service.isLoading {
                        loadingView
                    } else if let recipe = preview {
                        previewSection(recipe)
                    } else if let err = errorMessage {
                        errorView(err)
                    } else if importMode == .url {
                        hintSection
                    } else {
                        instagramHint
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("レシピをインポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(Color.appTextSecondary)
                }
            }
            .task {
                if !urlText.isEmpty && preview == nil {
                    await fetchRecipe()
                }
            }
            .onChange(of: importMode) { _, _ in
                preview = nil; errorMessage = nil
            }
        }
    }

    // MARK: - モード切替

    private var modePicker: some View {
        Picker("取り込み方法", selection: $importMode) {
            Text("URLから").tag(ImportMode.url)
            Text("テキストから").tag(ImportMode.text)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - テキスト入力

    private var textInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("レシピテキストを貼り付け")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.appTextSecondary)
                .kerning(0.5)

            TextEditor(text: $captionText)
                .font(.system(size: 14))
                .foregroundColor(Color.appTextPrimary)
                .frame(minHeight: 160)
                .padding(12)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appSeparator))

            Button {
                parseCaption()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 16))
                    Text("レシピを取り込む")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(captionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? Color.appPrimary.opacity(0.4) : Color.appPrimary)
                .cornerRadius(12)
            }
            .disabled(captionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var instagramHint: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("使い方")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.appTextSecondary)
                .kerning(0.5)

            VStack(spacing: 8) {
                ForEach([
                    ("1", "レシピのテキストをコピー"),
                    ("2", "上のテキストエリアに貼り付ける"),
                    ("3", "「レシピを取り込む」をタップ"),
                ], id: \.0) { num, text in
                    HStack(alignment: .top, spacing: 10) {
                        Text(num)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Color.appPrimary)
                            .clipShape(Circle())
                        Text(text)
                            .font(.system(size: 14))
                            .foregroundColor(Color.appTextPrimary)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appSeparator))
                }
            }

            // 使用例タグ
            VStack(alignment: .leading, spacing: 6) {
                Text("こんなレシピを取り込めます")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.appTextSecondary)
                    .kerning(0.3)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([
                            ("book.pages", "料理ブログ"),
                            ("camera", "Instagram"),
                            ("text.bubble", "X（旧Twitter）"),
                            ("note.text", "メモ帳"),
                            ("person.fill", "オリジナルレシピ"),
                            ("square.and.pencil", "自分のレシピメモ"),
                        ], id: \.1) { icon, label in
                            HStack(spacing: 4) {
                                Image(systemName: icon)
                                    .font(.system(size: 11))
                                Text(label)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(Color.appTextSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white)
                            .cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appSeparator))
                        }
                    }
                }
            }
            .padding(.top, 4)

            Text("材料・作り方が書かれているテキストほど精度が上がります")
                .font(.system(size: 12))
                .foregroundColor(Color.appTextSecondary)
                .padding(.top, 2)

            importUsageNotice
        }
    }

    // MARK: - URL入力

    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("レシピのURL")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.appTextSecondary)
                .kerning(0.5)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 14))
                        .foregroundColor(Color.appTextSecondary)
                    TextField("https://...", text: $urlText)
                        .font(.system(size: 14))
                        .foregroundColor(Color.appTextPrimary)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !urlText.isEmpty {
                        Button {
                            urlText = ""; preview = nil; errorMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color.appTextSecondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appSeparator))

                if isValidURL(urlText) {
                    let alreadySaved = bookmarkStore.contains(url: urlText)
                    Button {
                        bookmarkLabelDraft = URL(string: urlText)?.host ?? ""
                        showAddBookmarkAlert = true
                    } label: {
                        Image(systemName: alreadySaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 22))
                            .foregroundColor(alreadySaved ? Color.appPrimary : Color.appTextSecondary)
                    }
                    .disabled(alreadySaved)
                }

                Button {
                    Task { await fetchRecipe() }
                } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(urlText.isEmpty ? Color.appSeparator : Color.appPrimary)
                }
                .disabled(urlText.isEmpty || service.isLoading)
            }

            if bookmarkStore.bookmarks.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 11))
                    Text("よく使うサイトのURLを入力して右のアイコンでブックマーク登録できます")
                        .font(.system(size: 12))
                }
                .foregroundColor(Color.appTextSecondary)
                .padding(.top, 2)
            } else {
                bookmarkChips
            }
        }
        .alert("ブックマークに追加", isPresented: $showAddBookmarkAlert) {
            TextField("ラベル（省略可）", text: $bookmarkLabelDraft)
                .autocorrectionDisabled()
            Button("追加") {
                bookmarkStore.add(
                    url: urlText,
                    label: bookmarkLabelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("このURLをブックマークに保存します")
        }
    }

    private var bookmarkChips: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ブックマーク")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color.appTextSecondary)
                .kerning(0.3)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(bookmarkStore.bookmarks) { bookmark in
                        HStack(spacing: 4) {
                            Button {
                                urlText = bookmark.url
                                preview = nil
                                errorMessage = nil
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "bookmark.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color.appPrimary)
                                    Text(bookmark.displayLabel)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color.appTextPrimary)
                                }
                            }
                            Button {
                                bookmarkStore.delete(bookmark)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(Color.appTextSecondary)
                            }
                        }
                        .padding(.leading, 10)
                        .padding(.trailing, 8)
                        .padding(.vertical, 7)
                        .background(Color.white)
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appSeparator))
                        .contextMenu {
                            Button {
                                editingBookmark    = bookmark
                                editingLabelDraft  = bookmark.label
                            } label: {
                                Label("ラベルを編集", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                bookmarkStore.delete(bookmark)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .alert("ラベルを編集", isPresented: Binding(
            get: { editingBookmark != nil },
            set: { if !$0 { editingBookmark = nil } }
        )) {
            TextField("ラベル", text: $editingLabelDraft)
                .autocorrectionDisabled()
            Button("保存") {
                if var bm = editingBookmark {
                    bm.label = editingLabelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    bookmarkStore.update(bm)
                }
                editingBookmark = nil
            }
            Button("キャンセル", role: .cancel) { editingBookmark = nil }
        }
    }

    private func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return url.scheme == "https" || url.scheme == "http"
    }

    // MARK: - ローディング

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color.appPrimary)
            Text("レシピを読み込み中...")
                .font(.system(size: 14))
                .foregroundColor(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appSeparator))
    }

    // MARK: - エラー

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .foregroundColor(.red)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.red)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.05))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.2)))
    }

    // MARK: - プレビュー

    private func previewSection(_ recipe: ImportedRecipe) -> some View {
        VStack(alignment: .leading, spacing: 16) {

            Label("取得完了", systemImage: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "3D6B4A"))

            VStack(alignment: .leading, spacing: 0) {

                // サムネイル
                if let thumbURL = recipe.thumbnailURL, let url = URL(string: thumbURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                                .frame(maxWidth: .infinity).frame(height: 200).clipped()
                        default:
                            Color(hex: "F5EDE2").frame(maxWidth: .infinity).frame(height: 80)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {

                    // 料理名入力
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("料理名")
                                .font(.system(size: 11))
                                .foregroundColor(Color.appTextSecondary)
                            Image(systemName: "pencil")
                                .font(.system(size: 10))
                                .foregroundColor(Color.appTextSecondary)
                        }
                        TextField("料理名を入力", text: $savedName)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color.appTextPrimary)
                            .padding(8)
                            .background(Color.appBgSecondary)
                            .cornerRadius(8)
                    }

                    // メタ情報
                    HStack(spacing: 0) {
                        metaChip(icon: "clock", text: "\(recipe.cookTime)分")
                        metaChip(icon: "person.2", text: "\(recipe.servings)人分")
                        metaChip(icon: "fork.knife", text: recipe.category.label)
                        if !recipe.sourceName.isEmpty {
                            metaChip(icon: "globe", text: recipe.sourceName)
                        }
                    }

                    // 材料
                    if !recipe.ingredients.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.appPrimary)
                                Text("材料 \(recipe.ingredients.count)品")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.appTextPrimary)
                            }
                            .padding(.bottom, 8)

                            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { i, ing in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(Color.appPrimary.opacity(0.25))
                                        .frame(width: 5, height: 5)
                                    Text(ing)
                                        .font(.system(size: 13))
                                        .foregroundColor(Color.appTextPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                }
                                .padding(.vertical, 5)
                                if i < recipe.ingredients.count - 1 {
                                    Divider().padding(.leading, 15)
                                }
                            }
                        }
                    }

                    // 手順数
                    if !recipe.steps.isEmpty {
                        Divider()
                        HStack(spacing: 6) {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 12))
                                .foregroundColor(Color.appPrimary)
                            Text("作り方 \(recipe.steps.count)ステップ")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.appTextPrimary)
                        }
                    } else {
                        Divider()
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "C0994A"))
                            Text("作り方を取得できませんでした（元のページで確認してください）")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "C0994A"))
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.white)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appSeparator))

            // 保存ボタン
            Button {
                saveRecipe()
            } label: {
                Text("このレシピを保存する")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.appPrimary)
                    .cornerRadius(14)
            }
        }
    }

    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(text)
                .font(.system(size: 12))
        }
        .foregroundColor(Color.appTextSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(hex: "F7F3EF"))
        .cornerRadius(8)
        .padding(.trailing, 6)
    }

    // MARK: - ヒント

    private var hintSection: some View {
        VStack(spacing: 12) {
            Text("対応サイト")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.appTextSecondary)
                .kerning(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                ForEach([
                    ("https://cookpad.com",       "クックパッド",       "cookpad.com"),
                    ("https://delishkitchen.tv",  "デリッシュキッチン", "delishkitchen.tv"),
                    ("https://www.kurashiru.com", "クラシル",           "kurashiru.com"),
                    ("https://macaro-ni.jp",      "macaroni",           "macaro-ni.jp"),
                    ("https://oceans-nadia.com",  "Nadia",              "oceans-nadia.com"),
                ], id: \.0) { urlStr, name, domain in
                    HStack(spacing: 0) {
                        Link(destination: URL(string: urlStr)!) {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(hex: "3D6B4A"))
                                    .font(.system(size: 14))
                                Text(name)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.appTextPrimary)
                                Spacer()
                                HStack(spacing: 4) {
                                    Text(domain)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.appTextSecondary)
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color.appTextSecondary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        Button {
                            bookmarkStore.add(url: urlStr, label: name)
                        } label: {
                            Image(systemName: bookmarkStore.contains(url: urlStr) ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 15))
                                .foregroundColor(bookmarkStore.contains(url: urlStr) ? Color.appPrimary : Color.appTextSecondary)
                                .frame(width: 44, height: 44)
                        }
                        .disabled(bookmarkStore.contains(url: urlStr))
                    }
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appSeparator))
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13))
                    .foregroundColor(Color.appTextSecondary)
                Text("ブラウザのシェアボタンからも追加できます")
                    .font(.system(size: 13))
                    .foregroundColor(Color.appTextSecondary)
            }
            .padding(.top, 4)

            importUsageNotice
        }
    }

    private var importUsageNotice: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle")
                .font(.system(size: 11))
                .foregroundColor(Color.appTextSecondary)
                .padding(.top, 1)
            Text("取り込んだレシピは私的利用の目的にのみご使用ください。各サービスの利用規約に従ってご利用ください。")
                .font(.system(size: 11))
                .foregroundColor(Color.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func parseCaption() {
        errorMessage = nil
        preview      = nil
        let recipe   = service.importFromCaption(captionText)
        preview      = recipe
        savedName    = recipe.name
    }

    private func fetchRecipe() async {
        errorMessage = nil
        preview      = nil
        do {
            let recipe = try await service.importRecipe(from: urlText)
            preview    = recipe
            savedName  = recipe.name
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveRecipe() {
        guard var recipe = preview else { return }
        recipe = ImportedRecipe(
            id:           recipe.id,
            name:         savedName.isEmpty ? recipe.name : savedName,
            ingredients:  recipe.ingredients,
            steps:        recipe.steps,
            cookTime:     recipe.cookTime,
            servings:     recipe.servings,
            category:     recipe.category,
            sourceURL:    recipe.sourceURL,
            sourceName:   recipe.sourceName,
            thumbnailURL: recipe.thumbnailURL,
            note:         recipe.note,
            importedAt:   recipe.importedAt,
            protein:      recipe.protein,
            fat:          recipe.fat,
            carb:         recipe.carb
        )
        store.add(recipe)
        dismiss()
    }
}

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @StateObject private var vm           = SettingsViewModel()
    @ObservedObject private var subscription = SubscriptionManager.shared
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {

                        // ── プレミアム ──────────────────────────────
                        premiumSection

                        // ── 通知 ────────────────────────────────────
                        notificationSection

                        // ── 献立の目標 ──────────────────────────────
                        goalSection

                        // ── アプリ情報 ──────────────────────────────
                        appInfoSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .onAppear { vm.load() }
        .sheet(isPresented: $showPaywall) { PremiumPaywallView() }
    }

    // MARK: - ヘッダー

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("アプリ設定")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.appPrimary)
                    .kerning(1.2)
                Text("設定")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - プレミアム

    private var premiumSection: some View {
        settingsSection(header: "プレミアム") {
            if subscription.isPremium {
                HStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color.appPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.appPrimary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("プレミアム会員")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.appTextPrimary)
                        Text("全機能が利用可能です")
                            .font(.system(size: 13))
                            .foregroundColor(Color.appTextTertiary)
                    }
                    Spacer()
                    Text("有効")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.appGreenDark)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appAccentLight)
                        .clipShape(Capsule())
                }
                .padding(14)
                #if DEBUG
                Divider().padding(.horizontal, 14)
                Button("Free に戻す (Debug)") { subscription.setPremium(false) }
                    .font(.system(size: 13))
                    .foregroundColor(Color.appPrimary)
                    .padding(14)
                #endif
            } else {
                // アップグレードCTA
                Button { showPaywall = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.appPrimary)
                            .frame(width: 32, height: 32)
                            .background(Color.appPrimary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("プレミアムにアップグレード")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.appTextPrimary)
                            Text("月額480円")
                                .font(.system(size: 13))
                                .foregroundColor(Color.appTextTertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.appTextTertiary)
                    }
                    .padding(14)
                }
                .buttonStyle(.plain)

                Divider().padding(.horizontal, 14)

                // プレミアム機能一覧
                let features: [(String, Color, String, String)] = [
                    ("sparkles",            Color.appFish,      "AI献立生成",        "冷蔵庫の食材から最適な献立を提案"),
                    ("calendar.badge.plus", Color.appGreen,     "7日間献立",         "1週間分まとめて献立を作成"),
                    ("book.closed",         Color.appPrimary,   "マイレシピ無制限",   "お気に入りレシピを何件でも保存"),
                    ("chart.pie",           Color.appGreenDark, "栄養分析（PFC）",   "PFCバランスを毎日チェック"),
                    ("leaf",                Color.appGreenDark, "ダイエットモード",   "低カロリー献立を優先提案"),
                    ("bolt",                Color.appFish,      "筋トレモード",       "高たんぱく献立を優先提案"),
                ]
                VStack(spacing: 0) {
                    ForEach(Array(features.enumerated()), id: \.offset) { idx, f in
                        if idx > 0 { Divider().padding(.horizontal, 14) }
                        HStack(spacing: 12) {
                            Image(systemName: f.0)
                                .font(.system(size: 13))
                                .foregroundColor(f.1)
                                .frame(width: 28, height: 28)
                                .background(f.1.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(f.2)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.appTextPrimary)
                                Text(f.3)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.appTextTertiary)
                            }
                            Spacer()
                            Image(systemName: "lock")
                                .font(.system(size: 11))
                                .foregroundColor(Color.appTextTertiary.opacity(0.5))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }

                #if DEBUG
                Divider().padding(.horizontal, 14)
                Button("🔧 プレミアムにする (Debug)") { subscription.setPremium(true) }
                    .font(.system(size: 13))
                    .foregroundColor(Color.appPrimary)
                    .padding(14)
                #endif
            }
        }
    }

    // MARK: - 通知

    private var notificationSection: some View {
        settingsSection(header: "通知") {
            VStack(spacing: 0) {
                HStack {
                    Text("献立通知")
                        .font(.system(size: 15))
                        .foregroundColor(Color.appTextPrimary)
                    Spacer()
                    Toggle("", isOn: $vm.isNotificationEnabled)
                        .tint(Color.appPrimary)
                        .onChange(of: vm.isNotificationEnabled) { _, _ in vm.save() }
                }
                .padding(14)

                if vm.isNotificationEnabled {
                    Divider().padding(.horizontal, 14)
                    DatePicker(
                        "通知時刻",
                        selection: $vm.notificationDate,
                        displayedComponents: .hourAndMinute
                    )
                    .font(.system(size: 15))
                    .padding(14)

                    Divider().padding(.horizontal, 14)
                    HStack {
                        Text("不足食材がある日は早めに通知")
                            .font(.system(size: 15))
                            .foregroundColor(Color.appTextPrimary)
                        Spacer()
                        Toggle("", isOn: $vm.earlyReminderEnabled)
                            .tint(Color.appPrimary)
                            .onChange(of: vm.earlyReminderEnabled) { _, _ in vm.save() }
                    }
                    .padding(14)

                    Divider().padding(.horizontal, 14)
                    HStack(spacing: 8) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color.appPrimary)
                        Text("毎日 \(timeLabel) に「今日のごはん」をお知らせします")
                            .font(.system(size: 13))
                            .foregroundColor(Color.appTextTertiary)
                    }
                    .padding(14)
                }

                if vm.authStatus == .denied {
                    Divider().padding(.horizontal, 14)
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("通知が拒否されています。設定アプリから許可してください")
                            .font(.system(size: 13))
                            .foregroundColor(Color.appTextSecondary)
                    }
                    .padding(14)
                    Button("設定アプリを開く") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.system(size: 15))
                    .foregroundColor(Color.appPrimary)
                    .padding(14)
                } else if vm.authStatus == .notDetermined {
                    Divider().padding(.horizontal, 14)
                    Button("通知を許可する") { vm.requestPermissionIfNeeded() }
                        .font(.system(size: 15))
                        .foregroundColor(Color.appPrimary)
                        .padding(14)
                }
            }
        }
    }

    // MARK: - 献立の目標

    private var goalSection: some View {
        settingsSection(header: "献立の目標") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("食事の目標")
                                .font(.system(size: 15))
                                .foregroundColor(Color.appTextPrimary)
                            if !subscription.isPremium {
                                Text("PRO")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.appPrimary)
                                    .clipShape(Capsule())
                            }
                        }
                        Text("献立生成に自動で反映されます")
                            .font(.system(size: 12))
                            .foregroundColor(Color.appTextTertiary)
                    }
                    Spacer()
                }

                HStack(spacing: 8) {
                    ForEach(HealthMode.allCases, id: \.self) { mode in
                        GoalModeChip(
                            mode:       mode,
                            isSelected: vm.goalHealthMode == mode,
                            isPremium:  subscription.isPremium
                        ) {
                            if mode != .none && !subscription.isPremium {
                                showPaywall = true
                            } else {
                                vm.goalHealthMode = mode
                                vm.saveGoal()
                            }
                        }
                    }
                }
            }
            .padding(14)
        }
    }

    // MARK: - アプリ情報

    private let privacyURL = URL(string: "https://concent-apps.github.io/legal/totonogohan/privacy.html")!
    private let termsURL   = URL(string: "https://concent-apps.github.io/legal/totonogohan/terms.html")!
    private let contactURL = URL(string: "mailto:info.concent.jp@gmail.com")!

    private var appInfoSection: some View {
        settingsSection(header: "アプリについて") {
            VStack(spacing: 0) {
                HStack {
                    Text("バージョン")
                        .font(.system(size: 15))
                        .foregroundColor(Color.appTextPrimary)
                    Spacer()
                    Text(appVersion)
                        .font(.system(size: 15))
                        .foregroundColor(Color.appTextTertiary)
                }
                .padding(14)

                Divider().padding(.horizontal, 14)

                HStack {
                    Text("サンプルレシピ数")
                        .font(.system(size: 15))
                        .foregroundColor(Color.appTextPrimary)
                    Spacer()
                    Text("\(SampleRecipes.all.count)品")
                        .font(.system(size: 15))
                        .foregroundColor(Color.appTextTertiary)
                }
                .padding(14)

                Divider().padding(.horizontal, 14)

                Link(destination: privacyURL) {
                    HStack {
                        Text("プライバシーポリシー")
                            .font(.system(size: 15))
                            .foregroundColor(Color.appTextPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.appTextTertiary)
                    }
                    .padding(14)
                }

                Divider().padding(.horizontal, 14)

                Link(destination: termsURL) {
                    HStack {
                        Text("利用規約")
                            .font(.system(size: 15))
                            .foregroundColor(Color.appTextPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.appTextTertiary)
                    }
                    .padding(14)
                }

                Divider().padding(.horizontal, 14)

                Link(destination: contactURL) {
                    HStack {
                        Text("お問い合わせ")
                            .font(.system(size: 15))
                            .foregroundColor(Color.appTextPrimary)
                        Spacer()
                        Image(systemName: "envelope")
                            .font(.system(size: 13))
                            .foregroundColor(Color.appTextTertiary)
                    }
                    .padding(14)
                }
            }
        }
    }

    // MARK: - セクション共通

    @ViewBuilder
    private func settingsSection<Content: View>(
        header: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(header)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.appTextTertiary)
                .kerning(0.5)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.white)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appSeparator, lineWidth: 1))
        }
    }

    // MARK: - Helpers

    private var timeLabel: String {
        String(format: "%02d:%02d", vm.notificationHour, vm.notificationMinute)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}

// MARK: - GoalModeChip

private struct GoalModeChip: View {
    let mode:       HealthMode
    let isSelected: Bool
    let isPremium:  Bool
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if mode != .none && !isPremium {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .medium))
                }
                Text(mode.label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : Color.appTextSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isSelected ? chipColor : Color.appBackground)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.clear : Color.appSeparator, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
    }

    private var chipColor: Color {
        switch mode {
        case .none:   return Color.appTextSecondary
        case .diet:   return Color.appGreen
        case .muscle: return Color.appMuscle
        }
    }
}

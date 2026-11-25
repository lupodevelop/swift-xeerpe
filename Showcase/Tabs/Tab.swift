#if os(macOS)
import SwiftUI
import xeerpe

// Tabs are grouped by where an app would use the effects: first how a chain
// works, then payments, messaging, privacy, status, photos, play and brand,
// then the reference tabs.

enum Tab: String, CaseIterable, Identifiable {
    case start = "Start", payments = "Payments", messaging = "Messaging", privacy = "Privacy", status = "Status"
    case photo = "Photo", play = "Play", brand = "Brand", reveal = "Reveal", backgrounds = "Backgrounds", catalog = "Catalog"
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .start: "play.circle"
        case .payments: "creditcard"
        case .messaging: "bubble.left.and.bubble.right"
        case .privacy: "lock"
        case .status: "gauge.with.dots.needle.50percent"
        case .photo: "camera"
        case .play: "gamecontroller"
        case .brand: "seal"
        case .reveal: "eye"
        case .backgrounds: "drop"
        case .catalog: "square.grid.3x3"
        }
    }

    @MainActor @ViewBuilder
    func content(start: Double) -> some View {
        switch self {
        case .start: StartTab()
        case .payments: PaymentsTab()
        case .messaging: MessagingTab()
        case .privacy: PrivacyTab()
        case .status: StatusTab()
        case .photo: VStack(alignment: .leading, spacing: 44) { PhotoEditor(); FilmDemo() }
        case .play: PlayTab()
        case .brand: BrandTab()
        case .reveal: VStack(alignment: .leading, spacing: 44) { Reveals(start: start); DustDelete() }
        case .backgrounds: Surfaces()
        case .catalog: CatalogBrowser()
        }
    }
}

/// A phone mockup beside the title of what it shows.
@MainActor
private func phoneSection(_ title: String, _ hint: String, @ViewBuilder _ phone: () -> some View) -> some View {
    HStack(alignment: .top, spacing: 28) {
        phone()
        heading(title, hint).frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor
struct StartTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 44) {
            BasicsGrid()
            CRTDemo()
            DeviceScreens()
            ScannerDemo()
        }
    }
}

@MainActor
struct PaymentsTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 44) {
            phoneSection("Wallet", "The wallet hides the balance behind the eye; rows show under the pointer.") { WalletPhone() }
            CardRow()
            MetalCardDemo()
            SignsDemo(cards: true)
            TicketDemo()
            SendGift()
            TapToCash()
        }
    }
}

@MainActor
struct MessagingTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 44) {
            phoneSection("Chat", "Tap a spoiler to dissolve it, tap again to hide it.") { ChatPhone() }
            BurnDemo()
            if #available(macOS 15, *) { TextRiseDemo() }
            GooeyDemo()
            AssistantDemo()
        }
    }
}

@MainActor
struct PrivacyTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 44) {
            phoneSection("Lock screen", "Notifications stay blurred until the pointer is on them. The clock and the wallpaper turn with the tilt.") { LockPhone() }
            PrivacyDemo()
            ProgressiveBlur()
            RetroScreens()
            VaultDemo()
        }
    }
}

@MainActor
struct StatusTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 44) {
            LoadingFeed()
            VStack(alignment: .leading, spacing: 18) {
                heading("Jobs", "Any async work as a job: a model, a fingerprint, a render. Its phase, progress and result are signals every effect can read.")
                ExportDemo()
            }
            VolumeLimit()
            PulseAndLight()
            SmokeSparksDemo()
            GenieDemo()
        }
    }
}

@MainActor
struct PlayTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 44) {
            ScratchTicket()
            GameBoyDemo()
            ToonDemo()
            ComicChains()
            TapePrintDemo()
        }
    }
}

@MainActor
struct BrandTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 44) {
            AppIconDemo()
            Glyphs()
            SignsDemo()
            FoilDemo()
            DialDemo()
            JewelDemo()
        }
    }
}
#endif

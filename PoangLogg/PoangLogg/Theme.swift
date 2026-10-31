import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Color {
    init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) }

    /// En färg som byter värde i mörkt läge.
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { trait in
            UIColor(hex: trait.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

/// Samma färger som webbversionen av Poänglogg.
enum Theme {
    static let court = Color.black
    static let red = Color.dynamic(0xD7192B, 0xFF3344)
    static let bg = Color.dynamic(0xF3F3F3, 0x0B0B0B)
    static let surface = Color.dynamic(0xFFFFFF, 0x181818)
    static let ink = Color.dynamic(0x000000, 0xF5F5F5)
    static let muted = Color.dynamic(0x5E5E5E, 0xA3A3A3)
    static let rule = Color.dynamic(0xD9D9D9, 0x2F2F2F)
    static let own = Color.dynamic(0xD7192B, 0xFF3344)
    static let ownSoft = Color.dynamic(0xFBE4E6, 0x3A1013)
    static let forced = Color.dynamic(0x7A0E17, 0xC2505A)
    static let forcedSoft = Color.dynamic(0xF0E2E3, 0x2A1517)
    static let win = Color.dynamic(0x000000, 0xFFFFFF)
    static let winSoft = Color.dynamic(0xE9E9E9, 0x262626)
    static let onWin = Color.dynamic(0xFFFFFF, 0x000000)

    static let w = [Color.dynamic(0x000000, 0xFFFFFF), .dynamic(0x404040, 0xD4D4D4),
                    .dynamic(0x262626, 0xEAEAEA), .dynamic(0x595959, 0xBDBDBD)]
    static let oe = [Color.dynamic(0x8C8C8C, 0x7A7A7A), .dynamic(0xB3B3B3, 0x5C5C5C),
                     .dynamic(0xA0A0A0, 0x8F8F8F), .dynamic(0xC6C6C6, 0x6B6B6B)]

    static func palette(_ type: ReasonType) -> [Color] {
        switch type {
        case .own:
            return [own, Color(hex: 0xF2636D), Color(hex: 0xA3101C), Color(hex: 0xFF9AA1),
                    Color(hex: 0xE0452F), Color(hex: 0xC23A47)]
        case .forced:
            return [forced, Color(hex: 0x5A1F24), Color(hex: 0x9E3A44), Color(hex: 0x8A5A5E)]
        case .opperr: return oe
        case .winner: return w
        case .unspec: return [win]
        }
    }

    static func accent(_ type: ReasonType) -> Color {
        switch type {
        case .own: return own
        case .forced: return forced
        case .opperr: return oe[0]
        case .winner, .unspec: return win
        }
    }

    static func soft(_ type: ReasonType) -> Color {
        switch type {
        case .own: return ownSoft
        case .forced: return forcedSoft
        case .opperr, .winner, .unspec: return winSoft
        }
    }
}

extension Font {
    /// Stora, smala siffror som i resultattavlan.
    static func scoreboard(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.condensed)
    }

    static let sectionTitle = Font.system(size: 22, weight: .bold).width(.condensed)
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// Vit kantad knapp på den svarta resultattavlan.
struct OutlineOnDarkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10).padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.55), lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Neutral knapp med ram, som `.btn` på webben.
struct PlainBoxStyle: ButtonStyle {
    var foreground: Color = Theme.ink
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.rule, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title).font(.sectionTitle)
            if let subtitle {
                Text(subtitle).font(.subheadline.weight(.medium)).foregroundStyle(Theme.muted)
            }
        }
        .padding(.top, 18).padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Spelarens bild om den finns i Assets ("Player"), annars initialen.
struct PlayerAvatar: View {
    let name: String
    let size: CGFloat
    var ring: CGFloat = 2

    var body: some View {
        Group {
            if let img = UIImage(named: "Player") {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Text(String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
                    .font(.system(size: size * 0.45, weight: .bold).width(.condensed))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(hex: 0x2A2A2A))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Theme.red, lineWidth: ring))
        .accessibilityHidden(true)
    }
}

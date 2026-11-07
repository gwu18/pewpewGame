import SwiftUI
import UIKit

/// The 32×32 target face as a crisp icon (visual spec §5.1 pixel ornaments).
struct FaceIcon: View {
    var size: CGFloat

    private static let image: UIImage = {
        let map = PixelTargetMap.normal()
        let n = map.count
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: n, height: n), format: format).image { context in
            for y in 0..<n {
                for x in 0..<n {
                    guard let color = color(map[y][x]) else { continue }
                    color.setFill()
                    context.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }()

    private static func color(_ pixel: FacePixel) -> UIColor? {
        switch pixel {
        case .clear: nil
        case .gold: Theme.Palette.bullseyeGold.uiColor
        case .shine: Theme.Palette.goldShine.uiColor
        case .red: Theme.Palette.targetRed.uiColor
        case .blue: Theme.Palette.ringBlue.uiColor
        case .ink: Theme.Palette.ink.uiColor
        case .paper: Theme.Palette.paper.uiColor
        }
    }

    var body: some View {
        Image(uiImage: Self.image)
            .interpolation(.none)
            .resizable()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Face icon + "PEWPEW" in Press Start 2P, Target Red with a hard Ink shadow.
struct Wordmark: View {
    var logoSize: CGFloat
    var iconSize: CGFloat

    var body: some View {
        HStack(spacing: 18) {
            FaceIcon(size: iconSize)
            Text("PEWPEW")
                .font(Theme.Fonts.pixel(logoSize))
                .foregroundStyle(Theme.Palette.targetRed.color)
                .pixelShadow(Theme.Shadow.logo)
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("PewPew")
    }
}

/// 4 pt pixel dash, 8 on / 8 off, white 22 %.
struct PixelDivider: View {
    var body: some View {
        Canvas { context, size in
            var x: CGFloat = 0
            while x < size.width {
                context.fill(Path(CGRect(x: x, y: 0, width: 8, height: 4)), with: .color(.white.opacity(0.22)))
                x += 16
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

struct PrimaryPixelButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Theme.Space.xl)
            .frame(minHeight: Theme.Metrics.primaryButtonHeight)
            .background(Theme.Palette.buttonRed.color, in: .capsule)
            .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 2))
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .contentShape(.hoverEffect, .capsule)
            .hoverEffect(.highlight)
    }
}

extension View {
    /// START / PLAY AGAIN / ENTER ARENA: solid Button Red capsule with a 24 pt pixel label (spec §5.4).
    /// A tinted `.borderedProminent` renders washed-out salmon on glass, so the fill is drawn here and
    /// the system hover highlight is kept.
    func primaryPixelButton() -> some View {
        font(Theme.Fonts.pixel(Theme.TypeSize.button))
            .foregroundStyle(.white)
            .buttonStyle(PrimaryPixelButtonStyle())
            .frame(maxWidth: .infinity, minHeight: Theme.Metrics.primaryButtonHeight)
    }

    func secondaryButton() -> some View {
        font(Theme.Fonts.row)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .frame(minHeight: Theme.Metrics.secondaryButtonHeight)
    }
}

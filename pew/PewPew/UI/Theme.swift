import SwiftUI
import UIKit

struct PewColor: Sendable {
    let hex: UInt32
    init(_ hex: UInt32) { self.hex = hex }
    private var r: CGFloat { CGFloat((hex >> 16) & 0xFF) / 255 }
    private var g: CGFloat { CGFloat((hex >> 8) & 0xFF) / 255 }
    private var b: CGFloat { CGFloat(hex & 0xFF) / 255 }
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
    var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }
}

enum Theme {
    enum Palette {
        static let paper        = PewColor(0xF4F1E8)
        static let ink          = PewColor(0x1B1B1F)
        static let ringBlue     = PewColor(0x2B6FD6)
        static let targetRed    = PewColor(0xE8402A)
        static let bullseyeGold = PewColor(0xFFC93C)
        static let goldShine    = PewColor(0xFFF1B8)
        static let blasterMint  = PewColor(0x3EE6C1)
        static let missGray     = PewColor(0x9AA0A6)
        static let grayRampLo   = PewColor(0x5F6368)
        static let grayRampHi   = PewColor(0xC9CDD1)
        static let buttonRed    = PewColor(0xC8321E)
        static let flashWhite   = PewColor(0xFFFFFF)
    }

    enum Fonts {
        static let pixelName = "PressStart2P-Regular"
        static let pixelAvailable = UIFont(name: pixelName, size: 24) != nil
        /// Press Start 2P: multiples of 8 pt, >= 24 pt, UPPERCASE / numbers only.
        static func pixel(_ size: CGFloat) -> Font {
            pixelAvailable ? .custom(pixelName, fixedSize: size)
                           : .system(size: size, weight: .black, design: .monospaced)
        }
        static func pixelUIFont(_ size: CGFloat) -> UIFont {
            UIFont(name: pixelName, size: size) ?? .monospacedSystemFont(ofSize: size, weight: .black)
        }
        static func number(_ size: CGFloat) -> Font {
            .system(size: size, weight: .heavy, design: .rounded).monospacedDigit()
        }
        static let row      = Font.system(size: 20, weight: .semibold)
        static let body     = Font.system(size: 20)
        static let caption  = Font.system(size: 17)
        static let hudLabel = Font.system(size: 17, weight: .bold)
        static let hint     = Font.system(size: 22, weight: .semibold)
        static let tutorial = Font.system(size: 28, weight: .heavy, design: .rounded)
    }

    enum Space {
        static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16
        static let xl: CGFloat = 24, xxl: CGFloat = 32, panelH: CGFloat = 40, panelV: CGFloat = 36
    }

    enum Radius {
        static let panel: CGFloat = 46, hud: CGFloat = 40, tutorial: CGFloat = 36
        static let tile: CGFloat = 22, chip: CGFloat = 10
    }

    enum Metrics {
        static let launcher = CGSize(width: 520, height: 380)
        static let lobby    = CGSize(width: 600, height: 700)
        static let results  = CGSize(width: 640, height: 600)
        static let hud      = CGSize(width: 460, height: 128)
        static let tutorial = CGSize(width: 460, height: 200)
        static let countdownDisc: CGFloat = 300
        static let goCapsule = CGSize(width: 360, height: 200)
        static let primaryButtonHeight: CGFloat = 68
        static let secondaryButtonHeight: CGFloat = 60
        static let pickerWidth: CGFloat = 370
        static let rowLabelWidth: CGFloat = 130
        static let pointsPerMeter: CGFloat = 1360   // verify with PhysicalMetrics on device
    }

    enum TypeSize {   // display sizes, pt
        static let logo: CGFloat = 48, launcherLogo: CGFloat = 56, countdown: CGFloat = 160
        static let hudTime: CGFloat = 64, hudScore: CGFloat = 32, resultsScore: CGFloat = 64
        static let header: CGFloat = 24, button: CGFloat = 24, chip: CGFloat = 24, stat: CGFloat = 34
    }

    enum Shadow {   // hard pixel shadows (radius 0)
        static let logo: CGFloat = 4, hero: CGFloat = 5, countdown: CGFloat = 10
    }
}

extension View {
    func pixelShadow(_ offset: CGFloat) -> some View {
        shadow(color: Theme.Palette.ink.color, radius: 0, x: offset, y: offset)
    }
}

import CoreGraphics
import RealityKit
import UIKit

enum FacePixel: UInt8 { case clear, gold, shine, red, blue, ink, paper }

enum PixelTargetMap {
    static let grid = 32
    static let ringEdges: [(Float, FacePixel)] = [(0.20, .gold), (0.40, .red), (0.66, .blue), (0.79, .ink), (1.00, .paper)]
    private static let tiePriority: [FacePixel: Int] = [.clear: 0, .paper: 1, .ink: 2, .blue: 3, .red: 4, .gold: 5]

    static let goldenNormal = """
    ............KKKKKKKK............
    .........KKKPPPPPPPPKKK.........
    .......KKPPPPPPPPPPPPPPKK.......
    ......KPPPPPPPKKKKPPPPPPPK......
    .....KPPPPPKKKKKKKKKKPPPPPK.....
    ....KPPPPKKKKKBBBBKKKKKPPPPK....
    ...KPPPPKKKBBBBBBBBBBKKKPPPPK...
    ..KPPPPKKKBBBBBBBBBBBBKKKPPPPK..
    ..KPPPKKKBBBBBBBBBBBBBBKKKPPPK..
    .KPPPKKKBBBBBKKKKKKBBBBBKKKPPPK.
    .KPPPKKBBBBKKRRRRRRKKBBBBKKPPPK.
    .KPPKKBBBBKRRRRRRRRRRKBBBBKKPPK.
    KPPPKKBBBBKRRRRRRRRRRKBBBBKKPPPK
    KPPPKKBBBKRRRRgGGGRRRRKBBBKKPPPK
    KPPKKBBBBKRRRgGGGGGRRRKBBBBKKPPK
    KPPKKBBBBKRRRGGGGGGRRRKBBBBKKPPK
    KPPKKBBBBKRRRGGGGGGRRRKBBBBKKPPK
    KPPKKBBBBKRRRGGGGGGRRRKBBBBKKPPK
    KPPPKKBBBKRRRRGGGGRRRRKBBBKKPPPK
    KPPPKKBBBBKRRRRRRRRRRKBBBBKKPPPK
    .KPPKKBBBBKRRRRRRRRRRKBBBBKKPPK.
    .KPPPKKBBBBKKRRRRRRKKBBBBKKPPPK.
    .KPPPKKKBBBBBKKKKKKBBBBBKKKPPPK.
    ..KPPPKKKBBBBBBBBBBBBBBKKKPPPK..
    ..KPPPPKKKBBBBBBBBBBBBKKKPPPPK..
    ...KPPPPKKKBBBBBBBBBBKKKPPPPK...
    ....KPPPPKKKKKBBBBKKKKKPPPPK....
    .....KPPPPPKKKKKKKKKKPPPPPK.....
    ......KPPPPPPPKKKKPPPPPPPK......
    .......KKPPPPPPPPPPPPPPKK.......
    .........KKKPPPPPPPPKKK.........
    ............KKKKKKKK............
    """

    static func normal() -> [[FacePixel]] {
        let n = grid, r = Float(n) / 2
        func ring(_ px: Float, _ py: Float) -> FacePixel {
            let d = ((px - r) * (px - r) + (py - r) * (py - r)).squareRoot() / r
            if d > 1 { return .clear }
            return ringEdges.first { d <= $0.0 }!.1
        }
        var base = Array(repeating: Array(repeating: FacePixel.clear, count: n), count: n)
        for y in 0..<n { for x in 0..<n {
            var votes: [FacePixel: Int] = [:]
            for sy in 0..<4 { for sx in 0..<4 {
                votes[ring(Float(x) + (Float(sx) + 0.5) / 4, Float(y) + (Float(sy) + 0.5) / 4), default: 0] += 1
            } }
            base[y][x] = votes.max { ($0.value, tiePriority[$0.key]!) < ($1.value, tiePriority[$1.key]!) }!.key
        } }
        func at(_ m: [[FacePixel]], _ x: Int, _ y: Int) -> FacePixel { (0..<n).contains(x) && (0..<n).contains(y) ? m[y][x] : .clear }
        var out = base
        for y in 0..<n { for x in 0..<n where base[y][x] != .clear {
            let ns = [at(base, x + 1, y), at(base, x - 1, y), at(base, x, y + 1), at(base, x, y - 1)]
            if ns.contains(.clear) { out[y][x] = .ink }
            else if base[y][x] == .blue && ns.contains(.red) { out[y][x] = .ink }
        } }
        out[13][14] = .shine; out[14][13] = .shine
        return out
    }

    static func isOutline(_ m: [[FacePixel]], _ x: Int, _ y: Int) -> Bool {
        let n = m.count
        guard m[y][x] != .clear else { return false }
        return [(1, 0), (-1, 0), (0, 1), (0, -1)].contains { dx, dy in
            let xx = x + dx, yy = y + dy
            return !(0..<n).contains(xx) || !(0..<n).contains(yy) || m[yy][xx] == .clear
        }
    }

    static func small() -> [[FacePixel]] {
        let m = normal(), n = m.count
        var out = m
        for y in 0..<n { for x in 0..<n where m[y][x] != .clear && !isOutline(m, x, y) {
            let touchesOutline = [(1, 0), (-1, 0), (0, 1), (0, -1)].contains { dx, dy in
                (0..<n).contains(x + dx) && (0..<n).contains(y + dy) && isOutline(m, x + dx, y + dy)
            }
            if touchesOutline { out[y][x] = .gold }
        } }
        return out
    }

    static func ascii(_ m: [[FacePixel]]) -> String {
        let ch: [FacePixel: Character] = [.clear: ".", .gold: "G", .shine: "g", .red: "R", .blue: "B", .ink: "K", .paper: "P"]
        return m.map { String($0.map { ch[$0]! }) }.joined(separator: "\n")
    }
}

struct TargetMaterials {
    var normal: UnlitMaterial
    var small: UnlitMaterial
    var normalGray: UnlitMaterial
    var smallGray: UnlitMaterial
    var flash: UnlitMaterial
    var flashGold: UnlitMaterial
    var ping: UnlitMaterial
    var shockwave: UnlitMaterial
    var inkBody: PhysicallyBasedMaterial
    var shards: [UnlitMaterial]
}

enum TargetTextures {
    @MainActor
    static func load() async throws -> TargetMaterials {
        #if DEBUG
        assert(PixelTargetMap.ascii(PixelTargetMap.normal()) == PixelTargetMap.goldenNormal)
        #endif
        let normalMap = PixelTargetMap.normal()
        let smallMap = PixelTargetMap.small()
        let normal = try await cutout(image(colored(normalMap)))
        let small = try await cutout(image(colored(smallMap)))
        let normalGray = try await cutout(image(gray(normalMap)))
        let smallGray = try await cutout(image(gray(smallMap)))
        let flash = try await cutout(image(flashMap(normalMap, fill: Theme.Palette.flashWhite.uiColor)))
        let flashGold = try await cutout(image(flashMap(normalMap, fill: Theme.Palette.goldShine.uiColor)))
        let ping = try await cutout(image(ringImage(color: Theme.Palette.paper.uiColor)))
        let shockwave = try await cutout(image(ringImage(color: Theme.Palette.bullseyeGold.uiColor)))
        let shardColors = [
            Theme.Palette.paper.uiColor,
            Theme.Palette.ink.uiColor,
            Theme.Palette.ringBlue.uiColor,
            Theme.Palette.targetRed.uiColor,
            Theme.Palette.bullseyeGold.uiColor,
            Theme.Palette.goldShine.uiColor,
        ]
        return TargetMaterials(
            normal: normal,
            small: small,
            normalGray: normalGray,
            smallGray: smallGray,
            flash: flash,
            flashGold: flashGold,
            ping: ping,
            shockwave: shockwave,
            inkBody: inkBody(),
            shards: shardColors.map { solid($0) }
        )
    }

    @MainActor private static func colored(_ map: [[FacePixel]]) -> [[SIMD4<UInt8>]] {
        map.map { row in row.map(color(for:)) }
    }

    @MainActor private static func color(for pixel: FacePixel) -> SIMD4<UInt8> {
        switch pixel {
        case .clear: return SIMD4(0, 0, 0, 0)
        case .gold: return bytes(Theme.Palette.bullseyeGold.uiColor)
        case .shine: return bytes(Theme.Palette.goldShine.uiColor)
        case .red: return bytes(Theme.Palette.targetRed.uiColor)
        case .blue: return bytes(Theme.Palette.ringBlue.uiColor)
        case .ink: return bytes(Theme.Palette.ink.uiColor)
        case .paper: return bytes(Theme.Palette.paper.uiColor)
        }
    }

    private static func gray(_ map: [[FacePixel]]) -> [[SIMD4<UInt8>]] {
        let lo = bytes(Theme.Palette.grayRampLo.uiColor)
        let hi = bytes(Theme.Palette.grayRampHi.uiColor)
        return map.map { row in
            row.map { pixel in
                let source = color(for: pixel)
                guard source.w > 0 else { return source }
                let t = relativeLuminance(source)
                return SIMD4(
                    UInt8(Float(lo.x) + (Float(hi.x) - Float(lo.x)) * t),
                    UInt8(Float(lo.y) + (Float(hi.y) - Float(lo.y)) * t),
                    UInt8(Float(lo.z) + (Float(hi.z) - Float(lo.z)) * t),
                    255
                )
            }
        }
    }

    private static func flashMap(_ map: [[FacePixel]], fill: UIColor) -> [[SIMD4<UInt8>]] {
        let fillBytes = bytes(fill)
        let ink = bytes(Theme.Palette.ink.uiColor)
        let n = map.count
        return (0..<n).map { y in
            (0..<n).map { x in
                let pixel = map[y][x]
                if pixel == .clear { return SIMD4<UInt8>(0, 0, 0, 0) }
                return PixelTargetMap.isOutline(map, x, y) ? ink : fillBytes
            }
        }
    }

    private static func ringImage(color: UIColor) -> [[SIMD4<UInt8>]] {
        let paper = bytes(color)
        let ink = bytes(Theme.Palette.ink.uiColor)
        let n = 32
        let r = Float(n) / 2
        return (0..<n).map { y in
            (0..<n).map { x in
                let dx = Float(x) + 0.5 - r
                let dy = Float(y) + 0.5 - r
                let d = (dx * dx + dy * dy).squareRoot() / r
                if d > 1 || d < 0.62 { return SIMD4<UInt8>(0, 0, 0, 0) }
                return d > 0.88 ? ink : paper
            }
        }
    }

    private static func image(_ pixels: [[SIMD4<UInt8>]]) -> CGImage {
        let grid = pixels.count
        let block = 16
        let size = grid * block
        var data = [UInt8](repeating: 0, count: size * size * 4)
        for y in 0..<grid {
            let flipped = (grid - 1 - y) * block
            for x in 0..<grid {
                let pixel = pixels[y][x]
                for by in 0..<block {
                    for bx in 0..<block {
                        let index = ((flipped + by) * size + x * block + bx) * 4
                        data[index] = pixel.x
                        data[index + 1] = pixel.y
                        data[index + 2] = pixel.z
                        data[index + 3] = pixel.w
                    }
                }
            }
        }
        let provider = CGDataProvider(data: Data(data) as CFData)!
        return CGImage(
            width: size,
            height: size,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }

    @MainActor
    private static func cutout(_ image: CGImage) async throws -> UnlitMaterial {
        let texture = try await TextureResource(image: image, withName: nil, options: .init(semantic: .color))
        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        material.opacityThreshold = 0.5
        return material
    }

    private static func solid(_ color: UIColor) -> UnlitMaterial {
        UnlitMaterial(color: color)
    }

    private static func inkBody() -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: Theme.Palette.ink.uiColor)
        material.roughness.scale = 0.55
        material.metallic.scale = 0
        material.faceCulling = .none
        return material
    }

    @MainActor private static func bytes(_ color: UIColor) -> SIMD4<UInt8> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD4(UInt8(r * 255), UInt8(g * 255), UInt8(b * 255), 255)
    }

    private static func relativeLuminance(_ pixel: SIMD4<UInt8>) -> Float {
        func linear(_ channel: UInt8) -> Float {
            let value = Float(channel) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(pixel.x) + 0.7152 * linear(pixel.y) + 0.0722 * linear(pixel.z)
    }
}

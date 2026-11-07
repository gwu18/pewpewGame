#if DEBUG
import Foundation

/// Launch arguments for simulator screenshots and smoke runs, e.g.
/// `xcrun simctl launch booted <bundle id> -PewEnterArena -PewAutoplay`.
enum LaunchFlags {
    private static let arguments = Set(ProcessInfo.processInfo.arguments)
    static let enterArena = arguments.contains("-PewEnterArena")
    static let autoplay = arguments.contains("-PewAutoplay")
    static let showDebug = arguments.contains("-PewShowDebug")
    static let howToPlay = arguments.contains("-PewHowToPlay")
    static let roam = arguments.contains("-PewRoam")
    static let popupDemo = arguments.contains("-PewPopupDemo")
}
#endif

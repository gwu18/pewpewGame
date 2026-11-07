import AVFoundation

/// Menu click sounds (sound-design §2, UI rows). Gameplay audio belongs to the M7a AudioBank.
@MainActor
enum UISound {
    enum Cue: String, CaseIterable {
        case tap = "ui_tap"
        case back = "ui_back"
        case toggleOn = "ui_toggle_on"
        case toggleOff = "ui_toggle_off"
    }

    private static var players: [Cue: AVAudioPlayer] = [:]

    static func preload() {
        guard players.isEmpty else { return }
        for cue in Cue.allCases {
            guard let url = Bundle.main.url(forResource: cue.rawValue, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[cue] = player
        }
    }

    static func play(_ cue: Cue) {
        preload()
        guard let player = players[cue] else { return }
        player.currentTime = 0
        player.play()
    }
}

import Foundation

public struct PerRing<T: Sendable>: Sendable {
    public var outer: T
    public var red: T
    public var gold: T

    public init(outer: T, red: T, gold: T) {
        self.outer = outer
        self.red = red
        self.gold = gold
    }
}

public struct Tuning: Sendable {
    public var round = Round()
    public var spawn = Spawn()
    public var targets = Targets()
    public var score = Score()
    public var gesture = Gesture()
    public var touch = Touch()
    public var fx = FX()
    public var hud = HUD()
    public var bands = Bands()
    public var placement = Placement()
    public var hints = Hints()
    public var panels = Panels()
    public var audio = Audio()

    public static let `default` = Tuning()

    public init() {}

    public struct ClosedRangePair: Sendable {
        public var lower: Float
        public var upper: Float
        public init(lower: Float, upper: Float) {
            self.lower = lower
            self.upper = upper
        }
    }

    public struct TimeRange: Sendable {
        public var lower: TimeInterval
        public var upper: TimeInterval
        public init(lower: TimeInterval, upper: TimeInterval) {
            self.lower = lower
            self.upper = upper
        }
    }

    public struct Triple<T: Sendable>: Sendable {
        public var normal: T
        public var small: T
        public var moving: T
        public init(normal: T, small: T, moving: T) {
            self.normal = normal
            self.small = small
            self.moving = moving
        }
    }

    public struct DifficultyTriple<T: Sendable>: Sendable {
        public var easy: T
        public var normal: T
        public var hard: T
        public init(easy: T, normal: T, hard: T) {
            self.easy = easy
            self.normal = normal
            self.hard = hard
        }
    }

    public struct Round: Sendable {
        public var lengths: [TimeInterval] = [30, 60]
        public var defaultLength: TimeInterval = 30
        public var countdownStep: TimeInterval = 1
        public var goDuration: TimeInterval = 0.5
        public var finalWarnSeconds: TimeInterval = 5
        public var resultsDelay: TimeInterval = 0.6
        public init() {}
    }

    public struct Spawn: Sendable {
        public var firstDelay = TimeRange(lower: 0.4, upper: 0.9)
        public var delay = DifficultyTriple(
            easy: TimeRange(lower: 0.6, upper: 1.4),
            normal: TimeRange(lower: 0.35, upper: 1.10),
            hard: TimeRange(lower: 0.25, upper: 0.80)
        )
        public var maxConcurrent = DifficultyTriple(easy: 1, normal: 1, hard: 2)
        public var noSpawnTail: TimeInterval = 0.8
        public var warmup: TimeInterval = 5
        /// Weights are normal / small / moving, in percent, for easy, normal, and hard.
        public var weights = DifficultyTriple(
            easy: Triple(normal: 80, small: 10, moving: 10),
            normal: Triple(normal: 60, small: 25, moving: 15),
            hard: Triple(normal: 40, small: 35, moving: 25)
        )
        public var placementRetry: TimeInterval = 0.1
        public var candidates = 12
        public init() {}
    }

    public struct Targets: Sendable {
        public var lifetimeBlaster = Triple(normal: 2.6, small: 2.4, moving: 3.0)
        public var touchLifetimeExtra: TimeInterval = 0.6
        public var lifetimeMultiplier = DifficultyTriple(easy: 1.3, normal: 1.0, hard: 0.8)
        public var roamLifetimeMultiplier = 1.5
        public var diameterBlaster = Triple<Float>(normal: 0.40, small: 0.26, moving: 0.40)
        public var diameterTouch = Triple<Float>(normal: 0.20, small: 0.14, moving: 0.20)
        public var sizeMultiplier = DifficultyTriple<Float>(easy: 1.15, normal: 1.0, hard: 0.85)
        public var bigTargetsMultiplier: Float = 1.4
        public var rimDepth: Float = 0.03
        public var rimScale: Float = 1.04
        public var faceThickness: Float = 0.006
        public var strafeBlasterAmplitude: Float = 0.6
        public var strafeBlasterPeriod: TimeInterval = 3.2
        public var strafeTouchAmplitude: Float = 0.15
        public var strafeTouchPeriod: TimeInterval = 3.0
        public var speedMultiplier = DifficultyTriple<Float>(easy: 0.7, normal: 1.0, hard: 1.3)
        public var reduceMotionSpeedMultiplier: Float = 0.5
        public var bobAmplitude: Float = 0.01
        public var bobPeriod: TimeInterval = 2
        public init() {}
    }

    public struct Score: Sendable {
        public var base = Triple(normal: 100, small: 150, moving: 200)
        public var goldRadius: Float = 0.20
        public var redRadius: Float = 0.40
        public var goldBonus = 100
        public var redBonus = 50
        public var speedBonusMax = 50
        public var speedFull: TimeInterval = 0.45
        public var speedZero: TimeInterval = 1.50
        public var comboStreakTier1 = 5
        public var comboMultiplierTier1 = 1.5
        public var comboStreakTier2 = 10
        public var comboMultiplierTier2 = 2.0
        public var rounding = 10
        public init() {}
    }

    public struct Gesture: Sendable {
        public var armFrames = 4
        public var poseGrace: TimeInterval = 0.15
        public var indexStraightArm: Float = 0.90
        public var indexStraightRelease: Float = 0.82
        public var curlMax: Float = 1.25
        public var curledRequired = 2
        public var pointingAwayMinDot: Float = 0.2
        public var thumbCocked: Float = 0.45
        public var fireOnset: Float = 0.40
        public var fireThreshold: Float = 0.27
        public var fireSnapWindow: TimeInterval = 0.25
        public var fireCooldown: TimeInterval = 0.22
        public var aimLookback: TimeInterval = 0.045
        public var aimAlpha: Float = 0.45
        public var aimBlendFinger: Float = 0.6
        public var aimBlendKnuckleWrist: Float = 0.4
        public var aimBuffer = 24
        public var assistNormalDegrees: Float = 3.5
        public var assistEasyDegrees: Float = 5.0
        public var assistBigTargetsMultiplier: Float = 1.5
        public var maxRange: Float = 8
        public var dwellFire: TimeInterval = 0.35
        public init() {}
    }

    public struct Touch: Sendable {
        public var forgiveness: Float = 0.03
        public var cooldown: TimeInterval = 0.15
        public init() {}
    }

    /// Visual-spec FX values. These replace the short build-plan FX row.
    public struct FX: Sendable {
        public var bodyDepthRatio: Float = 0.075
        public var finSizeRatio: Float = 0.16
        public var finOffsetRatio: Float = 0.12
        public var spawnStartScale: Float = 0.6
        public var spawnOvershootScale: Float = 1.12
        public var spawnOvershootTime: TimeInterval = 0.09
        public var spawnSettleTime: TimeInterval = 0.06
        public var spawnPingEndScale: Float = 1.6
        public var spawnPingDuration: TimeInterval = 0.30
        public var hitFlash: TimeInterval = 0.04
        public var bullseyeGoldFlash: TimeInterval = 0.04
        public var hitRemoveAfter: TimeInterval = 0.08
        public var hitPopScale = PerRing<Float>(outer: 1.15, red: 1.15, gold: 1.2)
        public var shardCount = PerRing<Int>(outer: 10, red: 14, gold: 20)
        public var shardLife = PerRing<TimeInterval>(outer: 0.35, red: 0.42, gold: 0.52)
        public var shardSpeedMult = PerRing<Float>(outer: 1.0, red: 1.1, gold: 1.3)
        public var goldSparkleCount = 6
        public var goldSparkleLifeMult: Double = 1.5
        public var shardSizeRatio: Float = 0.05
        public var shardSpeedPerDiameter: Float = 2.0
        public var shardUpPerDiameter: Float = 1.25
        public var shardTowardViewerMax: Float = 0.2
        public var shardComfortDistance: Float = 1.0
        public var shardGravity: Float = 3.0
        public var shardSpinDegPerSec: Float = 720
        public var shardPoolSize = 48
        public var shockwaveEndScale: Float = 2.2
        public var shockwaveDuration: TimeInterval = 0.26
        public var popupAngleDeg: Float = 1.2
        public var popupBullseyeAngleDeg: Float = 1.6
        public var popupRisePerMeter: Float = 0.04
        public var popupLife: TimeInterval = 0.6
        public var popupFadeOut: TimeInterval = 0.15
        public var popupReducedMotionLife: TimeInterval = 0.4
        public var popupPoolSize = 4
        public var expireWarnLead: TimeInterval = 0.6
        public var expireBlinkHalfPeriod: TimeInterval = 0.15
        public var expireDuration: TimeInterval = 0.2
        public var expireDrop: Float = 0.03
        public var expireShardCount = 4
        public var roundEndVanish: TimeInterval = 0.12
        public var armedCubeSize: Float = 0.008
        public var armedCubeSpinDegPerSec: Float = 90
        public var beamThickness: Float = 0.0025
        public var beamSegmentLength: Float = 0.2
        public var beamOpacities: [Float] = [0.60, 0.35, 0.15]
        public var beamOpacitiesHighContrast: [Float] = [0.9, 0.7, 0.5]
        public var reticleAngleDeg: Float = 1.2
        public var reticleAngleBigTargetsDeg: Float = 1.6
        public var reticleKickScale: Float = 1.4
        public var reticleKickDuration: TimeInterval = 0.12
        public var reticleMissTint: TimeInterval = 0.12
        public var hoverScale: Float = 1.06
        public var hoverScaleTime: TimeInterval = 0.06
        public var bracketsSizeRatio: Float = 1.25
        public var bracketsPopScale: Float = 1.2
        public var bracketsPopTime: TimeInterval = 0.08
        public var muzzleSize: Float = 0.024
        public var muzzleDuration: TimeInterval = 0.06
        public var muzzleSecondFrameScale: Float = 0.6
        public var tracerThickness: Float = 0.004
        public var tracerDuration: TimeInterval = 0.09
        public var tracerEndThicknessScale: Float = 0.25
        public var missShardCount = 6
        public var missShardSizePerMeter: Float = 0.004
        public var missShardLife: TimeInterval = 0.22
        public var missPuffEndScale: Float = 1.8
        public var missPuffDuration: TimeInterval = 0.18
        public var comboPopScale: Float = 1.3
        public var comboPopDuration: TimeInterval = 0.2
        public var finalSecondsPulseScale: Float = 1.08
        public var finalSecondsPulseDuration: TimeInterval = 0.3
        public var countdownPopScale: Float = 1.3
        public var countdownPopDuration: TimeInterval = 0.2
        public var goEndScale: Float = 1.25
        public var goFadeOut: TimeInterval = 0.15
        public var panelAppearScale: Float = 0.94
        public var panelAppearDuration: TimeInterval = 0.2
        public var resultsTally: TimeInterval = 0.8
        public var resultsTallyMaxTicks = 12
        public var tutorialSpriteFrame: TimeInterval = 0.5
        public var hintFade: TimeInterval = 0.2
        public init() {}
    }

    public struct HUD: Sendable {
        public var followDistance: Float = 1.1
        public var followPitchDegrees: Float = -18
        public var followYawThresholdDegrees: Float = 25
        public var followPositionThreshold: Float = 0.4
        public var followSettleYawDegrees: Float = 5
        public var followSettlePosition: Float = 0.05
        public var followTimeConstant: TimeInterval = 0.25
        public init() {}
    }

    public struct Bands: Sendable {
        public var stayPutBlasterDistance = ClosedRangePair(lower: 1.8, upper: 3.2)
        public var stayPutBlasterAzimuthDegrees: Float = 35
        public var stayPutBlasterElevation = ClosedRangePair(lower: -10, upper: 15)
        public var stayPutTouchForward = ClosedRangePair(lower: 0.42, upper: 0.58)
        public var stayPutTouchLateral: Float = 0.28
        public var stayPutTouchVertical = ClosedRangePair(lower: -0.40, upper: -0.05)
        public var roamBlasterDistance = ClosedRangePair(lower: 2.0, upper: 5.0)
        public var roamBlasterAzimuthDegrees: Float = 120
        public var roamBlasterHeight = ClosedRangePair(lower: 0.6, upper: 2.0)
        public var roamTouchDistance = ClosedRangePair(lower: 0.6, upper: 2.2)
        public var roamTouchAzimuthDegrees: Float = 90
        public var roamTouchHeight = ClosedRangePair(lower: 0.8, upper: 1.6)
        public var minSeparationBlasterDegrees: Float = 20
        public var minSeparationTouch: Float = 0.15
        public init() {}
    }

    public struct Placement: Sendable {
        public var surfaceChance: Float = 0.5
        public var wallOffset: Float = 0.05
        public var tableInset: Float = 0.15
        public var minPlaneSize: Float = 0.5
        public var lastResortBlaster: Float = 2.0
        public var lastResortTouch: Float = 0.5
        public var lastResortEyeDrop: Float = 0.1
        public init() {}
    }

    public struct Hints: Sendable {
        public var handsLost: TimeInterval = 3
        public init() {}
    }

    public struct Panels: Sendable {
        public var lobbyDistance: Float = 1.2
        public var lobbyPitchDegrees: Float = -8
        public var countdownDistance: Float = 1.6
        public var tutorialDistance: Float = 0.9
        public var tutorialPitchDegrees: Float = -20
        public init() {}
    }

    public struct Audio: Sendable {
        public var spatialGainDB: Float = -6
        public init() {}
    }
}

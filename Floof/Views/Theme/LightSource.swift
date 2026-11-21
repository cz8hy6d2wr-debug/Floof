import CoreMotion
import SwiftUI

/// Eine gedachte Lampe über dem iPhone.
///
/// Der Bewegungssensor liefert die Neigung des Geräts (Richtung der Schwerkraft).
/// Daraus entsteht ein kleiner Versatz, mit dem Lichtkegel und Lichtkanten so
/// wandern, als stünde die Lampe fest im Raum, während man das iPhone neigt.
/// Läuft nur, solange die App im Vordergrund ist – kein Zugriff auf Ort o. Ä.,
/// keine Berechtigung nötig.
@MainActor
@Observable
final class LightSource {
    static let shared = LightSource()

    /// Versatz der Lampe, jeweils −1 … 1 (x: links/rechts, y: vor/zurück).
    private(set) var offset: CGPoint = .zero

    @ObservationIgnored private let motion = CMMotionManager()
    /// Langsam mitlaufende "Ruhelage" für vor/zurück – jeder hält das iPhone anders schräg.
    @ObservationIgnored private var baselineZ: Double?

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 20
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let gravity = data?.gravity else { return }
            MainActor.assumeIsolated { self?.update(gravity) }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        baselineZ = nil
        withAnimation(.smooth(duration: 0.6)) { offset = .zero }
    }

    private func update(_ g: CMAcceleration) {
        let base = baselineZ ?? g.z
        baselineZ = base * 0.985 + g.z * 0.015

        // Neigt man das iPhone nach rechts, scheint die feste Lampe nach links zu wandern.
        let x = max(-1, min(1, -g.x * 1.6))
        let y = max(-1, min(1, (g.z - base) * 2.5))

        // Glätten, damit nichts zittert.
        let next = CGPoint(x: offset.x * 0.8 + x * 0.2, y: offset.y * 0.8 + y * 0.2)
        if abs(next.x - offset.x) > 0.008 || abs(next.y - offset.y) > 0.008 {
            offset = next
        }
    }
}

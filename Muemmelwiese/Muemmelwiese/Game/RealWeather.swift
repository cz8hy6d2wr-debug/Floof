import CoreLocation
import Foundation
import Observation

/// Echtes Wetter vom kostenlosen Dienst Open-Meteo (kein Konto, kein Schlüssel).
/// Gefragt wird nur der ungefähre Standort; das Ergebnis wird 30 Minuten zwischengespeichert.
@MainActor
@Observable
final class RealWeather: NSObject {
    static let shared = RealWeather()

    struct Snapshot: Codable, Equatable {
        var fetched: Date
        var temperature: Double
        /// WMO-Wettercode
        var code: Int
        /// km/h
        var wind: Double
        /// 0…100 %
        var cloudCover: Double
        /// mm in der letzten Stunde
        var precipitation: Double
        var sunrise: Date?
        var sunset: Date?
    }

    enum Kind: String {
        case klar, leichtBewoelkt, bewoelkt, nebel, niesel, regen, starkregen, schnee, gewitter

        var title: String {
            switch self {
            case .klar: "klar"
            case .leichtBewoelkt: "heiter"
            case .bewoelkt: "bewölkt"
            case .nebel: "Nebel"
            case .niesel: "Niesel"
            case .regen: "Regen"
            case .starkregen: "Starkregen"
            case .schnee: "Schnee"
            case .gewitter: "Gewitter"
            }
        }

        func symbol(isDay: Bool) -> String {
            switch self {
            case .klar: isDay ? "sun.max.fill" : "moon.stars.fill"
            case .leichtBewoelkt: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
            case .bewoelkt: "cloud.fill"
            case .nebel: "cloud.fog.fill"
            case .niesel: "cloud.drizzle.fill"
            case .regen: "cloud.rain.fill"
            case .starkregen: "cloud.heavyrain.fill"
            case .schnee: "cloud.snow.fill"
            case .gewitter: "cloud.bolt.rain.fill"
            }
        }
    }

    private(set) var snapshot: Snapshot?
    /// Standort verweigert oder keine Verbindung – dann spielt die Wiese ihr eigenes Wetter.
    private(set) var unavailable = false
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var continuation: CheckedContinuation<CLLocation?, Never>?
    @ObservationIgnored private var loading = false
    private static let cacheKey = "muemmelwiese.weather"
    static let enabledKey = "muemmelwiese.realWeather"

    var enabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            if newValue { Task { await refresh(force: true) } }
        }
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey),
           let cached = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snapshot = cached
        }
    }

    /// Aktuell gültiges Wetter (höchstens 3 Stunden alt), nur wenn eingeschaltet.
    var current: Snapshot? {
        guard enabled, let snapshot, Date.now.timeIntervalSince(snapshot.fetched) < 3 * 3600 else { return nil }
        return snapshot
    }

    static func kind(_ s: Snapshot) -> Kind {
        switch s.code {
        case 95...99: return .gewitter
        case 71...77, 85, 86: return .schnee
        case 65, 67, 82: return .starkregen
        case 61, 63, 66, 80, 81: return .regen
        case 51...57: return .niesel
        case 45, 48: return .nebel
        case 3: return .bewoelkt
        case 1, 2: return .leichtBewoelkt
        default: return s.cloudCover > 70 ? .bewoelkt : (s.cloudCover > 30 ? .leichtBewoelkt : .klar)
        }
    }

    /// Lädt neu, wenn der letzte Stand älter als 30 Minuten ist.
    func refresh(force: Bool = false) async {
        guard enabled, !loading else { return }
        if !force, let snapshot, Date.now.timeIntervalSince(snapshot.fetched) < 1800 { return }
        loading = true
        defer { loading = false }
        guard let location = await requestLocation() else { unavailable = true; return }
        let ok = await fetch(for: location.coordinate)
        unavailable = !ok && current == nil
    }

    private func fetch(for c: CLLocationCoordinate2D) async -> Bool {
        var parts = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        parts.queryItems = [
            .init(name: "latitude", value: String(format: "%.2f", c.latitude)),
            .init(name: "longitude", value: String(format: "%.2f", c.longitude)),
            .init(name: "current", value: "temperature_2m,weather_code,wind_speed_10m,cloud_cover,precipitation"),
            .init(name: "daily", value: "sunrise,sunset"),
            .init(name: "forecast_days", value: "1"),
            .init(name: "timezone", value: "auto"),
            .init(name: "timeformat", value: "unixtime"),
        ]
        guard let url = parts.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let r = try? JSONDecoder().decode(OpenMeteo.self, from: data) else { return false }
        let s = Snapshot(fetched: .now,
                         temperature: r.current.temperature_2m,
                         code: r.current.weather_code,
                         wind: r.current.wind_speed_10m,
                         cloudCover: r.current.cloud_cover,
                         precipitation: r.current.precipitation,
                         sunrise: r.daily.sunrise.first.map { Date(timeIntervalSince1970: $0) },
                         sunset: r.daily.sunset.first.map { Date(timeIntervalSince1970: $0) })
        snapshot = s
        if let encoded = try? JSONEncoder().encode(s) { UserDefaults.standard.set(encoded, forKey: Self.cacheKey) }
        return true
    }

    private struct OpenMeteo: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
            let wind_speed_10m: Double
            let cloud_cover: Double
            let precipitation: Double
        }
        struct Daily: Decodable {
            let sunrise: [Double]
            let sunset: [Double]
        }
        let current: Current
        let daily: Daily
    }

    // MARK: Standort

    private func requestLocation() async -> CLLocation? {
        switch manager.authorizationStatus {
        case .denied, .restricted: return nil
        case .notDetermined: manager.requestWhenInUseAuthorization()
        default: break
        }
        if let last = manager.location, Date.now.timeIntervalSince(last.timestamp) < 6 * 3600 { return last }
        return await withCheckedContinuation { cont in
            continuation?.resume(returning: nil)
            continuation = cont
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
            Task {
                try? await Task.sleep(for: .seconds(20))
                self.finish(nil)
            }
        }
    }

    private func finish(_ location: CLLocation?) {
        continuation?.resume(returning: location)
        continuation = nil
    }
}

extension RealWeather: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in self.finish(location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                if self.continuation != nil { self.manager.requestLocation() }
            } else if status == .denied || status == .restricted {
                self.finish(nil)
            }
        }
    }
}

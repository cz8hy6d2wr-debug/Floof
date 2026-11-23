import CoreLocation
import Foundation
import Observation

/// Wetter vom kostenlosen Dienst Open-Meteo (kein Konto, kein Schlüssel).
/// Gefragt wird nur der ungefähre Standort; das Ergebnis wird eine Stunde zwischengespeichert.
///
/// Cinnamon und Brownie wohnen drinnen: Wichtig ist vor allem Hitze – an heißen Tagen
/// wird es auch in der Wohnung warm. Frost und Regen lösen keine Hinweise aus,
/// sondern nur die Animation an der Dynamic Island.
@MainActor
@Observable
final class WeatherStore: NSObject {
    static let shared = WeatherStore()

    struct Weather: Codable, Equatable {
        var fetched: Date
        var temperature: Double
        var high: Double
        var low: Double
        var code: Int
        var wind: Double
        var isDay: Bool
        /// Stunde (0–23), ab der es heute 25 °C oder mehr hat – für "ab 14 Uhr heiß".
        var hotFromHour: Int?
    }

    enum Condition: String, Equatable {
        case clear, night, clouds, fog, rain, snow, storm, wind, frost, heat
    }

    private(set) var weather: Weather?
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var continuation: CheckedContinuation<CLLocation?, Never>?
    @ObservationIgnored private var loading = false
    private static let cacheKey = "floof.weather"

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey),
           let cached = try? JSONDecoder().decode(Weather.self, from: data) {
            weather = cached
        }
    }

    /// Aktuelles Wetter, nur wenn es von heute und höchstens drei Stunden alt ist.
    var current: Weather? {
        guard let weather, Date.now.timeIntervalSince(weather.fetched) < 3 * 3600,
              Calendar.current.isDateInToday(weather.fetched) else { return nil }
        return weather
    }

    var condition: Condition? { current.map(Self.condition(for:)) }

    static func condition(for w: Weather) -> Condition {
        switch w.code {
        case 95...99: return .storm
        case 71...77, 85, 86: return .snow
        case 51...67, 80...82: return .rain
        case 45, 48: return .fog
        default: break
        }
        if w.wind >= 35 { return .wind }
        if w.temperature <= 0 { return .frost }
        if w.code >= 2 { return .clouds }
        if !w.isDay { return .night }
        return w.temperature >= 25 ? .heat : .clear
    }

    /// Lädt neu, wenn der letzte Stand älter als eine Stunde ist.
    func refreshIfNeeded() async {
        guard !DemoMode.isActive, !loading else { return }
        if let weather, Date.now.timeIntervalSince(weather.fetched) < 3600 { return }
        loading = true
        defer { loading = false }
        guard let location = await requestLocation() else { return }
        await fetch(for: location.coordinate)
    }

    private func fetch(for c: CLLocationCoordinate2D) async {
        var parts = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        parts.queryItems = [
            .init(name: "latitude", value: String(format: "%.2f", c.latitude)),
            .init(name: "longitude", value: String(format: "%.2f", c.longitude)),
            .init(name: "current", value: "temperature_2m,weather_code,wind_speed_10m,is_day"),
            .init(name: "hourly", value: "temperature_2m"),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            .init(name: "forecast_days", value: "1"),
            .init(name: "timezone", value: "auto"),
        ]
        guard let url = parts.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let response = try? JSONDecoder().decode(OpenMeteo.self, from: data) else { return }
        let hot = response.hourly.temperature_2m.firstIndex { $0 >= 25 }
        let w = Weather(fetched: .now,
                        temperature: response.current.temperature_2m,
                        high: response.daily.temperature_2m_max.first ?? response.current.temperature_2m,
                        low: response.daily.temperature_2m_min.first ?? response.current.temperature_2m,
                        code: response.current.weather_code,
                        wind: response.current.wind_speed_10m,
                        isDay: response.current.is_day == 1,
                        hotFromHour: hot)
        weather = w
        if let encoded = try? JSONEncoder().encode(w) { UserDefaults.standard.set(encoded, forKey: Self.cacheKey) }
        WidgetBridge.refresh(from: PetStore.shared)
    }

    private struct OpenMeteo: Decodable {
        struct Current: Decodable { let temperature_2m: Double; let weather_code: Int; let wind_speed_10m: Double; let is_day: Int }
        struct Hourly: Decodable { let temperature_2m: [Double] }
        struct Daily: Decodable { let temperature_2m_max: [Double]; let temperature_2m_min: [Double] }
        let current: Current
        let hourly: Hourly
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
            // Spätestens nach 15 Sekunden aufgeben.
            Task {
                try? await Task.sleep(for: .seconds(15))
                self.finish(nil)
            }
        }
    }

    private func finish(_ location: CLLocation?) {
        continuation?.resume(returning: location)
        continuation = nil
    }

    // MARK: Texte

    /// "24° · bis 29°" bzw. Kurzbeschreibung für die Kopfzeile und das Widget.
    var summary: String? {
        guard let w = current else { return nil }
        return "\(Int(w.temperature.rounded()))° · \(Self.label(Self.condition(for: w))) · bis \(Int(w.high.rounded()))°"
    }

    static func label(_ c: Condition) -> String {
        switch c {
        case .clear: "sonnig"
        case .heat: "heiß"
        case .night: "klar"
        case .clouds: "bewölkt"
        case .fog: "neblig"
        case .rain: "Regen"
        case .snow: "Schnee"
        case .storm: "Gewitter"
        case .wind: "windig"
        case .frost: "Frost"
        }
    }

    static func symbol(_ c: Condition) -> String {
        switch c {
        case .clear, .heat: "sun.max.fill"
        case .night: "moon.stars.fill"
        case .clouds: "cloud.fill"
        case .fog: "cloud.fog.fill"
        case .rain: "cloud.rain.fill"
        case .snow: "cloud.snow.fill"
        case .storm: "cloud.bolt.rain.fill"
        case .wind: "wind"
        case .frost: "thermometer.snowflake"
        }
    }
}

extension WeatherStore: CLLocationManagerDelegate {
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

// MARK: - Hinweise für Wohnungskaninchen

extension PetStore {
    /// Hitze-Hinweis: ab 25 °C draußen wird es auch drinnen warm, ab 28 °C kritisch.
    var weatherHint: TodayHint? {
        guard let w = WeatherStore.shared.current, w.high >= 25 else { return nil }
        let names = pets.count == 2 ? "\(pets[0].name) & \(pets[1].name)" : "deine Kaninchen"
        let from = w.hotFromHour.map { " ab \($0) Uhr" } ?? ""
        if w.high >= 28 {
            return TodayHint(id: "weather-heat", symbol: "thermometer.sun.fill",
                             title: "Heute bis \(Int(w.high.rounded())) °C\(from)",
                             detail: "Morgens lüften, dann Fenster & Rollos zu. Fliese oder Kühlakku (eingewickelt) für \(names), Wasser öfter frisch.",
                             urgent: true, action: .article("not-hitze"), actionTitle: "Tipps")
        }
        return TodayHint(id: "weather-warm", symbol: "sun.max.fill",
                         title: "Warm heute, bis \(Int(w.high.rounded())) °C",
                         detail: "Mittags abdunkeln und einen kühlen Liegeplatz anbieten.",
                         action: .article("not-hitze"), actionTitle: "Tipps")
    }
}

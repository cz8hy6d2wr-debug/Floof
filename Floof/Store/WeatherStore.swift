import CoreLocation
import Foundation
import Observation

/// Wetter vom kostenlosen Dienst Open-Meteo (kein Konto, kein Schlüssel).
/// Gefragt wird nur der ungefähre Standort; das Ergebnis wird eine Stunde zwischengespeichert.
///
/// Cinnamon und Brownie wohnen drinnen: Wichtig ist vor allem Hitze – an heißen Tagen
/// wird es auch in der Wohnung warm. Das Wetter erscheint im Wochenkalender (Symbol, Temperatur,
/// leichte Animation). Hinweise richten sich nach der Haltung der Tiere (drinnen, gemischt, draußen).
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
        /// Vorhersage für die nächsten 7 Tage (ältere gespeicherte Stände haben sie nicht).
        var daily: [Day]?

        struct Day: Codable, Equatable {
            var date: String      // "yyyy-MM-dd"
            var hi: Double
            var lo: Double
            var code: Int
            var wind: Double
        }
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
        if DemoMode.isActive { weather = Self.demoWeather() }
    }

    /// Beispielwetter für Screenshots (Demo-Modus): alle Lagen einmal in der Woche.
    private static func demoWeather() -> Weather {
        let rows: [(Double, Double, Int, Double)] = [
            (27, 19, 0, 10), (21, 15, 3, 14), (15, 11, 63, 18), (11, 6, 2, 41),
            (3, -1, 73, 12), (1, -4, 45, 6), (8, 2, 95, 22),
        ]
        let days: [Weather.Day] = rows.enumerated().map { i, r in
            let date = Calendar.current.date(byAdding: .day, value: i, to: .now) ?? .now
            return Weather.Day(date: DoseKey.day(date), hi: r.0, lo: r.1, code: r.2, wind: r.3)
        }
        return Weather(fetched: .now, temperature: 24, high: 27, low: 19, code: 0, wind: 10, isDay: true,
                       hotFromHour: 13, daily: days)
    }

    /// Aktuelles Wetter, nur wenn es von heute und höchstens drei Stunden alt ist.
    var current: Weather? {
        guard let weather, Date.now.timeIntervalSince(weather.fetched) < 3 * 3600,
              Calendar.current.isDateInToday(weather.fetched) else { return nil }
        return weather
    }

    /// Wichtigste Lage (für Symbol und Hinweise).
    var condition: Condition? { current.map(Self.condition(for:)) }
    /// Alle aktuellen Lagen zusammen, z. B. [Nebel, Frost] – für die Animation.
    var conditions: [Condition] { current.map(Self.conditions(for:)) ?? [] }

    private static let priority: [Condition] = [.storm, .snow, .rain, .fog, .wind, .frost, .heat, .night, .clouds, .clear]

    static func condition(for w: Weather) -> Condition {
        conditions(for: w).min { priority.firstIndex(of: $0)! < priority.firstIndex(of: $1)! } ?? .clear
    }

    /// Mehrere Lagen können zusammen auftreten: Niederschlag oder Nebel, dazu Wind, Frost
    /// oder Hitze, und der Himmel (Wolken, Sterne, Sonne).
    static func conditions(for w: Weather) -> [Condition] {
        var result: [Condition] = []
        switch w.code {
        case 95...99: result.append(.storm)
        case 71...77, 85, 86: result.append(.snow)
        case 51...67, 80...82: result.append(.rain)
        case 45, 48: result.append(.fog)
        default: break
        }
        let covered = !result.isEmpty
        if w.wind >= 35 { result.append(.wind) }
        if w.temperature <= 0 { result.append(.frost) }
        if !covered {
            if w.code >= 2 {
                result.append(.clouds)
            } else if !w.isDay {
                result.append(.night)
            } else if w.temperature >= 25 {
                result.append(.heat)
            } else {
                result.append(.clear)
            }
        }
        return result
    }

    /// Vorhersage für einen Tag (heute und die nächsten 6 Tage), sonst `nil`.
    func forecast(on day: Date) -> Weather.Day? {
        guard let weather, Date.now.timeIntervalSince(weather.fetched) < 24 * 3600 else { return nil }
        let key = DoseKey.day(day)
        return weather.daily?.first { $0.date == key }
    }

    /// Lagen eines Tages (für Symbol und Animation im Kalender).
    static func conditions(for day: Weather.Day) -> [Condition] {
        var result: [Condition] = []
        switch day.code {
        case 95...99: result.append(.storm)
        case 71...77, 85, 86: result.append(.snow)
        case 51...67, 80...82: result.append(.rain)
        case 45, 48: result.append(.fog)
        default: break
        }
        if day.wind >= 35 { result.append(.wind) }
        if day.lo <= 0 { result.append(.frost) }
        if day.hi >= 25 { result.append(.heat) }
        if result.isEmpty || result == [.wind] || result == [.frost] {
            result.append(day.code >= 2 ? .clouds : .clear)
        }
        return result
    }

    /// Wichtigste Lage eines Tages – bestimmt das Symbol.
    static func condition(for day: Weather.Day) -> Condition {
        conditions(for: day).min { priority.firstIndex(of: $0)! < priority.firstIndex(of: $1)! } ?? .clear
    }

    /// Schlichtes Linien-Symbol für den Kalender.
    static func lineSymbol(_ c: Condition) -> String {
        switch c {
        case .clear, .heat: "sun.max"
        case .night: "moon.stars"
        case .clouds: "cloud"
        case .fog: "cloud.fog"
        case .rain: "cloud.rain"
        case .snow: "cloud.snow"
        case .storm: "cloud.bolt"
        case .wind: "wind"
        case .frost: "thermometer.snowflake"
        }
    }

    /// Lädt neu, wenn der letzte Stand älter als eine Stunde ist.
    func refreshIfNeeded() async {
        guard !DemoMode.isActive, !loading else { return }
        if let weather, weather.daily != nil, Date.now.timeIntervalSince(weather.fetched) < 3600 { return }
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
            .init(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,wind_speed_10m_max"),
            .init(name: "forecast_days", value: "7"),
            .init(name: "timezone", value: "auto"),
        ]
        guard let url = parts.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let response = try? JSONDecoder().decode(OpenMeteo.self, from: data) else { return }
        let hot = response.hourly.temperature_2m.prefix(24).firstIndex { $0 >= 25 }   // nur heute
        let d = response.daily
        let days: [Weather.Day] = d.time.indices.compactMap { i in
            guard i < d.temperature_2m_max.count, i < d.temperature_2m_min.count,
                  i < d.weather_code.count, i < d.wind_speed_10m_max.count else { return nil }
            return Weather.Day(date: d.time[i], hi: d.temperature_2m_max[i], lo: d.temperature_2m_min[i],
                               code: d.weather_code[i], wind: d.wind_speed_10m_max[i])
        }
        let w = Weather(fetched: .now,
                        temperature: response.current.temperature_2m,
                        high: response.daily.temperature_2m_max.first ?? response.current.temperature_2m,
                        low: response.daily.temperature_2m_min.first ?? response.current.temperature_2m,
                        code: response.current.weather_code,
                        wind: response.current.wind_speed_10m,
                        isDay: response.current.is_day == 1,
                        hotFromHour: hot,
                        daily: days)
        weather = w
        if let encoded = try? JSONEncoder().encode(w) { UserDefaults.standard.set(encoded, forKey: Self.cacheKey) }
        WidgetBridge.refresh(from: PetStore.shared)
    }

    private struct OpenMeteo: Decodable {
        struct Current: Decodable { let temperature_2m: Double; let weather_code: Int; let wind_speed_10m: Double; let is_day: Int }
        struct Hourly: Decodable { let temperature_2m: [Double] }
        struct Daily: Decodable {
            let time: [String]
            let weather_code: [Int]
            let temperature_2m_max: [Double]
            let temperature_2m_min: [Double]
            let wind_speed_10m_max: [Double]
        }
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
        let labels = Self.conditions(for: w)
            .sorted { Self.priority.firstIndex(of: $0)! < Self.priority.firstIndex(of: $1)! }
            .prefix(2).map(Self.label).joined(separator: ", ")
        return "\(Int(w.temperature.rounded()))° · \(labels) · bis \(Int(w.high.rounded()))°"
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

// MARK: - Wetter-Hinweise je nach Haltung

extension PetStore {
    /// Bis zu zwei Wetter-Hinweise für heute, passend zur Haltung der gewählten Tiere.
    /// Maßgeblich ist das Tier, das dem Wetter am meisten ausgesetzt ist (draußen vor gemischt vor drinnen).
    func weatherHints(for chosen: [Pet]) -> [TodayHint] {
        let weather = WeatherStore.shared
        guard let current = weather.current, let housing = chosen.map(\.housingOrDefault).max(by: { $0.exposure < $1.exposure })
        else { return [] }
        let day = weather.forecast(on: .now)
        let hi = day?.hi ?? current.high
        let lo = day?.lo ?? current.low
        let code = day?.code ?? current.code
        let wind = max(day?.wind ?? 0, current.wind)
        let exposed = chosen.filter { $0.housingOrDefault == housing }
        let names = exposed.count == 1 ? exposed[0].name
            : exposed.count == 2 ? "\(exposed[0].name) & \(exposed[1].name)" : "deine Kaninchen"
        let from = current.hotFromHour.map { " ab \($0) Uhr" } ?? ""
        let high = Int(hi.rounded()), low = Int(lo.rounded())
        let rain = (51...67).contains(code) || (80...82).contains(code)
        let snow = (71...77).contains(code) || code == 85 || code == 86
        let storm = (95...99).contains(code)
        var hints: [TodayHint] = []

        // Hitze – betrifft alle, draußen am stärksten.
        switch housing {
        case .indoor where hi >= 28:
            hints.append(TodayHint(id: "weather-heat", symbol: "thermometer.sun.fill", title: "Heute bis \(high) °C\(from)",
                                   detail: "Morgens lüften, dann Fenster & Rollos zu. Fliese oder Kühlakku (eingewickelt) für \(names), Wasser öfter frisch.",
                                   urgent: true, action: .article("not-hitze"), actionTitle: "Tipps"))
        case .indoor where hi >= 25:
            hints.append(TodayHint(id: "weather-warm", symbol: "sun.max.fill", title: "Warm heute, bis \(high) °C",
                                   detail: "Mittags abdunkeln und einen kühlen Liegeplatz anbieten.",
                                   action: .article("not-hitze"), actionTitle: "Tipps"))
        case .mixed where hi >= 25:
            hints.append(TodayHint(id: "weather-heat", symbol: "thermometer.sun.fill", title: "Heute bis \(high) °C\(from)",
                                   detail: "Auslauf nur morgens und abends im Schatten. Drinnen Rollos zu, kühler Liegeplatz für \(names).",
                                   urgent: hi >= 28, action: .article("not-hitze"), actionTitle: "Tipps"))
        case .outdoor where hi >= 25:
            hints.append(TodayHint(id: "weather-heat", symbol: "thermometer.sun.fill",
                                   title: hi >= 30 ? "Gefährlich heiß: \(high) °C\(from)" : "Heute bis \(high) °C\(from)",
                                   detail: "Gehege den ganzen Tag beschatten – die Sonne wandert mit. Mehrere Näpfe, Fliese oder Kühlakku. Po von \(names) auf Fliegenmaden prüfen.",
                                   urgent: true, action: .article("not-hitze"), actionTitle: "Tipps"))
        default:
            break
        }

        // Frost
        if lo <= 0 {
            switch housing {
            case .mixed:
                hints.append(TodayHint(id: "weather-frost", symbol: "thermometer.snowflake", title: "Frost, bis \(low) °C",
                                       detail: "Auslauf heute kurz halten – Wohnungskaninchen haben kein dichtes Winterfell.",
                                       urgent: lo <= -5, action: .article("hal-draussen"), actionTitle: "Tipps"))
            case .outdoor:
                hints.append(TodayHint(id: "weather-frost", symbol: "thermometer.snowflake",
                                       title: lo <= -8 ? "Strenger Frost, bis \(low) °C" : "Frost, bis \(low) °C",
                                       detail: lo <= -8
                                           ? "Schutzhaus zusätzlich dämmen, viel Stroh. Wasser mehrmals auf Eis prüfen. Kranke oder alte Tiere reinholen."
                                           : "Wasser mehrmals auf Eis prüfen, frisches Stroh ins Schutzhaus.",
                                       urgent: lo <= -8, action: .article("hal-draussen"), actionTitle: "Tipps"))
            case .indoor:
                break
            }
        }

        // Gewitter, Sturm, Regen, Schnee, Wind
        switch housing {
        case .outdoor:
            if storm || wind >= 50 {
                hints.append(TodayHint(id: "weather-storm", symbol: storm ? "cloud.bolt.rain.fill" : "wind",
                                       title: storm ? "Gewitter heute" : "Sturm, bis \(Int(wind.rounded())) km/h",
                                       detail: "Gehege sichern, Schutzhaus windgeschützt und trocken halten.",
                                       urgent: true, action: .article("hal-draussen"), actionTitle: "Tipps"))
            } else if snow {
                hints.append(TodayHint(id: "weather-snow", symbol: "cloud.snow.fill", title: "Schnee heute",
                                       detail: "Eingang zum Schutzhaus freihalten, Wasser nicht einfrieren lassen.",
                                       action: .article("hal-draussen"), actionTitle: "Tipps"))
            } else if rain {
                hints.append(TodayHint(id: "weather-rain", symbol: "cloud.rain.fill", title: "Regen heute",
                                       detail: "Überdachter, trockener Platz für \(names)? Nasse Einstreu wechseln.",
                                       action: .article("hal-draussen"), actionTitle: "Tipps"))
            } else if wind >= 35 {
                hints.append(TodayHint(id: "weather-wind", symbol: "wind", title: "Windig, bis \(Int(wind.rounded())) km/h",
                                       detail: "Liegt das Schutzhaus zugfrei?",
                                       action: .article("hal-draussen"), actionTitle: "Tipps"))
            }
        case .mixed:
            if storm || rain || snow || wind >= 50 {
                let what = storm ? "Gewitter" : snow ? "Schnee" : rain ? "Regen" : "Sturm"
                hints.append(TodayHint(id: "weather-wet", symbol: storm ? "cloud.bolt.rain.fill" : snow ? "cloud.snow.fill" : rain ? "cloud.rain.fill" : "wind",
                                       title: "\(what) heute",
                                       detail: "Auslauf lieber drinnen – oder nur kurz, mit trockenem Unterschlupf.",
                                       action: .article("hal-draussen"), actionTitle: "Tipps"))
            }
        case .indoor:
            break
        }

        return Array(hints.sorted { $0.urgent && !$1.urgent }.prefix(2))
    }
}

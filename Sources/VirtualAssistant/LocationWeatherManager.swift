import Foundation
import CoreLocation

class LocationWeatherManager: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    var currentLocation: CLLocationCoordinate2D?
    var currentWeather: WeatherInfo?
    var currentCity: String = "Unknown Location"

    var onLocationUpdate: (() -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = CLLocationDistance(3000) // Roughly city-level accuracy
        requestLocationPermission()
    }

    func requestLocationPermission() {
        let status = locationManager.authorizationStatus
        print("📍 Location permission status: \(status.description)")
        switch status {
        case .notDetermined:
            print("📍 Requesting location authorization...")
            #if os(macOS)
            locationManager.requestAlwaysAuthorization()
            #else
            locationManager.requestWhenInUseAuthorization()
            #endif
        case .authorizedAlways:
            print("📍 Location authorized - starting updates")
            startUpdatingLocation()
        #if !os(macOS)
        case .authorizedWhenInUse:
            print("📍 Location authorized - starting updates")
            startUpdatingLocation()
        #endif
        case .denied, .restricted:
            print("📍 ❌ Location permission denied or restricted - check System Settings → Privacy → Location")
        @unknown default:
            print("📍 Unknown authorization status")
            break
        }
    }

    func startUpdatingLocation() {
        print("📍 Starting location updates...")
        locationManager.startUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location.coordinate

        print("📍 Location: \(location.coordinate.latitude), \(location.coordinate.longitude)")

        // Get weather for this location
        fetchWeather(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)

        // Reverse geocode to get city name
        reverseGeocode(location: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 Location error: \(error.localizedDescription)")
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        #if os(macOS)
        if status == .authorizedAlways {
            startUpdatingLocation()
        }
        #else
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            startUpdatingLocation()
        }
        #endif
    }

    private func reverseGeocode(location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            if let placemark = placemarks?.first {
                self?.currentCity = placemark.locality ?? placemark.administrativeArea ?? "Unknown"
                print("📍 City: \(self?.currentCity ?? "Unknown")")
                self?.onLocationUpdate?()
            }
        }
    }

    private func fetchWeather(latitude: Double, longitude: Double) {
        // Using Open-Meteo API (free, no API key required)
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,weather_code,wind_speed_10m"

        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                print("🌤️ Weather fetch error: \(error?.localizedDescription ?? "Unknown")")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let current = json["current"] as? [String: Any],
                   let temp = current["temperature_2m"] as? Double,
                   let weatherCode = current["weather_code"] as? Int,
                   let windSpeed = current["wind_speed_10m"] as? Double {

                    let description = self?.weatherDescription(for: weatherCode) ?? "Unknown"
                    self?.currentWeather = WeatherInfo(temperature: temp, condition: description, windSpeed: windSpeed)
                    print("🌤️ Weather: \(Int(temp))°C, \(description), Wind: \(Int(windSpeed)) km/h")
                    self?.onLocationUpdate?()
                }
            } catch {
                print("🌤️ Weather parse error: \(error)")
            }
        }.resume()
    }

    private func weatherDescription(for code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1, 2: return "Mostly clear"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Light rain"
        case 61, 63, 65: return "Rain"
        case 71, 73, 75: return "Snow"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95, 96, 99: return "Thunderstorm"
        default: return "Variable"
        }
    }

    func getContextString() -> String {
        var context = "Current time: \(getTimeString())"

        if !currentCity.isEmpty && currentCity != "Unknown Location" {
            context += "\nLocation: \(currentCity)"
        }

        if let weather = currentWeather {
            context += "\nWeather: \(Int(weather.temperature))°C, \(weather.condition)"
        }

        return context
    }

    private func getTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, h:mm a"
        return formatter.string(from: Date())
    }
}

struct WeatherInfo {
    let temperature: Double
    let condition: String
    let windSpeed: Double
}

extension CLAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorizedAlways:
            return "authorizedAlways"
        @unknown default:
            return "unknown"
        }
    }
}

import Foundation
import CoreLocation
import AVFoundation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let locationManager = CLLocationManager()
    private let speechSynthesizer = AVSpeechSynthesizer()

    @Published var authorizationStatus: CLAuthorizationStatus?
    @Published var lastLocation: CLLocation?
    @Published var currentSpeed: CLLocationSpeed = 0.0 // meters per second
    @Published var totalDistance: CLLocationDistance = 0.0 // meters
    @Published var currentPace: String = "N/A" // e.g., "7:30 min/mile"

    private var previousLocation: CLLocation?
    private var lastAnnouncedDistance: CLLocationDistance = 0.0

    // MARK: - Initialization

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation // High accuracy for running
        locationManager.distanceFilter = 10 // Update every 10 meters, adjust as needed
        locationManager.activityType = .fitness // Optimized for fitness activities
    }

    // MARK: - Location Authorization

    func requestLocationAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    // MARK: - Start/Stop Location Updates

    func startTracking() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("Location authorization not granted.")
            requestLocationAuthorization()
            return
        }
        totalDistance = 0.0 // Reset distance for new run
        lastAnnouncedDistance = 0.0 // Reset announced distance
        previousLocation = nil // Clear previous location
        locationManager.startUpdatingLocation()
        print("Location tracking started.")
    }

    func stopTracking() {
        locationManager.stopUpdatingLocation()
        print("Location tracking stopped.")
    }

    // MARK: - CLLocationManagerDelegate Methods

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location authorization granted.")
        case .denied, .restricted:
            print("Location authorization denied or restricted.")
        case .notDetermined:
            print("Location authorization not determined.")
        @unknown default:
            fatalError("Unknown authorization status")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.last else { return }

        lastLocation = latestLocation
        currentSpeed = latestLocation.speed // Speed in meters/second

        // Only update distance if the location is valid and not paused/stopped
        if latestLocation.horizontalAccuracy < 20 && latestLocation.speed >= 0 { // Ignore inaccurate or negative speed
            if let prevLocation = previousLocation {
                let segmentDistance = latestLocation.distance(from: prevLocation)
                totalDistance += segmentDistance
            }
            previousLocation = latestLocation
        }

        // Calculate and speak pace based on current speed
        if currentSpeed > 0 { // Avoid division by zero
            let secondsPerMeter = 1.0 / currentSpeed
            let secondsPerMile = secondsPerMeter * 1609.34 // 1 mile = 1609.34 meters
            let minutes = Int(secondsPerMile / 60)
            let seconds = Int(secondsPerMile.truncatingRemainder(dividingBy: 60))
            currentPace = String(format: "%d:%02d min/mile", minutes, seconds)
        } else {
            currentPace = "0:00 min/mile (stopped)"
        }

        // Announce pace every 0.1 miles
        let announcementIntervalMiles: CLLocationDistance = 0.1 // Announce every 0.1 miles
        let announcementIntervalMeters = announcementIntervalMiles * 1609.34

        if totalDistance >= lastAnnouncedDistance + announcementIntervalMeters {
            let speechString = "Your current pace is \(currentPace). Total distance \(String(format: "%.1f", totalDistance / 1609.34)) miles."
            speak(text: speechString)
            lastAnnouncedDistance += announcementIntervalMeters
            // If you want to announce at exact tenth mile points, reset lastAnnouncedDistance to totalDistance rounded down.
            // For now, it just adds the interval.
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                print("Location access denied by user.")
            case .locationUnknown:
                print("Location data currently unavailable.")
            case .network:
                print("Network error with location services.")
            default:
                print("Location manager failed with error: \(error.localizedDescription)")
            }
        } else {
            print("Location manager failed with error: \(error.localizedDescription)")
        }
    }

    // MARK: - Text-to-Speech

    func speak(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US") // You can change language
        utterance.rate = 0.5 // Adjust speech rate (0.0 - 1.0)
        speechSynthesizer.speak(utterance)
    }
}

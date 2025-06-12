import Foundation
import CoreLocation
import AVFoundation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate, AVSpeechSynthesizerDelegate {
    
    private let locationManager = CLLocationManager()
    private let speechSynthesizer = AVSpeechSynthesizer()

    @Published var authorizationStatus: CLAuthorizationStatus?
    @Published var lastLocation: CLLocation?
    @Published var currentSpeed: CLLocationSpeed = 0.0 // meters per second
    @Published var totalDistance: CLLocationDistance = 0.0 // meters
    @Published var currentPace: String = "N/A" // e.g., "7:30 min/mile"
    @Published var metersPerMile: CLLocationDistance = 1609.344 // 1 mile = 1609.344 meters

    private var previousLocation: CLLocation?
    private var lastAnnouncedDistance: CLLocationDistance = 0.0

    // MARK: - Initialization

    override init() {
        super.init()
        print("initializing LocationManger...")
        locationManager.delegate = self
        speechSynthesizer.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation // High accuracy for running
        locationManager.distanceFilter = 10 // Update every 10 meters, adjust as needed
        locationManager.activityType = .fitness // Optimized for fitness activities
        
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .ambient // Allows for app audio to play while phone is on silent mode
                , options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            print("AVAudioSession configured for playback and active.")
        } catch {
            print("Failed to set audio session category or active session: \(error.localizedDescription)")
        }
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
            let secondsPerMile = secondsPerMeter * metersPerMile
            let minutes = Int(secondsPerMile / 60)
            let seconds = Int(secondsPerMile.truncatingRemainder(dividingBy: 60))
            currentPace = String(format: "%d:%02d min/mile", minutes, seconds)
        } else {
            currentPace = "0:00 min/mile (stopped)"
        }

        // Announce pace every 0.1 miles
        let announcementIntervalMiles: CLLocationDistance = 0.1 // Announce every 0.1 miles
        let announcementIntervalMeters = announcementIntervalMiles * metersPerMile

        if totalDistance >= lastAnnouncedDistance + announcementIntervalMeters {
            let speechString = "Your current pace is \(currentPace). Total distance \(String(format: "%.1f", totalDistance / metersPerMile)) miles."
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

    internal func speak(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US") // You can change language
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        
        
        // Change audio session to .playback with .duckOthers BEFORE speaking
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                options: [.duckOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            print("AVAudioSession changed to playback with duckOthers before speaking.")
        } catch {
            print("Failed to set audio session for speaking: \(error.localizedDescription)")
            // If setting failed, don't try to speak
            return
        }
        
        // Stop any current speech if necessary, then speak
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .word)
        }
        speechSynthesizer.speak(utterance)
        print("Speaking: \(text)")
    }
    
    // This delegate method is called when an utterance has finished
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {

        do {
            // Explicitly DEACTIVATE the session first.
            // This tells the app it is done with its "active" ducking state.
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("AVAudioSession deactivated before reverting.")

            // Set the category back to ambient (after deactivation)
            try AVAudioSession.sharedInstance().setCategory(
                .ambient,
                options: [.mixWithOthers]
            )

            // ACTIVATE the ambient session again.
            // This tells the app to bring back the audo but non-ducking state.
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            print("AVAudioSession reverted to ambient and reactivated after speaking.")
        } catch {
            print("Failed to revert audio session to ambient: \(error.localizedDescription)")
        }
    }
}

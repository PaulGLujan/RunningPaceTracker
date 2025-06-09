import SwiftUI
import CoreLocation

struct ContentView: View {
    // Create an instance of our LocationManager, making it observable
    @StateObject var locationManager = LocationManager()
    
    var body: some View {
        VStack {
            Text("Running Pace Tracker")
                .font(.largeTitle)
                .padding()

            Spacer()

            // Display Authorization Status
            Text("Location Status: \(locationManager.authorizationStatus?.description ?? "N/A")")
                .font(.headline)
                .padding(.bottom, 5)

            // Display current pace
            Text("Current Pace: \(locationManager.currentPace)")
                .font(.title2)
                .padding(.bottom, 5)

            // Display Total Distance
            Text("Total Distance: \(String(format: "%.2f", locationManager.totalDistance / locationManager.metersPerMile)) miles")
                .font(.title2)
                .padding(.bottom, 5)

            // Display current speed (for debugging/info)
            Text("Speed: \(String(format: "%.2f", locationManager.currentSpeed * 2.23694)) mph") // Convert m/s to mph
                .font(.caption)
                .padding(.bottom)

            HStack {
                Button {
                    // Request authorization if not determined
                    if locationManager.authorizationStatus == .notDetermined {
                        locationManager.requestLocationAuthorization()
                    } else {
                        locationManager.startTracking()
                    }
                } label: {
                    Text("Start Run")
                        .font(.title)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                Button {
                    locationManager.stopTracking()
                } label: {
                    Text("Stop Run")
                        .font(.title)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }

            Spacer()
        }
        .onAppear {
            // Request authorization when the view appears if it hasn't been requested yet
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestLocationAuthorization()
            }
        }
    }
}

// Extension to make CLAuthorizationStatus printable for debugging
extension CLAuthorizationStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "When In Use"
        @unknown default: return "Unknown"
        }
    }
}

// For Xcode Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

import UIKit
import Flutter
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      if let dartDefinesEncoded = Bundle.main.object(forInfoDictionaryKey: "DART_DEFINES") as? String {
        // Split the Base64-encoded string into individual defines
        let dartDefines = dartDefinesEncoded
            .components(separatedBy: ",")
            .compactMap { Data(base64Encoded: $0) }
            .compactMap { String(data: $0, encoding: .utf8) }

        // Look for the GOOGLE_MAPS_KEY in the decoded defines
        for define in dartDefines {
            if define.starts(with: "GOOGLE_MAPS_KEY=") {
                let apiKey = define.replacingOccurrences(of: "GOOGLE_MAPS_KEY=", with: "")
                GMSServices.provideAPIKey(apiKey)
                break
            }
        }
    } else {
        fatalError("DART_DEFINES is missing or invalid in Info.plist")
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseFunctions
import GoogleSignIn
final class FirebaseManager {
    static let shared = FirebaseManager()
    let auth: Auth
    let db: Firestore
    let functions: Functions

    private init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        } else {
            assertionFailure("Missing Firebase clientID for Google Sign-In configuration")
        }
        FirebaseConfiguration.shared.setLoggerLevel(.min)
        self.auth = Auth.auth()
        self.db = Firestore.firestore()
        self.functions = Functions.functions()
    }
}

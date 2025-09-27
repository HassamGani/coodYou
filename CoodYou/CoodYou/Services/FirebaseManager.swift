import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

final class FirebaseManager {
    static let shared = FirebaseManager()
    let auth: Auth
    let db: Firestore
    let functions: Functions

    private init() {
        // Firebase SDK v12+ does not expose FirebaseConfiguration in the same way.
        // Initialize the services directly.
        self.auth = Auth.auth()
        self.db = Firestore.firestore()
        self.functions = Functions.functions()
    }
}

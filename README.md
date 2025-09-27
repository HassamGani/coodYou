# CampusDash Firebase MVP

This repository contains the Firebase-backed implementation of the CampusDash MVP. It includes:

- **iOS app** built with SwiftUI integrating Firebase Auth, Firestore, Functions, and Messaging.
- **Firebase Cloud Functions** for order pooling, run assignment, dasher workflows, and Stripe onboarding scaffolding.
- **Firestore rules and indexes** tuned for the marketplace flows.
- **Configuration** for dining hall seed data and Firebase emulator usage.

## Prerequisites

- Xcode 15+
- Swift 5.9+
- Node.js 18+
- Firebase CLI (`npm install -g firebase-tools`)

## Project structure

```
.
├── ios/CoodYou              # SwiftUI client (Xcode project folder)
├── ios/CampusDashApp        # SwiftUI client
├── functions                # Firebase Cloud Functions (TypeScript)
├── firestore.rules          # Firestore security rules
├── firestore.indexes.json   # Required composite indexes
├── storage.rules            # Storage rules for proof uploads
└── config                   # Seed data and environment helpers
```

## iOS app setup

1. Open `ios/CoodYou` in Xcode.
1. Open `ios/CampusDashApp` in Xcode.
2. Add your Firebase `GoogleService-Info.plist` to the `Resources` folder.
3. Enable the following capabilities: Push Notifications, Background Modes (Location updates), and Location Updates.
4. Install Firebase SDKs via Swift Package Manager:
   - `https://github.com/firebase/firebase-ios-sdk.git`
   - Products: FirebaseAuth, FirebaseFirestore, FirebaseFunctions, FirebaseMessaging, FirebaseCore.
5. Configure Push Notifications and APNs keys in the Firebase console.

## Firebase backend setup

```bash
cd functions
npm install
npm run build
firebase emulators:start
```

Deploy when ready:

```bash
firebase deploy --only functions,firestore:rules,firestore:indexes,storage
```

### Seeding dining halls

Use the Firebase CLI to import the provided seed data:

```bash
firebase firestore:import config/columbia_halls.json --project <your-project>
```

Alternatively, run a temporary script using the Admin SDK:

```bash
node -e "const admin=require('firebase-admin');admin.initializeApp();const data=require('../config/columbia_halls.json');const db=admin.firestore();data.forEach(doc=>db.collection('dining_halls').doc(doc.id).set(doc));"
```

## Stripe integration

The `requestStripeOnboarding` callable function currently returns a placeholder response. Replace it with logic that creates an onboarding link using Stripe Connect when you are ready to process payouts.

## Testing

- Unit test the TypeScript functions with `firebase-functions-test`.
- Use Firebase Emulator Suite to validate Firestore rules and callable endpoints.
- In Xcode, create UI tests for order placement and dasher claim flows once Firebase configuration is in place.

## Environment variables

Configure the following Firebase Function environment variables before deploying:

```bash
firebase functions:config:set stripe.secret_key="sk_live_..." platform.fee_default=0.0
```

Access them in code via `functions.config().stripe.secret_key`.

## Security considerations

- Firestore rules restrict order creation and updates to the owning user and require authentication for run operations.
- Use App Check in production to mitigate abuse of callable functions.
- Consider adding rate-limiting logic to Cloud Functions for additional protection.

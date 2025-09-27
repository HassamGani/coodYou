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
├── CoodYou/CoodYou          # SwiftUI client (Xcode project folder)
├── functions                # Firebase Cloud Functions (TypeScript)
├── firestore.rules          # Firestore security rules
├── firestore.indexes.json   # Required composite indexes
├── storage.rules            # Storage rules for proof uploads
└── config                   # Seed data and environment helpers
```

## iOS app setup

1. Open `CoodYou/CoodYou` in Xcode.
2. Add your Firebase `GoogleService-Info.plist` to the `Resources` folder.
3. Enable the following capabilities: Push Notifications, Background Modes (Location updates), and Location Updates.
4. Install Firebase SDKs via Swift Package Manager:
   - `https://github.com/firebase/firebase-ios-sdk.git`
   - Products: FirebaseAuth, FirebaseFirestore, FirebaseFunctions, FirebaseMessaging, FirebaseCore.
   - Add `FirebaseFirestoreSwift` overlay if using Codable helpers.
   - Add `https://github.com/google/GoogleSignIn-iOS` (GoogleSignIn) for Google login.
5. Add `AuthenticationServices`, `PassKit`, and `Sign in with Apple` capabilities to the app target.
6. Configure Push Notifications and APNs keys in the Firebase console.
7. (Optional) Create an Apple Pay merchant ID and update `merchant.com.campusdash` inside `AddPaymentMethodSheet.swift`.

### Authentication and onboarding

- **Email / password** sign-up enforces `@columbia.edu` or `@barnard.edu` addresses and captures first/last names plus optional phone numbers.
- **Google** and **Apple** sign-in routes through Firebase Auth, automatically provisioning a Firestore profile and school record when an allowed campus email is detected.
- First launch presents the new **LandingView** with CampusDash branding and options to register, sign in, or use Apple/Google credentials.
- After authentication the user must pick a campus (currently only Columbia/Barnard) before the main tab experience unlocks.

### Profile, settings, and payments

- The profile tab now exposes verification status, campus affiliation, and a rich settings surface for notifications, live location, auto-accepting runs, and Apple Pay confirmation requirements.
- Payment methods are stored per-user in Firestore under `users/{uid}/paymentMethods` and can include Apple Pay, Stripe-linked cards, manual cards, PayPal, or Cash App references.
- Adding Apple Pay launches a `PKPaymentAuthorizationController` so users double-click the side button to complete setup; other methods capture descriptive metadata only (never full PAN data).
- Users can manage default payment methods, remove entries, and trigger password resets directly from the profile tab.

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

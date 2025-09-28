# CampusDash Firebase MVP

This repository contains the Firebase-backed implementation of the CampusDash MVP. It includes:

- **iOS app** built with SwiftUI integrating Firebase Auth, Firestore, Functions, and Messaging.
- **Web app** built with Next.js and Tailwind that mirrors the Uber-style dispatcher for CampusDash.
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
├── CoodYouWeb               # Next.js web client (Firebase + Mapbox UI)
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
5. Add `PassKit` and push capabilities; Sign in with Apple is no longer required for the mobile client.
6. Configure Push Notifications and APNs keys in the Firebase console.
7. (Optional) Create an Apple Pay merchant ID and update `merchant.com.campusdash` inside `AddPaymentMethodSheet.swift`.

### Authentication and onboarding

- **Email / password** sign-up enforces `@columbia.edu` or `@barnard.edu` addresses and captures first/last names plus optional phone numbers.
- **Google** OAuth and password login route through Firebase Auth, automatically provisioning a Firestore profile and school record when an allowed campus email is detected.
- First launch presents the new **LandingView** with CampusDash branding and options to register, sign in via email, or continue with Google.
- After authentication the user must pick a campus (currently only Columbia/Barnard) before the main tab experience unlocks.

## Auth experience (2025 redesign)

- **Visual rationale**: the shell combines Uber’s neutral boldness (high-contrast SF type, black/white palette, ruthless hierarchy) with Cluely’s calm micro-interactions (airy 8pt grid, gentle elevation, matched-geometry transitions). Spacing, typography, and the accent palette are codified in `Theme.swift` and mirrored in `Resources/theme-tokens.json` for design/development parity.
- **SwiftUI-first architecture**: `AuthShellView` orchestrates `WelcomeSignInView`, `CreateAccountView`, `CodeEntryView`, `ForgotPasswordView`, and shared components (OAuth buttons, legal footer, toast banner, password meter). A single `AuthShellViewModel` state machine (`.welcome`, `.emailEntry`, `.codeEntry`, `.creating`, `.forgot`, `.success`, `.error`) keeps transitions inline instead of full-screen jumps.
- **HIG & motion compliance**: controls honour 44pt touch targets, the primary CTA animates with a spring while respecting Reduce Motion, and haptics (`.light`, `.warning`, `.success`) reinforce validation events.
- **Accessibility checklist**:
  - Dynamic Type up to XXL with graceful wrapping.
  - VoiceOver labels for fields, buttons, divider, and legal text; inline errors announce via `auth.inlineError` accessibility element.
  - Contrast > WCAG AA in light/dark, no pure white backgrounds (`bg.base` resolves to #FFFFFF light / #0B0B0C dark with material wrappers).
  - RTL verified in previews; localization ready via `NSLocalizedString` keys listed below.
- **Micro-interactions**: the primary CTA uses `PrimaryButtonStyle` for press scaling, spinner, and success morph; `CheckmarkSuccess` animates a trimmed circle + SF Symbol checkmark (no external Lottie dependency) for the 1.5s success dwell before navigation.
- **System feedback**: inline errors live under their field, `ToastBanner` surfaces network or linking issues, and resend countdown disables the code button for 30s.

### Home map experience

- `HomeView` now opens to a full-screen MapKit canvas with an Apple Maps–style floating search bar. The screen stays map-first; no cards appear until the user searches or taps a dining hall.
- `SchoolService` and the new `DiningHallService` hydrate the `/schools` and `/dining_halls` collections, so search is an instant, on-device filter that groups results by school and hall.
- Selecting a school focuses the visible pins for that campus; selecting a hall recenters the map, highlights the custom marker, and presents `DiningHallDetailView` in a sheet for menus and checkout.
- Active orders surface as a compact floating pill; tapping it opens the existing handoff flow without cluttering the primary map UI.

### Integration guide

1. Swap `AuthShellView(service:)` injection in `LandingView` with a production `AuthFlowService` implementation that calls your backend for passwordless links/codes.
2. Implement `requestCode`, `verifyCode`, and `createAccount` to hit your auth API; map backend errors to `AuthFlowError` for consistent messaging.
3. Wire `AuthShellViewModel.handleOAuthSuccess` with real “new user” / “link required” flags from backend responses.
4. Provide legal content by replacing `auth.legal.placeholder` strings or presenting rich Markdown within `LegalSheetView`.
5. Add `message`/`mailto` URL schemes to `LSApplicationQueriesSchemes` if you keep the “Open email app” shortcut.
6. Update UI tests if you localise the displayed strings (see key list below) and keep the accessibility identifiers (`auth.emailField`, `auth.primaryButton`, `auth.inlineError`).
7. Seed `/schools` and `/dining_halls` in Firestore; `SchoolService` and `DiningHallService` expect the schema outlined in this README and drive both authentication checks and the map experience.

### Testing

- **Unit**: `AuthShellViewModelTests` exercise state transitions (email validation, OTP paste, password strength) with the actor-based `MockAuthFlowService`.
- **Snapshot**: `AuthShellSnapshotTests` renders the welcome state via `ImageRenderer` to guard against layout regressions in light/dark appearances.
- **UI**: `CoodYouUITests.testAuthEmailValidation` walks the happy-path error case (typing an invalid email and asserting inline guidance).

### Localization keys

```
auth.brand,
auth.headline,
auth.subheadline,
auth.divider.or,
auth.field.email,
auth.field.name,
auth.field.password,
auth.placeholder.email,
auth.placeholder.name,
auth.placeholder.password,
auth.cta.continue,
auth.cta.signIn,
auth.cta.verify,
auth.cta.create,
auth.cta.reset,
auth.link.create,
auth.link.haveAccount,
auth.link.forgot,
auth.link.backToSignIn,
auth.link.usePassword,
auth.link.useEmailCode,
auth.code.title,
auth.code.subtitle,
auth.code.resend,
auth.code.resendIn,
auth.code.openMail,
auth.code.paste,
auth.toast.resetSent,
auth.toast.linkAccount,
auth.success.title,
auth.success.subtitle,
auth.legal.disclaimer,
auth.legal.terms,
auth.legal.privacy,
auth.legal.placeholder,
auth.validation.email,
auth.validation.name,
auth.validation.passwordWeak,
auth.validation.passwordRequired,
auth.validation.school,
auth.validation.codeLength,
auth.oauth.googleSubtitle,
auth.password.weak,
auth.password.medium,
auth.password.strong,
auth.error.invalidEmail,
auth.error.invalidCode,
auth.error.expiredCode,
auth.error.accountExists,
auth.error.offline,
auth.error.oauthCancelled,
auth.error.server,
auth.error.generic,
auth.accessibility.loading,
auth.accessibility.create
```

Fill these in `Localizable.strings` for each supported locale; the current build falls back to key names until translations land.

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

## Web app setup (Next.js)

1. Install dependencies:

   ```bash
   cd CoodYouWeb
   npm install
   ```

2. Create a `.env.local` file in `CoodYouWeb/` with your Firebase config and optional Mapbox token:

   ```bash
   NEXT_PUBLIC_FIREBASE_API_KEY=...
   NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=...
   NEXT_PUBLIC_FIREBASE_PROJECT_ID=...
   NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=...
   NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=...
   NEXT_PUBLIC_FIREBASE_APP_ID=...
   NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID=...
   NEXT_PUBLIC_FIREBASE_REGION=us-central1
   NEXT_PUBLIC_MAPBOX_TOKEN=pk.ey...
   ```

   Set `NEXT_PUBLIC_USE_FIREBASE_EMULATORS=true` to target the Firebase Emulator Suite during local development.

3. Run the development server:

   ```bash
   npm run dev
   ```

   The app bootstraps Firebase Auth for Columbia/Barnard .edu addresses, renders the Uber-style dispatcher, dasher console,
   wallet, and admin controls, and shares the same Firestore collections/functions as the iOS client.

## Security considerations

- Firestore rules restrict order creation and updates to the owning user and require authentication for run operations.
- Use App Check in production to mitigate abuse of callable functions.
- Consider adding rate-limiting logic to Cloud Functions for additional protection.

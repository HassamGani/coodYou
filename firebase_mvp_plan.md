# CampusDash MVP Plan (Firebase-Centric)

## 1. Product Overview
- **Concept:** Peer-to-peer meal pickup where any student can act as buyer or dasher.
- **Initial Campus:** Columbia University (expandable to others via configurable data).
- **Core Mechanic:** Pair-based orders—two buyers share a run within the same dining hall and service window (Breakfast 7–12, Lunch 12–5, Dinner 5–9, overridable).

## 2. Pricing & Economics
- Buyer price per meal: `(meal_price / 2) + $0.50` (Breakfast $13 → $7.00 + $0.50, etc.).
- Dasher payout: Sum of both buyers' payments minus Stripe processing fees and optional platform fee (start at $0 to drive adoption).
- Solo fallback (feature flag): After timeout, offer single fulfillment at `0.75 * meal_price + $0.50`.

## 3. Order Lifecycle
1. `REQUESTED` – Buyer submits order and payment intent is created.
2. `POOLED` – Waiting for second buyer in same hall/window.
3. `READY_TO_ASSIGN` – Pair formed; broadcast to eligible dashers.
4. `CLAIMED` – Dasher accepts within claim window.
5. `IN_PROGRESS` – Dasher confirms pickup.
6. `DELIVERED` – Buyer confirms handoff via PIN; funds marked for release.
7. `PAID` – Stripe transfer to dasher completes.
8. `CLOSED` – Audit trail finalized.
- Failure states: `EXPIRED`, `CANCELLED_BUYER`, `CANCELLED_DASHER`, `DISPUTED`.

## 4. Firebase-Centric Architecture
### 4.1 Authentication & User Management
- **Firebase Authentication** with email link sign-in restricted to `.edu` domains; integrate phone number verification.
- Store user profiles in Firestore `users` collection: Stripe Connect onboarding status, ratings, notification preferences, device tokens.

### 4.2 Data Storage (Cloud Firestore)
Collections (subcollections where helpful):
- `dining_halls`: name, coordinates, campus, active flag.
- `service_windows`: hall reference, window type, default start/end, override map keyed by date.
- `orders`: buyer ref, hall ref, window type, price, status, timestamps, `pair_group_id`.
- `pair_groups`: hall ref, window type, target size (2), members list, status.
- `runs`: dasher ref, hall ref, pair ref, status, timestamps, pickup/delivery metadata (including PIN hash, optional photo URL).
- `payments`: run ref, buyer ref, amount, fees, Stripe intent IDs, payout status.
- `devices`: user ref, APNs token, last seen, subscribed halls.
- `ratings`: rater ref, ratee ref, run ref, score, comment.
- `audit_events`: entity details, action, metadata, timestamp.
- Index guidelines: composite indices on `(hall_id, window_type, status)` for orders/runs; TTL fields for expiration queries.

### 4.3 Business Logic (Cloud Functions for Firebase)
- **HTTP callable functions / REST endpoints** mirroring MVP API surface:
  - `createOrder`, `getOrdersPool`, `claimRun`, `markPickedUp`, `confirmDelivery`, `createPaymentIntent`, `onboardDasher`, `getEarnings`, admin operations.
- **Firestore triggers** to:
  - Transition orders into `pair_groups` (matchmaking) when a compatible order arrives.
  - Broadcast FCM notifications when `READY_TO_ASSIGN` or status changes.
  - Auto-expire orders/runs using scheduled Cloud Functions (Pub/Sub).
- **Stripe webhooks** hosted in Cloud Functions to reconcile payment events and initiate payouts.

### 4.4 Realtime Updates & Queues
- **Firebase Cloud Messaging (FCM)** for push notifications (buyers/dashers/admins).
- **Firestore real-time listeners** in iOS app for live pool counts, run status, countdown timers.
- **Redis alternative:** For MVP we rely on Firestore & Functions; if needed, integrate **Firebase Realtime Database** (optional) as low-latency claim lock store with `run_claims/{runId}` entries using `transaction` semantics.

### 4.5 Location & Geofencing Data
- Store geofence definitions within `dining_halls` documents: radius, meet points, custom service windows.
- Use Cloud Functions to manage topic subscriptions: when user enters hall (client-detected), call `registerPresence` function updating `devices` and subscribe to hall-specific FCM topics.

### 4.6 Admin Console (Firebase Hosting + React/Next.js)
- Deploy lightweight admin panel via Firebase Hosting connected to Firestore.
- Admin authentication via Firebase Auth with custom claims (`role: admin`).
- Features: manage halls/windows, monitor live pools/runs (Firestore listeners), trigger refunds, toggle platform fee config (stored in `config/global` document).

## 5. Payments (Stripe + Firebase)
- Store Stripe keys in **Firebase Functions config** (`firebase functions:config:set`).
- **Stripe Connect Express** onboarding via `onboardDasher` function generating account links.
- Payment flow:
  1. Client requests `createPaymentIntent` → Cloud Function creates Payment Intent with buyer amount.
  2. After delivery confirmation, `confirmDelivery` triggers function to capture payments and create Stripe Transfer to dasher.
  3. Store all Stripe event payloads in Firestore `audit_events` for traceability.
- Handle idempotency using Firestore documents that track last action IDs.

## 6. iOS App (SwiftUI)
### 6.1 Tech Stack
- SwiftUI + Combine/async-await.
- Firebase SDKs: Auth, Firestore, Functions, Messaging, Storage (optional for proof photos).
- Stripe iOS SDK for payment sheet + Connect onboarding flows (via web view).
- Core Location for geofence monitoring; background tasks to refresh hall proximity state.

### 6.2 Key Screens & Flows
1. **Home** – Select hall/window, view live pool counts (Firestore snapshot), place order.
2. **Order Status** – Track pairing progress, countdown, meeting PIN display.
3. **Dasher Hub** – Toggle availability, view claim offers, claim run with timer, update status.
4. **Wallet** – Earnings history from `payments` collection, Stripe onboarding status.
5. **Profile** – .edu verification state, phone verification, notification prefs, rating summary.
6. **Admin (role-based)** – Manage halls, override windows, view live runs; hidden unless `role=admin` claim.

### 6.3 Notifications & Presence
- Register APNs token with Firebase Messaging; Cloud Function associates token with halls when user indicates presence.
- Dasher claim notifications prioritized: in-hall tokens topic > 150m > 400m radius topics.
- Client handles claim countdown using timestamp from Firestore document to avoid clock drift.

### 6.4 Security Rules
- Write fine-grained Firestore Security Rules:
  - Users can read/write their own orders; dashers can read runs they claimed.
  - Admin operations require custom claim.
  - Use `allow update` with server-side Cloud Functions for sensitive transitions (e.g., payment status) to prevent client tampering.

## 7. Matching Logic
- Cloud Function `onOrderCreated` listens to new `orders` with status `REQUESTED`.
- Attempts to find existing `pair_group` for same hall/window with open slot (query Firestore with limit 1).
- If found, add order to group and update statuses to `READY_TO_ASSIGN`; else create new pair group.
- `createRun` function triggered when pair group reaches target size, generating run document and status `READY_TO_ASSIGN`.
- Claim flow uses Firestore transaction or Realtime Database transaction to ensure single dasher claim per run.
- Scheduled function checks stale pairs/runs, triggers notifications or fallback pricing.

## 8. Ops & Monitoring
- Use **Firebase Crashlytics** and **Performance Monitoring** in iOS app.
- Enable **Firebase App Check** to mitigate abuse.
- Log structured events from Functions to Google Cloud Logging with request IDs.
- Daily export of Firestore collections to BigQuery (via Firebase integration) for analytics.

## 9. Deployment & Environments
- Project setup: `campusdash-dev`, `campusdash-prod` Firebase projects.
- Use **Firebase Hosting** for admin panel and optionally marketing site.
- GitHub Actions workflow: lint/test Swift package, run unit tests, deploy Functions & Hosting via `firebase deploy --only functions,hosting` on main branch merges.
- Seed script (Cloud Function callable or CLI script) to load Columbia dining halls, service windows, meet points.

## 10. Testing Strategy
- **Cloud Functions:** Use Firebase Emulator Suite for integration tests covering order pairing, claim, delivery, payment flows.
- **iOS:** Unit tests for view models, integration tests with emulator using stubbed Functions.
- **End-to-End:** Script that simulates two buyers and one dasher using Firebase emulator + Stripe test keys.

## 11. Future Enhancements
- Photo proof storage in Firebase Storage (guarded by signed URLs).
- Reputation scoring pipeline leveraging BigQuery ML.
- Expand to multi-item orders, dynamic pricing, campus-wide promotions.
- Explore offline push fallback via SMS (Twilio) triggered by Cloud Functions when FCM delivery fails.

## 12. Prompt Template for AI Coding Assistants
```
You are building "CampusDash," an iOS SwiftUI app with a Firebase backend enabling students to buy or fulfill dining hall meals.

Requirements:
- Pair-based matching (2 buyers per run) within same dining hall & service window (Breakfast 7–12, Lunch 12–5, Dinner 5–9). Allow admin overrides per hall.
- Pricing: buyer pays meal_price/2 + $0.50; solo fallback (feature-flagged) uses 0.75*meal_price + $0.50.
- Order states: REQUESTED → POOLED → READY_TO_ASSIGN → CLAIMED → IN_PROGRESS → DELIVERED → PAID → CLOSED (+ failure states EXPired, CANCELLED_BUYER, CANCELLED_DASHER, DISPUTED).
- Firebase Auth (.edu email link + phone verification), Firestore for data model, Cloud Functions for business logic, Cloud Messaging for notifications, Firebase Hosting for admin panel.
- Stripe Connect Express for dashers; payment intent per buyer, transfer payout post-delivery confirmation (PIN).
- iOS app uses SwiftUI, Firebase SDKs, Stripe SDK, Core Location geofences, APNs push, Firestore listeners.
- Admin console (React/Next.js on Firebase Hosting) with CRUD for halls/windows, live order/run monitoring, fee toggle, refunds.
- Provide Firestore security rules, Functions, and iOS client code stubs with dependency injection and async/await patterns.
- Include Firebase Emulator test harness and GitHub Actions workflow for lint/test/deploy.
```

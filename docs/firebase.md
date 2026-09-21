# Firebase Cloud Messaging

ClassSync Android uses Firebase project `classsync-obl1vi0uzz`. The Android
application ID is `app.classsync.classsync`.

## Client configuration

FlutterFire generated:

- `apps/client/lib/firebase_options.dart`
- `apps/client/android/app/google-services.json`
- `apps/client/firebase.json`

The client requests notification permission when visible alerts or background
mobile sync are enabled. It registers its FCM token with the authenticated
ClassSync relay whenever either capability needs it, refreshes registration
when Firebase rotates the token, and unregisters it only when both are off.

## Relay credentials

In Firebase Console:

1. Open **Project settings → Service accounts**.
2. Generate a new private key for the Firebase Admin SDK service account.
3. Keep the downloaded JSON outside the repository.
4. Enable the Firebase Cloud Messaging API in the linked Google Cloud project
   if it is not already enabled.
5. Run `pnpm exec wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON` from
   `apps/relay`, then paste the complete JSON as the secret value.

The Worker exchanges the signed service-account JWT for a short-lived OAuth
token and calls FCM HTTP v1. Never commit the service-account JSON.

## Behavior

- Foreground message: starts shared sync engine.
- Notification tap: starts sync and opens ClassSync.
- Background delivery: quickly enqueues expedited WorkManager work keyed by the
  relay event; the worker initializes headless plugins, synchronizes account
  state, then claims and resumes the durable pipeline.
- WorkManager plus Fireflies overlap polling remains recovery.

Android may defer background work. Force-stopping ClassSync prevents delivery
until the user opens it again.

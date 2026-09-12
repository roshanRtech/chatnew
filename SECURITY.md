# Mighty Chat Application Security Standards & Hardening Guide

This document establishes the mandatory security rules, automated defenses, and developer guidelines for the Mighty Chat application (Flutter mobile & Web PWA).

---

## 1. Credentials & Secret Management (API Keys)
- **Status in Codebase**:
  - Remediated: Hardcoded vendor keys in `lib/utils/AppConstants.dart` (OneSignal REST key, Agora ID) have been purged and replaced with `String.fromEnvironment()`.
  - In `web_app/`: No production API keys are hardcoded.
- **Manual Action Required**:
  1. **Rotate Leaked Vendor Key**: The OneSignal REST key from the CodeCanyon template was exposed in the vendor zip. Log in to [OneSignal Dashboard](https://onesignal.com) and generate a **new REST API Key**.
  2. **Passing Build-Time Variables**: Pass keys at build time:
     ```bash
     flutter build apk --dart-define=AGORA_APP_ID="your_agora_id" --dart-define=ONESIGNAL_APP_ID="your_onesignal_id"
     ```
  3. **Never embed Master / Secret REST Keys in client code**: Dispatch push notifications via a Firebase Cloud Function, never via client HTTP calls.

---

## 2. Row Level Security (RLS) & Database Isolation
- **Firestore Rules (`firestore.rules`)**:
  - **User Isolation**: `match /users/{userId}` allows writes only if `request.auth.uid == userId`.
  - **Chat Privacy (No IDOR)**: Messages can only be read if `request.auth.uid in resource.data.users` or `request.auth.uid == resource.data.senderId`.
  - **Rate & Size Limits**: Reject messages larger than 50KB or missing required fields.
- **Storage Rules (`storage.rules`)**:
  - Enforces max upload limits (5MB for avatars, 25MB for media) and checks MIME type (`image/*`, `audio/*`, `application/pdf`).
- **Composite Indexes (`firestore.indexes.json`)**:
  - Pinned composite indexes for `messages` (`senderId` + `createdAt`, `tenantId` + `createdAt`) to prevent unbounded full collection scans.

---

## 3. Multi-Tenancy & Tenant ID Injection Prevention
- **Core Rule**: **NEVER** trust `tenant_id` sent in request bodies or query parameters.
- **Enforcement**:
  1. Multi-tenant middleware must extract the tenant ID exclusively from the cryptographically verified JWT (`decodedToken.tenantId`).
  2. Every database query must bind the tenant ID filter:
     ```javascript
     // Correct
     const query = db.collection('messages')
       .where('tenantId', '==', request.user.tenantId)
       .limit(50);
     ```
  3. Validate that database records match the session's tenant ID before returning data (blocks Cross-Tenant Data Hijacking).

---

## 4. Cross-Site Scripting (XSS) & Content Security
- **In `web_app/app.js`**:
  - All dynamic data (`chat.name`, `msg.text`, `story.userName`) is sanitized via `escapeHtml()`.
  - All media URLs are strictly verified via `sanitizeUrl()` to block `javascript:` or malicious URI protocol schemes.
  - Eliminated inline `onclick` string interpolation. Event listeners are bound via `addEventListener` and `data-` attributes.

---

## 5. SQL Injection & Local SQLite Defense
- **Rule**: Never concatenate strings in SQL queries. Always use parameterized queries.
- **In `SqliteMethods.dart`**:
  ```dart
  // Correct
  await db.query(tableName, where: 'logId = ?', whereArgs: [logId], limit: 50);
  ```

---

## 6. CSRF, Authentication & Session Security
- **Authentication**:
  - Store web JWT tokens in `HttpOnly`, `Secure`, `SameSite=Strict` cookies or transient memory, never in unencrypted local storage if holding sensitive admin capabilities.
  - Invalidate session caches upon logout.
- **CSRF**:
  - Always enforce anti-CSRF tokens for state-changing POST/PUT/DELETE requests when using cookie-based auth.

---

## 7. Memory Leaks & Resource Cleanup
- **Timers and Audio**:
  - Always call `clearInterval()` when stopping recording or calls.
  - Always stop all `MediaStreamTrack` instances:
    ```javascript
    stream.getTracks().forEach(track => track.stop());
    ```
  - In Flutter: Always call `streamSubscription.cancel()`, `timer.cancel()`, and `controller.dispose()` in `dispose()`.

---

## 8. Cryptographic Failures & External Entities (XXE)
- Use standard algorithms (AES-GCM 256, TLS 1.3). Never use ECB mode or hardcoded initialization vectors (IVs).
- Disable external entity resolution (DTD) in all XML/SVG parsers to prevent XXE.

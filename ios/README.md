# iOS Starter

This folder contains a local Swift Package named `AmonKit` plus a minimal app template.

## Recommended local setup

1. Open Xcode.
2. Create a new **iOS App** project.
3. Add `ios/AmonKit` as a **local package dependency**.
4. Copy the files from `ios/AppTemplate` into your app target.
5. Enable **Sign in with Apple** capability in Xcode when you are ready to test native sign-in.
6. Start the backend locally at `http://127.0.0.1:8000`.

## What is implemented

- Swift models aligned to the schema
- URLSession-based API client for auth, search, retrieve, compare, research
- SQLite-backed local workspace store
- Keychain-backed local encryption key storage
- AES-GCM export/import utility
- SwiftUI scaffold for sign-in, search, workspace, compare, research, and WebView browsing

## What to harden next

- replace the dev login exchange with verified Sign in with Apple token exchange
- add richer workspace editing and scoped notes UI
- add background refresh and better clean view parsing
- replace the built-in file protection + field encryption mix with SQLCipher if you want full encrypted-database semantics

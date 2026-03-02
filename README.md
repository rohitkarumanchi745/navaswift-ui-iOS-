# NAVA - Dating App (iOS)

A full-featured dating app built with **SwiftUI** and connected to a **Rust/Axum** backend. NAVA combines swipe-based discovery, video reels, real-time chat, and premium subscriptions into a native iOS experience.

## Features

### Discovery & Matching
- **Swipe-based discovery** with like, pass, and super-like actions
- **AI-powered insights** for match recommendations
- **Location-based** proximity filtering with configurable distance
- **University discovery** for student-verified profiles

### Reels
- **Short-form video reels** for profile expression
- **Private messaging** on reels (Instagram-style DM via reel)
- Video upload with caption and category tagging

### Chat & Communication
- **Real-time WebSocket chat** with typing indicators and read receipts
- **GraphQL-powered** message history with pagination
- **Voice & video call** integration (WebRTC signaling)
- Conversation list with unread badges

### Premium (StoreKit 2)
- **Gold, Platinum, Ultra** subscription tiers via Apple In-App Purchase
- Consumable products: boosts, super likes, spotlight
- Server-side transaction verification (`/api/payments/verify-apple`)
- Restore purchases support
- StoreKit Configuration file for sandbox testing

### Verification
- **Selfie verification** with liveness detection
- **Student verification** via university email OTP
- **Voice intro** recording and playback

### Profile & Settings
- Profile editing with photo upload
- Preference management (age range, distance, interests)
- Account deletion (GDPR/App Store compliant)
- Privacy policy and terms of service

## Architecture

```
nava/
├── Models/
│   └── UserProfile.swift          # User, Match, Chat, Like models
├── Services/
│   ├── APIService.swift           # REST + GraphQL client with retry logic
│   ├── AppConfig.swift            # Environment switching (dev/prod)
│   ├── AuthService.swift          # OTP auth, token management, keychain
│   ├── ChatWebSocket.swift        # WebSocket client for real-time chat
│   ├── LocationService.swift      # CoreLocation + backend sync
│   └── StoreKitManager.swift      # StoreKit 2 IAP management
├── Theme/
│   └── AppTheme.swift             # Colors, typography, design tokens
├── Views/
│   ├── AI/                        # AI match insights
│   ├── Chat/                      # ChatView, ConversationsView
│   ├── Discover/                  # Swipe card stack
│   ├── Legal/                     # Privacy policy, terms
│   ├── Matches/                   # Match list with premium gating
│   ├── Onboarding/                # Landing, login, OTP, profile setup
│   ├── Premium/                   # StoreKit 2 subscription UI
│   ├── Profile/                   # User profile display
│   ├── Reels/                     # Video reels feed + upload
│   ├── Settings/                  # Edit profile, preferences, account
│   └── Verification/              # Selfie, student, voice verification
├── navaApp.swift                  # App entry point, environment injection
└── Products.storekit              # StoreKit testing configuration
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI Framework | SwiftUI |
| State Management | `@StateObject`, `@EnvironmentObject`, `ObservableObject` |
| Networking | `URLSession` with retry, GraphQL, REST |
| Real-time | `URLSessionWebSocketTask` (native WebSocket) |
| Payments | StoreKit 2 (`Product`, `Transaction`, `AppStore.sync()`) |
| Auth | OTP via phone number, JWT tokens, Keychain storage |
| Location | CoreLocation with backend sync |
| Media | `AVPlayer` for reels, `AsyncImage` for photos |

## Backend

This app connects to a [Rust/Axum backend](https://github.com/rohitkarumanchi745/nava-dating-backend-main) providing:
- REST API + GraphQL + WebSocket endpoints
- PostgreSQL + Neo4j (dual-write) + Redis
- Payment processing (Apple StoreKit, Razorpay, Stripe)
- Federated learning for privacy-preserving recommendations
- LLM-based content labeling pipeline

## Setup

### Prerequisites
- Xcode 16+
- iOS 17.0+ deployment target
- Rust backend running locally (or update `AppConfig.swift` for remote)

### Run
1. Clone the repository
2. Open `nava.xcodeproj` in Xcode
3. For StoreKit testing: **Product > Scheme > Edit Scheme > Run > Options** → set StoreKit Configuration to `Products.storekit`
4. Build and run on simulator or device

### Environment Configuration
- **Debug builds**: connect to `http://127.0.0.1:8080` (local backend)
- **Release builds**: connect to `https://api.nava.app` (production)

Configure in `Services/AppConfig.swift`.

## API Endpoints Used

| Feature | Endpoint | Method |
|---------|----------|--------|
| Auth | `/send-otp`, `/verify-otp` | POST |
| Profile | `/update-profile`, `/profile/me` | POST, GET |
| Discovery | `/discover`, `/match/like`, `/match/pass` | GET, POST |
| Chat | `/ws/chat` (WebSocket), `/graphql` | WS, POST |
| Reels | `/reels`, `/reels/feed`, `/reels/message` | POST, GET |
| Payments | `/api/payments/verify-apple` | POST |
| Location | `/location/update` | POST |
| Verification | `/verify/selfie`, `/student/verify` | POST |
| Account | `/account/delete` | POST |

## License

Private - All rights reserved.

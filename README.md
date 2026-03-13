# NAVA - Dating App (iOS)

A full-featured dating app built with **SwiftUI** and connected to a **Rust/Axum** backend. NAVA combines swipe-based discovery, video reels, real-time chat, and premium subscriptions into a native iOS experience.

## Features

### Discovery & Matching
- **Swipe-based discovery** with like, pass, and swipe-up super-like gestures
- **Super Like** flow with dedicated `POST /match/super-like` endpoint, animated stamp overlay, and feedback banner
- **AI-powered insights** for match recommendations with compatibility scoring
- **Location-based** proximity filtering with configurable distance
- **University discovery** for student-verified profiles
- **Sent Likes** view with super-liked vs regular likes separated into sections
- **Matches** view with "Super Liked You" horizontal carousel, message requests, and regular likes grid

### Student Search
- **University-grouped results** — search results grouped by university with sticky headers showing graduation cap icon, university name, and student count
- **University autocomplete** — as-you-type dropdown combining trending universities + live API search (`/universities/search?q=...`)
- **Name + university search** — typing a name shows all matching users grouped under their universities
- **Advanced filters** — university, city, country, gender, age range, university tier
- **Dynamic pagination** — 50-result limit when filtering by university, 20 otherwise

### Reels
- **Short-form video reels** for profile expression
- **Parallel pipeline upload** — compression starts immediately on video pick, filter export runs while user browses, upload fires on Post tap
- **7 video filters** (Original, Vivid, Warm, Cool, Vintage, Drama, Fade) with real-time CIFilter preview thumbnails
- **AVVideoComposition-based** per-frame filter export with progress tracking
- **Private messaging** on reels (Instagram-style DM via reel)
- **Reel inbox** with conversation threads
- **Reel message composer** with reply context
- **Floating upload progress pill** showing pipeline status across all tabs

### Chat & Communication
- **Real-time WebSocket chat** with typing indicators and read receipts
- **GraphQL-powered** message history with pagination
- **Message requests** with accept/decline flow
- **Voice & video call** integration (WebRTC signaling via `CallManager`)
- Conversation list with unread badges

### Premium (StoreKit 2)
- **Gold, Platinum, Ultra** subscription tiers via Apple In-App Purchase
- Consumable products: boosts, super likes, spotlight
- Server-side transaction verification (`/api/payments/verify-apple`)
- Restore purchases support
- StoreKit Configuration file for sandbox testing

### Verification
- **Selfie verification** with liveness detection
- **Student verification** via university email OTP with multi-step flow
- **Student ID verification** with photo upload
- **Alumni verification** for graduated users
- **Campus verification** with location-based check-in
- **Enrollment proof** upload for manual review
- **Professional verification** for working professionals
- **Voice intro** recording and playback

### Profile & Settings
- Profile editing with photo upload and **university picker** (API-driven autocomplete)
- **Interleaved profile detail view** — photos interspersed with bio, interests, languages, and reels sections
- **My Reels** section on profile with horizontal thumbnail carousel
- Preference management (age range, distance, interests)
- **Invite friends** sharing flow
- Notification preferences
- Safety appeal submission
- Content moderation status display
- Account deletion (GDPR/App Store compliant)
- Privacy policy and terms of service

### Infrastructure
- **Deep linking** support for navigating to profiles, matches, and reels
- **Network monitoring** with connectivity status
- **Network metrics** tracking for API performance with circuit breaker
- **Push notification** management with background fetch
- **Local caching** for offline data persistence
- **Structured logging** via `NavLog` with categories
- **HEIF/WebP image decoding** support

## Architecture

The project uses a **Swift Package Manager (SPM)** modular architecture with 4 local packages:

```
nava/
├── nava/
│   ├── navaApp.swift                  # App entry point, environment injection
│   ├── Assets.xcassets                # Asset catalog
│   ├── Products.storekit              # StoreKit testing configuration
│   └── PrivacyInfo.xcprivacy          # Privacy manifest
│
├── Packages/
│   ├── NavCore/                       # Shared models, theme, utilities
│   │   └── Sources/NavCore/
│   │       ├── Models/
│   │       │   ├── UserProfile.swift          # User, Match, Chat, DiscoverProfile models
│   │       │   ├── StudentModels.swift        # Search, filters, student results
│   │       │   ├── UniversityModels.swift     # University search/autocomplete models
│   │       │   ├── GraphQLModels.swift        # GraphQL response types
│   │       │   ├── ReelMessageModels.swift    # Reel messaging models
│   │       │   ├── AIInsightsModels.swift     # AI insights response models
│   │       │   ├── VerificationModels.swift   # Verification status/type models
│   │       │   ├── StoreProductID.swift       # IAP product identifiers
│   │       │   └── ModerationStatus.swift     # Content moderation states
│   │       ├── Theme/
│   │       │   └── AppTheme.swift             # Colors, typography, spacing tokens
│   │       ├── UI/
│   │       │   ├── ErrorBanner.swift          # Reusable error banner
│   │       │   ├── FlowLayout.swift           # Flow layout helper
│   │       │   └── ModeratedPhotoView.swift   # Photo with moderation overlay
│   │       ├── Extensions/
│   │       │   ├── Array+Safe.swift           # Safe array subscript
│   │       │   └── ImageDecoding.swift        # HEIF/WebP image format support
│   │       ├── DeepLink.swift                 # Deep link routing
│   │       ├── LocalCache.swift               # Disk-based caching
│   │       └── Logger.swift                   # Structured logging (NavLog)
│   │
│   ├── NavNetworking/                 # API client layer
│   │   └── Sources/NavNetworking/
│   │       ├── APIService.swift               # REST + GraphQL client with retry
│   │       └── AppConfig.swift                # Environment switching (dev/prod)
│   │
│   ├── NavServices/                   # Business logic services
│   │   └── Sources/NavServices/
│   │       ├── AuthManager.swift              # OTP auth, JWT tokens, keychain
│   │       ├── StoreKitManager.swift          # StoreKit 2 IAP management
│   │       ├── ChatWebSocket.swift            # WebSocket client for real-time chat
│   │       ├── CallManager.swift              # WebRTC call signaling
│   │       ├── LocationManager.swift          # CoreLocation + backend sync
│   │       ├── NetworkMonitor.swift           # NWPathMonitor connectivity
│   │       ├── NetworkMetrics.swift           # API latency/error tracking
│   │       ├── PushNotificationManager.swift  # APNs registration + handling
│   │       ├── NotificationOutcome.swift      # Notification action results
│   │       ├── ReelUploadService.swift        # Parallel pipeline reel upload (compress → filter → upload)
│   │       └── VideoFilter.swift              # 7-filter enum with CIFilter + AVVideoComposition export
│   │
│   └── NavFeatures/                   # All UI views
│       └── Sources/NavFeatures/
│           ├── MainTabView.swift              # Root tab navigation
│           ├── Discover/
│           │   ├── DiscoverView.swift         # Swipe card stack + super like
│           │   └── SentLikesView.swift        # Sent likes with super like sections
│           ├── Search/
│           │   ├── StudentSearchView.swift    # Grouped university results + autocomplete
│           │   ├── StudentCard.swift          # Student result card
│           │   └── StudentFilterSheet.swift   # Filter modal
│           ├── Matches/
│           │   ├── MatchesView.swift          # Match list with super like carousel
│           │   └── MessageRequestDetailView.swift  # Message request accept/decline
│           ├── Chat/
│           │   ├── ConversationsView.swift    # Conversation list
│           │   ├── ChatView.swift             # Chat messages
│           │   ├── CallView.swift             # Voice/video call UI
│           │   └── MatchProfileDetailView.swift  # Interleaved profile detail from match/discover
│           ├── Reels/
│           │   ├── ReelsView.swift            # Vertical reel feed + upload flow + filter carousel
│           │   ├── ReelConversationView.swift # Reel DM thread
│           │   ├── ReelInboxView.swift        # Reel message inbox
│           │   └── ReelMessageComposer.swift  # Reel message input
│           ├── Premium/
│           │   └── PremiumView.swift          # Subscription UI
│           ├── Onboarding/
│           │   ├── LandingView.swift          # Welcome screen
│           │   ├── LoginView.swift            # Phone number entry
│           │   ├── OtpVerificationView.swift  # OTP input
│           │   ├── UpdateProfileView.swift    # Onboarding profile setup
│           │   └── UniversityPickerView.swift # University autocomplete picker
│           ├── Settings/
│           │   ├── SettingsView.swift         # Settings menu
│           │   ├── EditProfileView.swift      # Edit profile with university picker
│           │   ├── PreferencesView.swift      # Match preferences
│           │   ├── InviteView.swift           # Invite friends sharing
│           │   ├── NotificationPreferencesView.swift  # Push notification settings
│           │   └── SafetyAppealView.swift     # Appeal moderation decisions
│           ├── Profile/
│           │   └── ProfileView.swift          # User profile with My Reels section
│           ├── Verification/
│           │   ├── SelfieVerificationView.swift      # Liveness selfie check
│           │   ├── StudentVerificationView.swift     # University email OTP (multi-step)
│           │   ├── StudentIDVerificationView.swift   # Student ID photo upload
│           │   ├── AlumniVerificationView.swift      # Alumni verification flow
│           │   ├── CampusVerificationView.swift      # Location-based campus check-in
│           │   ├── EnrollmentProofView.swift         # Enrollment document upload
│           │   ├── ProfessionalVerificationView.swift # Professional verification
│           │   └── VoiceIntroView.swift              # Voice intro recording
│           ├── AI/
│           │   └── AIInsightsView.swift       # AI match insights with compatibility
│           └── Legal/
│               ├── PrivacyPolicyView.swift    # Privacy policy
│               └── TermsOfServiceView.swift   # Terms of service
```

### Package Dependency Graph

```
NavCore  (models, theme, utilities — no dependencies)
   ↓
NavNetworking  (API client — depends on NavCore)
   ↓
NavServices  (business logic — depends on NavCore + NavNetworking)
   ↓
NavFeatures  (all UI — depends on NavCore + NavNetworking + NavServices)
   ↓
nava app target  (entry point — depends on all packages)
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI Framework | SwiftUI |
| Architecture | SPM modular packages (NavCore → NavNetworking → NavServices → NavFeatures) |
| State Management | `@StateObject`, `@EnvironmentObject`, `ObservableObject` |
| Networking | `URLSession` with retry, GraphQL, REST |
| Real-time | `URLSessionWebSocketTask` (native WebSocket) |
| Payments | StoreKit 2 (`Product`, `Transaction`, `AppStore.sync()`) |
| Auth | OTP via phone number, JWT tokens, Keychain storage |
| Location | CoreLocation with backend sync |
| Media | `AVPlayer` for reels, `AVAssetExportSession` + `AVVideoComposition` for video filters, `AsyncImage` for photos |
| Image Processing | CoreImage (`CIFilter`) for real-time video filters |
| Connectivity | `NWPathMonitor` for network status |

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
2. Open `nava.xcodeproj` in Xcode (SPM packages resolve automatically)
3. For StoreKit testing: **Product > Scheme > Edit Scheme > Run > Options** → set StoreKit Configuration to `Products.storekit`
4. Build and run on simulator or device

### Environment Configuration
- **Debug builds**: connect to `http://127.0.0.1:8080` (local backend)
- **Release builds**: connect to `https://api.nava.app` (production)

Configure in `Packages/NavNetworking/Sources/NavNetworking/AppConfig.swift`.

## API Endpoints Used

| Feature | Endpoint | Method |
|---------|----------|--------|
| Auth | `/send-otp`, `/verify-otp` | POST |
| Profile | `/update-profile`, `/profile/me`, `/profile/:id` | POST, GET |
| Discovery | GraphQL `discover`, `likeUser`, `passUser` | POST |
| Super Like | `/match/super-like` | POST |
| Student Search | `/search/students?q=...&limit=...&offset=...` | GET |
| Search Suggestions | `/search/students/suggestions` | GET |
| University Autocomplete | `/universities/search?q=...&limit=8` | GET |
| Chat | `/ws/chat` (WebSocket), GraphQL queries | WS, POST |
| Reels | `/reels`, `/reels/feed`, `/reels/user/:id`, `/reels/message` | POST, GET |
| Payments | `/api/payments/verify-apple` | POST |
| Location | `/location/update` | POST |
| Verification | `/verify/selfie`, `/student/verify`, `/student/verify-id` | POST |
| Account | `/account/delete` | POST |

## License

Private - All rights reserved.

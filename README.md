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
- **Reel & voice intro indicators** on discover cards showing whether a user has uploaded reels or a voice intro

### Student Search
- **University-grouped results** — search results grouped by university with sticky headers showing graduation cap icon, university name, and student count
- **University autocomplete** — as-you-type dropdown combining trending universities + live API search (`/universities/search?q=...`)
- **Name + university search** — typing a name shows all matching users grouped under their universities
- **Advanced filters** — university, city, country, gender, age range, university tier
- **Dynamic pagination** — 50-result limit when filtering by university, 20 otherwise

### Reels
- **Short-form video reels** for profile expression
- **Apple Music integration** — search the Apple Music catalog, preview 30-second clips, and attach songs to reel uploads with adjustable music/original audio volume mixing
- **Video trimmer** — inline trim editor with frame strip timeline and draggable handles, triggered automatically when a picked video exceeds 30 seconds; supports export at up to 4K resolution
- **Parallel pipeline upload** — compression starts immediately on video pick, filter export runs while user browses, audio mixing runs on Post tap, upload fires when ready
- **Smart compression** — progressive downscale pipeline (4K → 1080p → 720p → 540p → 480p) with 50MB threshold to minimize upload size
- **Audio mixing** — `AVMutableComposition`-based audio mux blends music preview track (looped to fill duration) with original video audio at user-specified volumes, exported without video re-encode
- **7 video filters** (Original, Vivid, Warm, Cool, Vintage, Drama, Fade) with real-time CIFilter preview thumbnails
- **AVVideoComposition-based** per-frame filter export with progress tracking
- **Live upload preview** — tapping the thumbnail plays the filtered video alongside the music preview clip simultaneously before posting
- **Private messaging** on reels (Instagram-style DM via reel)
- **Reel inbox** with conversation threads and unread count badge
- **Reel message composer** with reply context
- **Reel activity feed** — full-screen activity list with filterable categories (All, Likes, Views, Messages, Creator Likes) fetched from `/reels/activity`
- **Like creator** action from reel cards
- **Global/Local feed scope** toggle for location-scoped reel discovery
- **Floating upload progress pill** showing pipeline status across all tabs
- **Draggable tab bar overlay** — swipe up/down to reveal/hide the tab bar within full-screen reel experience

### Chat & Communication
- **Real-time WebSocket chat** with typing indicators and read receipts
- **Real-time presence** — partner online status and last-seen timestamps derived from WebSocket connection state
- **GraphQL-powered** message history with pagination
- **Message requests** with accept/decline flow
- **Voice & video call** integration (WebRTC signaling via `CallManager`)
- Conversation list with unread badges

### Push Notifications
- **Notification Service Extension** — separate process intercepts push notifications before display to enrich with sender names and download profile photo / reel thumbnail media attachments
- **Actionable notification categories** — MESSAGE (inline reply), MATCH (View Match), LIKE (View Profile), REEL (View Reel + Reply) with lock screen action buttons
- **Inline reply from notifications** — reply directly from the lock screen without opening the app; routes to chat or reel thread REST endpoints
- **Deep link prefetch** — app prefetches conversation/match data via GraphQL before navigating so the destination screen loads instantly
- **Background fetch** — silent push prewarms badge counts via GraphQL `matches` query
- **Token lifecycle** — device token registered on login, unregistered on logout

### Premium (StoreKit 2)
- **Gold, Platinum, Ultra** subscription tiers via Apple In-App Purchase
- Consumable products: boosts, super likes, spotlight
- Server-side transaction verification (`/api/payments/verify-apple`)
- Restore purchases support
- StoreKit Configuration file for sandbox testing

### Verification
- **Live selfie camera** — in-app front-camera capture session using `AVCaptureSession` with mirrored output (not UIImagePickerController) and shutter flash animation
- **On-device face detection** — Vision framework confirms a face is present in the selfie before proceeding
- **On-device face matching** — selfie compared against existing profile photos using `VNGenerateImageFeaturePrintRequest` feature-print distance; rejected client-side if no match
- **Dual-layer verification** — client-side Vision framework face matching + server-side ArcFace ONNX model
- **Face detection on photo uploads** — profile photos must contain a visible face or they are rejected during onboarding
- **Student verification** via university email OTP with multi-step flow (tracks method: email, student ID, enrollment doc, campus, LMS)
- **Student ID verification** with photo upload
- **Alumni verification** for graduated users
- **Campus verification** with location-based check-in
- **Enrollment proof** upload for manual review
- **Professional verification** for working professionals
- **Voice intro** recording and playback

### Profile & Settings
- Profile editing with photo upload and **university picker** (API-driven autocomplete)
- **Interleaved profile detail view** — photos interspersed with bio, interests, languages, and reels sections
- **Photo gallery** — horizontal scrollable gallery of all profile photos on the profile screen
- **My Reels tab** on profile with 3-column thumbnail grid showing view/like count overlays
- **My Reels player** — full-screen paging reel player for the user's own uploads, launched from the profile grid
- **Reel engagement stats** — aggregate Likes / Views / Messages displayed on profile
- **Reel activity section** — latest 5 activity items (who liked/viewed/messaged) with "See All" link to full activity feed
- Preference management (age range, distance, interests)
- **Invite friends** sharing flow
- Notification preferences
- Safety appeal submission
- Content moderation status display
- Account deletion (GDPR/App Store compliant)
- Privacy policy and terms of service

### Onboarding
- **Permissions gate** — location, notification, camera, and photo library permissions requested before profile setup
- **Face-validated photo uploads** — photos rejected if no face detected via Vision framework
- **University picker** with API-driven autocomplete and trending suggestions

### Infrastructure
- **Deep linking** support for navigating to profiles, matches, reels, and reel message threads
- **Network monitoring** with connectivity status
- **Network metrics** tracking for API performance with circuit breaker and periodic flush (5-minute interval)
- **Push notification** management with actionable categories, inline reply, deep link prefetch, and background fetch
- **Notification Service Extension** for rich media push notifications
- **Local caching** with AES-GCM encryption for offline data persistence (including reel activity fallback)
- **Audio session management** with Bluetooth routing for calls, reels, and media
- **Structured logging** via `NavLog` with categories
- **HEIF/WebP/DNG/RAW image decoding** support via CIImage fallback
- **Graceful task cancellation** — SwiftUI `.task` cancellations handled without disrupting auth state
- **Upload retry** — failed reel uploads can be retried without re-compressing or re-filtering

## Architecture

The project uses a **Swift Package Manager (SPM)** modular architecture with 4 local packages plus a Notification Service Extension:

```
nava/
├── nava/
│   ├── navaApp.swift                  # App entry point, environment injection
│   ├── Assets.xcassets                # Asset catalog
│   ├── Products.storekit              # StoreKit testing configuration
│   └── PrivacyInfo.xcprivacy          # Privacy manifest
│
├── NotificationServiceExtension/
│   ├── NotificationService.swift      # Rich push: media attachments, categories, sender names
│   └── Info.plist                     # Extension configuration
│
├── Packages/
│   ├── NavCore/                       # Shared models, theme, utilities
│   │   └── Sources/NavCore/
│   │       ├── Models/
│   │       │   ├── UserProfile.swift          # User, Match, Chat, DiscoverProfile models
│   │       │   ├── StudentModels.swift        # Search, filters, student results
│   │       │   ├── UniversityModels.swift     # University search/autocomplete models
│   │       │   ├── GraphQLModels.swift        # GraphQL response types
│   │       │   ├── ReelMessageModels.swift    # Reel messaging, inbox, activity, match status models
│   │       │   ├── ReelMusic.swift            # Apple Music track metadata for reel uploads
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
│   │       │   └── ImageDecoding.swift        # Image decoding, face detection, face matching
│   │       ├── DeepLink.swift                 # Deep link routing (profiles, matches, reels, reel messages)
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
│   │       ├── ChatWebSocket.swift            # WebSocket client for real-time chat + presence
│   │       ├── CallManager.swift              # WebRTC call signaling
│   │       ├── LocationManager.swift          # CoreLocation + backend sync
│   │       ├── NetworkMonitor.swift           # NWPathMonitor connectivity
│   │       ├── NetworkMetrics.swift           # API latency/error tracking with periodic flush
│   │       ├── PushNotificationManager.swift  # APNs registration, categories, inline reply, prefetch
│   │       ├── NotificationOutcome.swift      # Notification action results
│   │       ├── AudioSessionManager.swift      # Audio session + Bluetooth routing
│   │       ├── ReelUploadService.swift        # 8-phase parallel pipeline (compress → filter → mix audio → upload)
│   │       └── VideoFilter.swift              # 7-filter enum with CIFilter + AVVideoComposition export
│   │
│   └── NavFeatures/                   # All UI views
│       └── Sources/NavFeatures/
│           ├── MainTabView.swift              # Root tab navigation + upload pill overlay + prefetch indicator
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
│           │   ├── ChatView.swift             # Chat messages + real-time presence
│           │   ├── CallView.swift             # Voice/video call UI
│           │   └── MatchProfileDetailView.swift  # Interleaved profile detail from match/discover
│           ├── Reels/
│           │   ├── ReelsView.swift            # Vertical reel feed + upload flow + filter carousel + music
│           │   ├── ReelConversationView.swift # Reel DM thread
│           │   ├── ReelInboxView.swift        # Reel message inbox
│           │   ├── ReelMessageComposer.swift  # Reel message input
│           │   ├── ReelActivityListView.swift # Filterable reel activity feed (likes, views, messages)
│           │   ├── MusicSearchView.swift      # Apple Music catalog search + 30-sec preview
│           │   └── VideoTrimmerView.swift     # Frame strip timeline trimmer with 30-sec limit
│           ├── Premium/
│           │   └── PremiumView.swift          # Subscription UI
│           ├── Onboarding/
│           │   ├── LandingView.swift          # Welcome screen
│           │   ├── LoginView.swift            # Phone number entry
│           │   ├── OtpVerificationView.swift  # OTP input
│           │   ├── UpdateProfileView.swift    # Onboarding profile setup + face validation
│           │   ├── UniversityPickerView.swift # University autocomplete picker
│           │   └── PermissionsGateView.swift  # Location, notification, camera permissions
│           ├── Settings/
│           │   ├── SettingsView.swift         # Settings menu
│           │   ├── EditProfileView.swift      # Edit profile with university picker
│           │   ├── PreferencesView.swift      # Match preferences
│           │   ├── InviteView.swift           # Invite friends sharing
│           │   ├── NotificationPreferencesView.swift  # Push notification settings
│           │   └── SafetyAppealView.swift     # Appeal moderation decisions
│           ├── Profile/
│           │   └── ProfileView.swift          # User profile + My Reels tab + engagement stats + activity
│           ├── Verification/
│           │   ├── SelfieVerificationView.swift      # Selfie check + face matching vs profile photos
│           │   ├── SelfieCameraView.swift             # Live AVCaptureSession front-camera capture
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
   ↓
NotificationServiceExtension  (rich push — standalone extension target)
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI Framework | SwiftUI |
| Architecture | SPM modular packages (NavCore → NavNetworking → NavServices → NavFeatures) |
| State Management | `@StateObject`, `@EnvironmentObject`, `ObservableObject` |
| Networking | `URLSession` with retry, GraphQL, REST |
| Real-time | `URLSessionWebSocketTask` (native WebSocket) with presence tracking |
| Payments | StoreKit 2 (`Product`, `Transaction`, `AppStore.sync()`) |
| Auth | OTP via phone number, JWT tokens, Keychain storage |
| Location | CoreLocation with backend sync |
| Media | `AVPlayer` for reels, `AVAssetExportSession` + `AVVideoComposition` for video filters, `AVMutableComposition` for audio mixing, `AsyncImage` for photos |
| Music | MusicKit (`MusicCatalogSearchRequest`) for Apple Music search and preview |
| Video Editing | `AVAssetImageGenerator` for frame strip thumbnails, `AVAssetExportSession` for trim export (up to 4K) |
| Image Processing | CoreImage (`CIFilter`) for real-time video filters |
| Camera | `AVCaptureSession` + `AVCapturePhotoOutput` for in-app selfie capture |
| Face Detection | Vision framework (`VNDetectFaceRectanglesRequest`, `VNGenerateImageFeaturePrintRequest`) |
| Push Notifications | `UNUserNotificationCenter` with actionable categories, `UNNotificationServiceExtension` for rich media |
| Encryption | CryptoKit (AES-GCM) for local cache |
| Connectivity | `NWPathMonitor` for network status |

## Backend

This app connects to a [Rust/Axum backend](https://github.com/rohitkarumanchi745/nava-dating-backend-main) providing:
- REST API + GraphQL + WebSocket endpoints
- PostgreSQL + Neo4j (dual-write) + Redis
- Payment processing (Apple StoreKit, Razorpay, Stripe)
- ArcFace ONNX model for server-side face verification
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
- **Debug builds**: connect to `http://192.168.1.103:8080` (local backend via Wi-Fi IP — update to your Mac's IP for physical device testing)
- **Release builds**: connect to `https://api.nava.app` (production)

Configure in `Packages/NavNetworking/Sources/NavNetworking/AppConfig.swift`.

## API Endpoints Used

| Feature | Endpoint | Method |
|---------|----------|--------|
| Auth | `/send-otp`, `/verify-otp`, `/refresh` | POST |
| Profile | `/update-profile`, `/profile/me`, `/profile/:id` | POST, GET |
| Discovery | GraphQL `discover`, `likeUser`, `passUser` | POST |
| Super Like | `/match/super-like` | POST |
| Student Search | `/search/students?q=...&limit=...&offset=...` | GET |
| Search Suggestions | `/search/students/suggestions` | GET |
| University Autocomplete | `/universities/search?q=...&limit=8` | GET |
| Chat | `/ws/chat` (WebSocket), GraphQL queries | WS, POST |
| Messages | `/messages` | POST |
| Reels | `/reels`, `/reels/feed`, `/reels/feed?scope=local`, `/reels/user/:id` | POST, GET |
| Reel Messaging | `/reels/message`, `/reels/:reelId/message` | POST |
| Reel Activity | `/reels/activity?limit=50` | GET |
| Reel Inbox | `/reels/inbox?limit=...&unread_only=true` | GET |
| Reel Interactions | `/reels/:reelId/like-creator` | POST |
| Payments | `/api/payments/verify-apple` | POST |
| Location | `/location/update` | POST |
| Verification | `/verify/selfie`, `/student/verify`, `/student/verify-id` | POST |
| Notifications | `/api/notifications/register-device`, `/api/notifications/unregister-device` | POST |
| Prefetch | GraphQL `conversation`, `match-detail` | POST |
| Account | `/account/delete` | POST |

## License

Private - All rights reserved.

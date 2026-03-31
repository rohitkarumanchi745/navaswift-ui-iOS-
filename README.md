# NAVA - Dating App (iOS)

A full-featured dating app built with **SwiftUI** and connected to a **Rust/Axum** backend. NAVA combines swipe-based discovery, video reels, real-time chat, social features, fitness tracking, outdoor exploration, and premium subscriptions into a native iOS experience.

## Features

### Discovery & Matching
- **Swipe-based discovery** with like, pass, and swipe-up super-like gestures
- **Super Like** flow with dedicated `POST /match/super-like` endpoint, animated stamp overlay, and feedback banner
- **AI-powered insights** for match recommendations with compatibility scoring
- **Federated learning** — on-device model training from swipe interactions sends weight deltas (not raw data) to the server for privacy-preserving recommendation improvements
- **Location-based** proximity filtering with configurable distance
- **University discovery** for student-verified profiles
- **Sent Likes** view with super-liked vs regular likes separated into sections
- **Matches** view with "Super Liked You" horizontal carousel, message requests, and regular likes grid
- **Reel & voice intro indicators** on discover cards showing whether a user has uploaded reels or a voice intro
- **Infinite pagination** — discover feed auto-fetches more profiles when running low, with `excludeIds` deduplication to prevent repeats
- **Offline swipe queue** — swipes made without connectivity are persisted to disk and flushed automatically when the network is restored (24-hour expiry)

### Student Search
- **University-grouped results** — search results grouped by university with sticky headers showing graduation cap icon, university name, and student count
- **University autocomplete** — as-you-type dropdown combining trending universities + live API search (`/universities/search?q=...`)
- **Name + university search** — typing a name shows all matching users grouped under their universities
- **Advanced filters** — university, city, country, gender, age range, university tier
- **Dynamic pagination** — 50-result limit when filtering by university, 20 otherwise

### Music Taste & Compatibility
- **Apple Music integration** — syncs top genres and artists via MusicKit
- **Spotify integration** — OAuth 2.0 PKCE flow via `ASWebAuthenticationSession`, syncs top artists and genres from Spotify Web API
- **Dual-source sync** — merges and deduplicates Apple Music + Spotify data, posts top 10 genres and artists to `/music/sync`
- **Music compatibility** — per-profile compatibility score with shared genres/artists breakdown via `/music/compatibility/:id`
- **Music Taste view** — genre chips, artist carousel, Spotify connect/disconnect, and compatibility display

### Fitness & Strava
- **HealthKit integration** — syncs calories, active minutes, and workouts
- **Strava integration** — OAuth 2.0 flow for importing activities, routes, elevation, and segment efforts
- **Weekly stats** — calories burned, active minutes, workout count, streak, and fitness score via `/fitness/stats`
- **Goals & progress** — configurable weekly targets for calories, minutes, and workouts with progress tracking
- **Leaderboard** — competitive fitness ranking by score
- **Workout history** — detailed activity log with type icons (hiking, running, cycling, swimming, etc.)

### Outdoor Exploration
- **Community-curated outdoor spots** — treks, viewpoints, photo spots, lakes, parks, trails, heritage sites, waterfalls, campsites with ratings and match scores
- **Seasonal guide** — weather and recommendations by season/city
- **Visit logging** — record visits with weather conditions, duration, calories, and notes
- **Golden hour detection** — highlights optimal photography timing via sunrise/sunset data
- **Add new spots** — contribute outdoor discoveries with category, season, and time-of-day metadata

### Social Hub
- **Spots** — location-based ephemeral messages with reactions (like Stories pinned to a place), photo attachments, and message threads
- **Playgrounds** — group activities (study groups, hangouts, sports, gaming, music, food, travel) with member lists, join status, and capacity limits
- **Events** — location and date-based event coordination with RSVP tracking
- **Location search** — integrated map-based location picker for all social features

### Explorer Profile
- **Map search tracking** — logs place searches and navigation to build an explorer identity
- **Trending locations** — popular search destinations with search/navigation counts
- **Explorer profile** — personalized profile showing explorer type, top location categories, visit counts, and most-visited places

### Contact Matching
- **Contact sync** — syncs device contacts to identify friends already on Nava
- **Privacy controls** — configurable visibility for contact discovery, music taste sharing, and fitness data sharing

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
- **Cellular upload warning** — prompts confirmation before uploading on metered connections (cellular/hotspot)
- **HLS processing state** — shows "Processing..." overlay with spinner for reels still being transcoded server-side
- **Private messaging** on reels (Instagram-style DM via reel)
- **Reel inbox** with conversation threads and unread count badge
- **Reel message composer** with reply context
- **Reel activity feed** — full-screen activity list with filterable categories (All, Likes, Views, Messages, Creator Likes) fetched from `/reels/activity`
- **Like creator** action from reel cards
- **Global/Local feed scope** toggle for location-scoped reel discovery
- **Floating upload progress pill** showing pipeline status across all tabs
- **Draggable tab bar overlay** — swipe up/down to reveal/hide the tab bar within full-screen reel experience
- **Disk space check** — skips video caching when device storage is below 100MB
- **Upload retry** — failed reel uploads can be retried without re-compressing or re-filtering
- **LRU video cache** — caches 3 most recent reel videos for offline playback

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
- **Explorer profile** — search analytics and location category breakdown
- **Fitness detail** — HealthKit stats, Strava connection, workout history, goals, leaderboard
- **Music taste** — genre and artist breakdown with Spotify integration and compatibility scores
- **Contacts on Nava** — see which phone contacts are on the platform
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
- **Network monitoring** with connectivity status and metered connection detection (`isExpensive`)
- **Network metrics** tracking for API performance with circuit breaker and periodic flush (5-minute interval)
- **HTTP error handling** — 401 interceptor for session expiry, 403 forbidden detection, 5xx service unavailable with retry classification (`isRetryable`)
- **Push notification** management with actionable categories, inline reply, deep link prefetch, and background fetch
- **Notification Service Extension** for rich media push notifications
- **Local caching** with AES-GCM encryption for offline data persistence (including reel activity fallback)
- **Profile cache** — profile data cached on disk with TTL, loads instantly before network refresh
- **Discover cache** — cache-first loading for discover feed with background refresh
- **Matches cache** — cached match list for instant display on launch
- **Offline action queue** — swipes/likes/passes persisted to disk when offline, auto-flushed on reconnection (24-hour expiry)
- **Upload retry** — failed reel uploads can be retried without re-processing
- **Disk space awareness** — video caching skipped below 100MB free space
- **Audio session management** with Bluetooth routing for calls, reels, and media
- **Structured logging** via `NavLog` with categories
- **HEIF/WebP/DNG/RAW image decoding** support via CIImage fallback
- **Graceful task cancellation** — SwiftUI `.task` cancellations handled without disrupting auth state
- **Rate limiting** — swipe rate limiting to prevent abuse
- **Memory pressure handling** — responds to low memory warnings
- **Null island filtering** — rejects location coordinates at (0, 0)
- **Logout cleanup** — clears all caches, tokens, and local state on sign out

## Architecture

The project uses a **Swift Package Manager (SPM)** modular architecture with 4 local packages plus a Notification Service Extension:

```
nava/
├── nava/
│   ├── navaApp.swift                  # App entry point, environment injection
│   ├── Assets.xcassets                # Asset catalog
│   ├── Products.storekit              # StoreKit testing configuration
│   ├── Info.plist                     # App configuration
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
│   │       │   ├── ModerationStatus.swift     # Content moderation states
│   │       │   ├── ContactMatchingModels.swift # Contact sync and privacy models
│   │       │   ├── FLModels.swift             # Federated learning round/update models
│   │       │   ├── FitnessModels.swift        # Fitness stats, workouts, goals, leaderboard
│   │       │   ├── MapSearchModels.swift       # Map search, trending, explorer profile
│   │       │   ├── MusicTasteModels.swift      # Music taste sync, compatibility
│   │       │   ├── OutdoorModels.swift         # Outdoor spots, visits, seasonal guides
│   │       │   ├── SocialModels.swift          # Spots, playgrounds, events
│   │       │   └── StravaModels.swift          # Strava auth, activities, routes
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
│   │       ├── LocalCache.swift               # Disk-based caching with AES-GCM encryption
│   │       └── Logger.swift                   # Structured logging (NavLog)
│   │
│   ├── NavNetworking/                 # API client layer
│   │   └── Sources/NavNetworking/
│   │       ├── APIService.swift               # REST + GraphQL client with retry, 401/403/5xx handling
│   │       └── AppConfig.swift                # Environment switching (dev/prod)
│   │
│   ├── NavServices/                   # Business logic services
│   │   └── Sources/NavServices/
│   │       ├── AuthManager.swift              # OTP auth, JWT tokens, keychain, profile caching
│   │       ├── StoreKitManager.swift          # StoreKit 2 IAP management
│   │       ├── ChatWebSocket.swift            # WebSocket client for real-time chat + presence
│   │       ├── CallManager.swift              # WebRTC call signaling
│   │       ├── LocationManager.swift          # CoreLocation + backend sync
│   │       ├── NetworkMonitor.swift           # NWPathMonitor connectivity + metered detection
│   │       ├── NetworkMetrics.swift           # API latency/error tracking with periodic flush
│   │       ├── PushNotificationManager.swift  # APNs registration, categories, inline reply, prefetch
│   │       ├── NotificationOutcome.swift      # Notification action results
│   │       ├── AudioSessionManager.swift      # Audio session + Bluetooth routing
│   │       ├── ReelUploadService.swift        # 8-phase pipeline (compress → filter → mix → upload) with retry
│   │       ├── VideoFilter.swift              # 7-filter enum with CIFilter + AVVideoComposition export
│   │       ├── ContactMatchingService.swift   # Device contact sync and matching
│   │       ├── FederatedLearningService.swift # On-device FL training with weight delta upload
│   │       ├── FitnessService.swift           # HealthKit + Strava fitness tracking
│   │       ├── MapSearchService.swift         # Map search tracking and explorer profile
│   │       ├── MusicTasteSyncService.swift    # Apple Music + Spotify dual-source sync
│   │       ├── OfflineActionQueue.swift       # Offline swipe queue with auto-flush
│   │       ├── OutdoorService.swift           # Outdoor spots CRUD and visit logging
│   │       ├── SpotifyAuthManager.swift       # Spotify OAuth PKCE flow
│   │       └── StravaAuthManager.swift        # Strava OAuth flow
│   │
│   └── NavFeatures/                   # All UI views
│       └── Sources/NavFeatures/
│           ├── MainTabView.swift              # Root tab navigation + upload pill overlay + prefetch indicator
│           ├── Discover/
│           │   ├── DiscoverView.swift         # Swipe card stack + super like + pagination
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
│           │   ├── ReelsView.swift            # Vertical reel feed + upload flow + filter carousel + music + cellular warning
│           │   ├── ReelConversationView.swift # Reel DM thread
│           │   ├── ReelInboxView.swift        # Reel message inbox
│           │   ├── ReelMessageComposer.swift  # Reel message input
│           │   ├── ReelActivityListView.swift # Filterable reel activity feed (likes, views, messages)
│           │   ├── MusicSearchView.swift      # Apple Music catalog search + 30-sec preview
│           │   └── VideoTrimmerView.swift     # Frame strip timeline trimmer with 30-sec limit
│           ├── Social/
│           │   ├── SocialHubView.swift        # Social feed: spots, playgrounds, events
│           │   ├── CreateSpotView.swift       # Create location-based spot
│           │   ├── CreatePlaygroundView.swift # Create group activity
│           │   ├── CreateEventView.swift      # Create event with date/location
│           │   ├── SpotDetailView.swift       # Spot detail with reactions
│           │   ├── PlaygroundDetailView.swift # Playground detail with members
│           │   ├── EventDetailView.swift      # Event detail with RSVP
│           │   └── SocialLocationSearchSheet.swift  # Map-based location picker
│           ├── Outdoor/
│           │   ├── OutdoorView.swift          # Browse outdoor spots by category + seasonal guide
│           │   ├── OutdoorSpotDetailView.swift # Spot detail with weather, visits, memories
│           │   └── AddSpotView.swift          # Add new outdoor spot
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
│           │   ├── ProfileView.swift          # User profile + My Reels tab + engagement stats + activity
│           │   ├── ExplorerProfileView.swift  # Explorer analytics and location categories
│           │   ├── FitnessDetailView.swift    # HealthKit stats, Strava, workouts, goals, leaderboard
│           │   ├── MusicTasteView.swift       # Genre/artist breakdown + Spotify + compatibility
│           │   └── ContactsOnNavaView.swift   # Contacts already on Nava
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
| Networking | `URLSession` with retry, GraphQL, REST, 401/403/5xx error classification |
| Real-time | `URLSessionWebSocketTask` (native WebSocket) with presence tracking |
| Payments | StoreKit 2 (`Product`, `Transaction`, `AppStore.sync()`) |
| Auth | OTP via phone number, JWT tokens, Keychain storage, Spotify/Strava OAuth PKCE |
| Location | CoreLocation with backend sync |
| Media | `AVPlayer` for reels, `AVAssetExportSession` + `AVVideoComposition` for video filters, `AVMutableComposition` for audio mixing, `AsyncImage` for photos |
| Music | MusicKit (`MusicCatalogSearchRequest`) for Apple Music, Spotify Web API for Spotify |
| Video Editing | `AVAssetImageGenerator` for frame strip thumbnails, `AVAssetExportSession` for trim export (up to 4K) |
| Image Processing | CoreImage (`CIFilter`) for real-time video filters |
| Camera | `AVCaptureSession` + `AVCapturePhotoOutput` for in-app selfie capture |
| Face Detection | Vision framework (`VNDetectFaceRectanglesRequest`, `VNGenerateImageFeaturePrintRequest`) |
| Health & Fitness | HealthKit for workout/calorie/active-minute data |
| Push Notifications | `UNUserNotificationCenter` with actionable categories, `UNNotificationServiceExtension` for rich media |
| Encryption | CryptoKit (AES-GCM) for local cache |
| Connectivity | `NWPathMonitor` for network status + metered connection detection |
| Machine Learning | On-device federated learning with weight delta aggregation |

## Backend

This app connects to a [Rust/Axum backend](https://github.com/rohitkarumanchi745/nava-dating-backend-main) providing:
- REST API + GraphQL + WebSocket endpoints
- PostgreSQL + Neo4j (dual-write) + Redis
- Payment processing (Apple StoreKit, Razorpay, Stripe)
- ArcFace ONNX model for server-side face verification
- Federated learning aggregation for privacy-preserving recommendations
- LLM-based content labeling pipeline
- HLS video transcoding pipeline

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

### Optional Integrations
- **Spotify**: Register an app at [Spotify Developer Dashboard](https://developer.spotify.com/dashboard), add `nava://spotify-callback` as redirect URI, and replace `YOUR_SPOTIFY_CLIENT_ID` in `SpotifyAuthManager.swift`
- **Strava**: Register an app at [Strava API](https://www.strava.com/settings/api), add `nava://strava-callback` as redirect URI, and replace `YOUR_STRAVA_CLIENT_ID` in `StravaAuthManager.swift`

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
| Music Sync | `/music/sync` | POST |
| Music Compatibility | `/music/compatibility/:id` | GET |
| Fitness Sync | `/fitness/sync` | POST |
| Fitness Stats | `/fitness/stats`, `/fitness/workouts`, `/fitness/goals`, `/fitness/leaderboard` | GET, POST |
| Outdoor Spots | `/outdoor/spots`, `/outdoor/visit`, `/outdoor/memories`, `/outdoor/seasonal-guide` | GET, POST |
| Social | `/social/spots`, `/social/playgrounds`, `/social/events` | GET, POST |
| Contact Sync | `/contacts/sync` | POST |
| Federated Learning | `/fl/register`, `/fl/round`, `/fl/update` | GET, POST |
| Map Search | `/map/search`, `/map/trending`, `/map/interests` | GET, POST |
| Payments | `/api/payments/verify-apple` | POST |
| Location | `/location/update` | POST |
| Verification | `/verify/selfie`, `/student/verify`, `/student/verify-id` | POST |
| Notifications | `/api/notifications/register-device`, `/api/notifications/unregister-device` | POST |
| Prefetch | GraphQL `conversation`, `match-detail` | POST |
| Account | `/account/delete` | POST |

## License

Private - All rights reserved.

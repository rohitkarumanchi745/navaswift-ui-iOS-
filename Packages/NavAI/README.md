# NavAI — on-device chat suggestions (BitNet b1.58)

On-device chat-suggestion engine for Nava, powered by **BitNet b1.58 2B-4T** via
`bitnet.cpp`, with a hybrid router that prefers the server when online and falls
back to the on-device model — and finally to templates — so suggestions work
**fully offline**.

## Layers

| Layer | Target | Runs where | Notes |
|-------|--------|-----------|-------|
| Prompt + parsing + templates | `NavAIPrompt` | anywhere | Pure Foundation, unit-tested. Shared with the server path. |
| Native inference | `BitNetCore` (xcframework) | device | `bitnet.cpp` (llama.cpp + ternary kernels) + a thin C wrapper. |
| Engine + downloader + router | `NavAI` | device | `BitNetEngine` (actor), `BitNetModelManager`, `SuggestionEngine`. |

The tiered routing in `SuggestionEngine.suggestReplies`:

1. **Server** (`RemoteSuggestionProviding`) when online — best quality + personalization.
2. **On-device BitNet** when offline or the server fails.
3. **Templates** (`TemplateSuggestions`) — guaranteed non-empty fallback.

## One-time setup: build the native engine

The model weights and the C++ engine are **not** checked in. Build the
xcframework once on a Mac (Xcode + cmake + python3):

```bash
cd Packages/NavAI
./scripts/build-bitnet-ios.sh          # produces Frameworks/BitNet.xcframework
```

Pin `BITNET_REF` to a known-good commit for production builds. If a bump breaks
the build, the symbols to reconcile are marked `// API:` in `native/nava_bitnet.cpp`.

Then add `NavAI` as a local package dependency in `nava.xcodeproj` (it already
uses `Packages/*`), and host the GGUF on your CDN.

## Usage

```swift
import NavAI
import NavAIPrompt
import NavServices        // for NetworkMonitor

// NetworkMonitor already exposes `isConnected`.
extension NetworkMonitor: NetworkReachability {}

let spec = BitNetModelSpec(
    name: "bitnet-b1.58-2B-4T-i2s",
    remoteURL: URL(string: "https://cdn.nava.app/models/bitnet-2b-i2s.gguf")!,
    sha256: "…",           // from the built GGUF
    sizeBytes: 1_150_000_000
)

let modelManager = BitNetModelManager(spec: spec)
let suggestions = SuggestionEngine(
    modelManager: modelManager,
    reachability: networkMonitor,   // your @MainActor NetworkMonitor
    remote: nil                     // wire the server provider in the next slice
)

// Optional: pre-download on Wi-Fi so the offline path is ready.
suggestions.prewarm()

// Get suggestions (never throws; always returns something usable).
let context = ConversationContext(
    matchName: "Priya",
    myName: "Arjun",
    recentTurns: [
        .init(author: .them, text: "hey! how was your weekend?"),
        .init(author: .me,   text: "went climbing, it was unreal"),
        .init(author: .them, text: "no way, where do you climb?")
    ],
    tone: .warm,
    maxSuggestions: 3
)
let replies = await suggestions.suggestReplies(for: context)
```

## Tests

```bash
cd Packages/NavAI
swift test --filter NavAIPromptTests      # pure prompt/parse/template logic
```

`NavAIPrompt` has no native or UI dependencies, so its tests run on any host.
The `NavAI` target requires `Frameworks/BitNet.xcframework` (built above).

## Personalization (per-user, on-device)

Two independent layers make suggestions sound like *this* user — both optional,
both degrading gracefully to the shared model:

### 1. Retrieval ("write like me") — via Harrier embeddings

`EmbeddingProvider` produces vectors; the reference config targets
**`microsoft/harrier-oss-v1-0.6b`**. NOTE: I don't have that model's card, so
`EmbeddingModelConfig.dimension` (default 1024) and `.pooling` (default mean)
are best-guess defaults for a 0.6B embedder — **confirm them against the card**;
nothing else changes. Swap in a hosted API or CoreML/ONNX/GGUF runtime by
conforming `EmbeddingProvider`.

Flow: as the user sends messages, `SuggestionEngine.recordSentMessage` embeds
them into an on-device `UserStyleStore` (private, capped, never uploaded). At
suggestion time we embed the incoming message, retrieve the user's closest past
messages (`StyleRetrieval`), and inject them as voice exemplars in the prompt.

### 2. Per-user LoRA adapter ("my model")

A small LoRA adapter per user, applied on top of the frozen shared BitNet at
inference (`BitNetEngine.applyAdapter` → `nava_bitnet_set_adapter`). Adapters are
versioned and fetched by `LoRAAdapterManager`.

**Training is off-device (hybrid / federated), not on the phone.** On-device
backprop through a 2B base is impractical; instead:

```
 on-device                         server (reuses your FL + DP infra)
 ─────────                         ──────────────────────────────────
 collect signal ──(DP noise)──►   aggregate per-user gradients / data
 (UserStyleStore: the user's       train/refresh a small LoRA adapter
  own sent + replied messages)     per user (or per-cohort)
        ▲                                    │
        └──────── download adapter ◄─────────┘  (LoRAAdapterManager, versioned)
        │
   apply at inference (BitNetEngine) → personalized, offline generation
```

This matches the "Hybrid" choice: the phone contributes privacy-safe signal and
runs inference-with-adapter; the server does the heavy LoRA training and ships
the ~few-MB adapter back.

## Wiring personalization

```swift
let styleStore = UserStyleStore(userID: currentUserID)
let adapters   = LoRAAdapterManager()

// Embeddings: on-device Harrier (offline), wrapped in an LRU cache.
// `harrierModelURL` is a GGUF of microsoft/harrier-oss-v1-0.6b, downloaded like
// the base model. Or use RemoteEmbeddingProvider(endpoint:) for the hosted path.
let embedder = CachingEmbeddingProvider(
    HarrierEmbeddingProvider(modelPath: harrierModelURL.path, config: .harrier)
)

let suggestions = SuggestionEngine(
    modelManager: modelManager,
    reachability: networkMonitor,
    userID: currentUserID,
    embedder: embedder,
    styleStore: styleStore,
    adapterManager: adapters,
    // Points at the backend's GET /suggestions/adapter (see below).
    currentAdapterSpec: { await api.currentLoRAAdapter(for: currentUserID) }
)

// When the user sends a message, feed the style store (also raw material for
// the federated trainer's on-device signal):
suggestions.recordSentMessage(sentText, weight: gotReply ? 2 : 1)
```

> **Harrier caveat:** `EmbeddingModelConfig` defaults `dimension` to 1024 and
> `pooling` to mean for `microsoft/harrier-oss-v1-0.6b`. Confirm both against
> the model card and adjust `.harrier`; nothing else changes.

## Backend: FedLoRA (implemented in the Rust repo)

The per-user adapter lifecycle lives in `nava-dating-backend-main`:

| Endpoint | Auth | Purpose |
|----------|------|---------|
| `GET  /suggestions/adapter` | user | device fetches its active adapter spec |
| `POST /fl/lora/signal` | user | device submits DP-protected training signal |
| `POST /admin/lora/train` | admin | enqueue jobs for eligible users |
| `GET  /admin/lora/jobs/next` | worker | claim a job + its signals |
| `POST /admin/lora/adapter` | worker | register a trained adapter (activates it, pushes a `lora_adapter_ready` event to the device) |
| `POST /admin/lora/jobs/{id}/fail` | worker | report a failed job |

Migration `032_lora_adapters.sql`; the training worker is
`scripts/fedlora_trainer.py` (PyTorch + PEFT → GGUF via llama.cpp's
`convert_lora_to_gguf.py`).

## What's next (not in this slice)

- **Harrier `EmbeddingProvider` impl** once the model card confirms dim/pooling
  (on-device CoreML/ONNX, or hosted).
- **Server FedLoRA trainer**: the per-user adapter training job (backend) that
  `currentAdapterSpec` points at.
- **Server suggestion path**: implement `RemoteSuggestionProviding` (reuse
  `SuggestionPrompt` verbatim).
- **A SwiftUI suggestion bar** above the chat composer.

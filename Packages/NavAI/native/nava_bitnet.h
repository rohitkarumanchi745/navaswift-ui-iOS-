// nava_bitnet.h — minimal C API over bitnet.cpp (llama.cpp + ternary kernels).
//
// This is the *stable* surface the Swift layer talks to. It deliberately hides
// all of llama.cpp so the app never has to track llama.h churn — only this
// header and nava_bitnet.cpp move when the vendored engine is bumped.
//
// Threading: a `nava_bitnet_model` is NOT thread-safe. Own it from a single
// actor/queue (see BitNetEngine.swift, which wraps it in a Swift actor).

#ifndef NAVA_BITNET_H
#define NAVA_BITNET_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle to a loaded model + its inference context.
typedef struct nava_bitnet_model nava_bitnet_model;

// Model/context load parameters.
typedef struct {
    int32_t n_ctx;        // context window in tokens (0 = a sane default)
    int32_t n_threads;    // 0 = auto (hardware concurrency)
    int32_t n_gpu_layers; // Metal offload layers; 0 = CPU only (BitNet is CPU-first)
    bool    use_mmap;     // memory-map the GGUF (recommended on iOS)
    bool    embeddings;   // load as an embedding model (Harrier), not a generator
    int32_t pooling;      // embedding pooling: 0=mean, 1=cls, 2=last
} nava_bitnet_params;

// Sampling parameters for a single completion.
typedef struct {
    int32_t  max_tokens;      // hard cap on generated tokens
    float    temperature;     // 0 = greedy
    float    top_p;
    int32_t  top_k;
    float    repeat_penalty;
    uint32_t seed;            // 0 = random
    // NULL-terminated array of UTF-8 stop strings; generation halts once any
    // appears in the output. May be NULL.
    const char *const *stop;
} nava_bitnet_sampling;

// Sensible defaults (short, slightly creative — tuned for chat suggestions).
nava_bitnet_params   nava_bitnet_default_params(void);
nava_bitnet_sampling nava_bitnet_default_sampling(void);

// Process-wide backend init/teardown. Call init once at startup and free once
// at shutdown. Safe to call load/complete only between them.
void nava_bitnet_backend_init(void);
void nava_bitnet_backend_free(void);

// Load a GGUF model from disk. Returns NULL on failure; if `err`/`err_len` are
// provided, a human-readable reason is written there.
nava_bitnet_model *nava_bitnet_load(const char *model_path,
                                    nava_bitnet_params params,
                                    char *err, int err_len);

// Free a model handle. NULL-safe.
void nava_bitnet_free(nava_bitnet_model *model);

// Per-token streaming callback. `token_text` is UTF-8 and valid ONLY for the
// duration of the call. Return false to stop generation early (cancellation).
typedef bool (*nava_bitnet_token_cb)(const char *token_text, void *user_data);

// Run a completion for `prompt`, streaming tokens through `cb`. Returns the
// number of tokens generated, or -1 on error (with `err` filled if provided).
// Each call starts from a cleared KV cache, so completions are independent.
int32_t nava_bitnet_complete(nava_bitnet_model *model,
                             const char *prompt,
                             nava_bitnet_sampling sampling,
                             nava_bitnet_token_cb cb,
                             void *user_data,
                             char *err, int err_len);

// ---------------------------------------------------------------------------
// Per-user LoRA adapters (personalization at inference time).
//
// The base model stays shared and frozen; a small per-user LoRA adapter (GGUF)
// is loaded and applied on top. Training happens off-device (server/federated);
// here we only load + apply an adapter the device downloaded.
// ---------------------------------------------------------------------------

// Opaque handle to a loaded LoRA adapter.
typedef struct nava_bitnet_adapter nava_bitnet_adapter;

// Load a LoRA adapter (GGUF) for `model`. Returns NULL on failure (err filled).
nava_bitnet_adapter *nava_bitnet_adapter_load(nava_bitnet_model *model,
                                              const char *adapter_path,
                                              char *err, int err_len);

// Apply `adapter` at `scale` (typically 1.0), replacing any active adapter.
// Returns 0 on success, non-zero on error.
int32_t nava_bitnet_set_adapter(nava_bitnet_model *model,
                                nava_bitnet_adapter *adapter,
                                float scale);

// Remove all applied adapters, reverting to the base model for subsequent
// completions. Does not free the adapter handle.
void nava_bitnet_clear_adapters(nava_bitnet_model *model);

// Free an adapter handle (clear it first if applied).
void nava_bitnet_adapter_free(nava_bitnet_adapter *adapter);

// ---------------------------------------------------------------------------
// Embeddings (for the Harrier embedding model).
//
// Load a model with `params.embeddings = true`, then call this to get a pooled
// sentence embedding for `text`. Writes up to `out_capacity` floats into `out`
// and returns the embedding dimension, or -1 on error (err filled).
// ---------------------------------------------------------------------------
int32_t nava_bitnet_embed(nava_bitnet_model *model,
                          const char *text,
                          float *out, int32_t out_capacity,
                          char *err, int err_len);

#ifdef __cplusplus
}
#endif

#endif // NAVA_BITNET_H

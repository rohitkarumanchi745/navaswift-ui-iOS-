// nava_bitnet.cpp — thin wrapper over llama.cpp as vendored by bitnet.cpp.
//
// VERSION NOTE: llama.cpp's C API drifts. This file targets the modern API
// (late-2024/2025 era) that current bitnet.cpp ships: the sampler-chain API
// (`llama_sampler_*`), `llama_model_load_from_file`, `llama_init_from_model`,
// and the `llama_vocab`-based tokenizer calls. If you bump the vendored engine
// and the build fails, the symbols to reconcile are marked `// API:` below.

#include "nava_bitnet.h"
#include "llama.h"

#include <algorithm>
#include <cstdio>
#include <cstring>
#include <string>
#include <thread>
#include <vector>

struct nava_bitnet_model {
    llama_model       *model  = nullptr;
    const llama_vocab *vocab  = nullptr;
    llama_context     *ctx    = nullptr;
    int32_t            threads = 0;
};

struct nava_bitnet_adapter {
    llama_adapter_lora *lora = nullptr;
};

static void set_err(char *err, int err_len, const char *msg) {
    if (err && err_len > 0) {
        std::snprintf(err, (size_t) err_len, "%s", msg);
    }
}

nava_bitnet_params nava_bitnet_default_params(void) {
    nava_bitnet_params p;
    p.n_ctx        = 0;
    p.n_threads    = 0;
    p.n_gpu_layers = 0;    // BitNet is CPU-first; leave Metal off by default
    p.use_mmap     = true;
    p.embeddings   = false;
    p.pooling      = 0;    // mean
    return p;
}

static llama_pooling_type nava_pooling(int32_t p) {
    switch (p) {
        case 1:  return LLAMA_POOLING_TYPE_CLS;
        case 2:  return LLAMA_POOLING_TYPE_LAST;
        default: return LLAMA_POOLING_TYPE_MEAN;
    }
}

nava_bitnet_sampling nava_bitnet_default_sampling(void) {
    nava_bitnet_sampling s;
    s.max_tokens     = 96;   // enough for a few short suggestions
    s.temperature    = 0.7f;
    s.top_p          = 0.9f;
    s.top_k          = 40;
    s.repeat_penalty = 1.1f;
    s.seed           = 0;
    s.stop           = nullptr;
    return s;
}

void nava_bitnet_backend_init(void) { llama_backend_init(); }
void nava_bitnet_backend_free(void) { llama_backend_free(); }

nava_bitnet_model *nava_bitnet_load(const char *model_path,
                                    nava_bitnet_params params,
                                    char *err, int err_len) {
    if (!model_path) { set_err(err, err_len, "model_path is null"); return nullptr; }

    llama_model_params mparams = llama_model_default_params();
    mparams.n_gpu_layers = params.n_gpu_layers;
    mparams.use_mmap     = params.use_mmap;

    // API: older builds call this `llama_load_model_from_file`.
    llama_model *model = llama_model_load_from_file(model_path, mparams);
    if (!model) { set_err(err, err_len, "failed to load model file"); return nullptr; }

    const int32_t threads = params.n_threads > 0
        ? params.n_threads
        : (int32_t) std::max(1u, std::thread::hardware_concurrency());

    llama_context_params cparams = llama_context_default_params();
    cparams.n_ctx         = params.n_ctx > 0 ? params.n_ctx : 2048;
    cparams.n_threads     = threads;
    cparams.n_threads_batch = threads;
    if (params.embeddings) {
        cparams.embeddings   = true;
        cparams.pooling_type = nava_pooling(params.pooling);
    }

    // API: older builds call this `llama_new_context_with_model`.
    llama_context *ctx = llama_init_from_model(model, cparams);
    if (!ctx) {
        llama_model_free(model);
        set_err(err, err_len, "failed to create inference context");
        return nullptr;
    }

    auto *handle    = new nava_bitnet_model();
    handle->model   = model;
    handle->vocab   = llama_model_get_vocab(model);
    handle->ctx     = ctx;
    handle->threads = threads;
    return handle;
}

void nava_bitnet_free(nava_bitnet_model *m) {
    if (!m) return;
    if (m->ctx)   llama_free(m->ctx);
    if (m->model) llama_model_free(m->model);
    delete m;
}

// --- Per-user LoRA adapters -------------------------------------------------

nava_bitnet_adapter *nava_bitnet_adapter_load(nava_bitnet_model *m,
                                              const char *adapter_path,
                                              char *err, int err_len) {
    if (!m || !m->model) { set_err(err, err_len, "invalid model handle"); return nullptr; }
    if (!adapter_path)   { set_err(err, err_len, "adapter_path is null"); return nullptr; }

    // API: older builds call this `llama_lora_adapter_init`.
    llama_adapter_lora *lora = llama_adapter_lora_init(m->model, adapter_path);
    if (!lora) { set_err(err, err_len, "failed to load LoRA adapter"); return nullptr; }

    auto *handle = new nava_bitnet_adapter();
    handle->lora = lora;
    return handle;
}

int32_t nava_bitnet_set_adapter(nava_bitnet_model *m,
                                nava_bitnet_adapter *adapter,
                                float scale) {
    if (!m || !m->ctx) return -1;
    // Start from a clean slate so adapters don't stack unintentionally.
    // API: older builds call these `llama_lora_adapter_clear` / `_set`.
    llama_clear_adapter_lora(m->ctx);
    if (!adapter || !adapter->lora) return 0; // clearing only
    return llama_set_adapter_lora(m->ctx, adapter->lora, scale);
}

void nava_bitnet_clear_adapters(nava_bitnet_model *m) {
    if (!m || !m->ctx) return;
    llama_clear_adapter_lora(m->ctx);
}

void nava_bitnet_adapter_free(nava_bitnet_adapter *adapter) {
    if (!adapter) return;
    // API: older builds call this `llama_lora_adapter_free`.
    if (adapter->lora) llama_adapter_lora_free(adapter->lora);
    delete adapter;
}

// --- Embeddings -------------------------------------------------------------

int32_t nava_bitnet_embed(nava_bitnet_model *m,
                          const char *text,
                          float *out, int32_t out_capacity,
                          char *err, int err_len) {
    if (!m || !m->ctx || !m->vocab) { set_err(err, err_len, "invalid model handle"); return -1; }
    if (!text || !out)              { set_err(err, err_len, "null text/out");        return -1; }

    const llama_vocab *vocab = m->vocab;
    const int32_t text_len = (int32_t) std::strlen(text);

    const int32_t n_tok = -llama_tokenize(vocab, text, text_len, nullptr, 0, true, true);
    if (n_tok <= 0) { set_err(err, err_len, "tokenization produced no tokens"); return -1; }
    std::vector<llama_token> tokens((size_t) n_tok);
    if (llama_tokenize(vocab, text, text_len, tokens.data(), n_tok, true, true) < 0) {
        set_err(err, err_len, "tokenization failed");
        return -1;
    }

    llama_kv_self_clear(m->ctx);
    llama_batch batch = llama_batch_get_one(tokens.data(), (int32_t) tokens.size());
    // API: encoder-style embedding models use `llama_encode`; decoder-style use
    // `llama_decode`. `llama_decode` works for both with pooling enabled.
    if (llama_decode(m->ctx, batch) != 0) {
        set_err(err, err_len, "failed to encode text");
        return -1;
    }

    // Pooled sequence embedding (pooling_type was set at context creation).
    const float *emb = llama_get_embeddings_seq(m->ctx, 0);
    if (!emb) {
        set_err(err, err_len, "no embeddings produced (is this an embedding model?)");
        return -1;
    }

    // API: older builds call this `llama_n_embd(model)`.
    const int32_t dim = llama_model_n_embd(m->model);
    const int32_t n = dim < out_capacity ? dim : out_capacity;
    std::memcpy(out, emb, (size_t) n * sizeof(float));
    return dim;
}

int32_t nava_bitnet_complete(nava_bitnet_model *m,
                             const char *prompt,
                             nava_bitnet_sampling s,
                             nava_bitnet_token_cb cb,
                             void *user_data,
                             char *err, int err_len) {
    if (!m || !m->ctx || !m->vocab) { set_err(err, err_len, "invalid model handle"); return -1; }
    if (!prompt) { set_err(err, err_len, "prompt is null"); return -1; }

    const llama_vocab *vocab = m->vocab;
    const int32_t prompt_len = (int32_t) std::strlen(prompt);

    // Tokenize (add BOS, parse special tokens so chat templates work).
    const int32_t n_tok = -llama_tokenize(vocab, prompt, prompt_len, nullptr, 0, true, true);
    if (n_tok <= 0) { set_err(err, err_len, "tokenization produced no tokens"); return -1; }
    std::vector<llama_token> tokens((size_t) n_tok);
    if (llama_tokenize(vocab, prompt, prompt_len, tokens.data(), n_tok, true, true) < 0) {
        set_err(err, err_len, "tokenization failed");
        return -1;
    }

    // Fresh KV cache so each suggestion request is independent.
    // API: older builds call this `llama_kv_cache_clear`.
    llama_kv_self_clear(m->ctx);

    // Decode the prompt in one batch.
    llama_batch batch = llama_batch_get_one(tokens.data(), (int32_t) tokens.size());
    if (llama_decode(m->ctx, batch) != 0) {
        set_err(err, err_len, "failed to decode prompt");
        return -1;
    }

    // Build the sampler chain: penalties -> top_k -> top_p -> temp -> dist.
    llama_sampler *smpl = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(smpl, llama_sampler_init_penalties(64, s.repeat_penalty, 0.0f, 0.0f));
    if (s.top_k > 0)  llama_sampler_chain_add(smpl, llama_sampler_init_top_k(s.top_k));
    if (s.top_p < 1.0f) llama_sampler_chain_add(smpl, llama_sampler_init_top_p(s.top_p, 1));
    llama_sampler_chain_add(smpl, llama_sampler_init_temp(s.temperature));
    llama_sampler_chain_add(smpl,
        llama_sampler_init_dist(s.seed == 0 ? LLAMA_DEFAULT_SEED : s.seed));

    std::string generated;
    int32_t n_generated = 0;

    for (int32_t i = 0; i < s.max_tokens; i++) {
        const llama_token id = llama_sampler_sample(smpl, m->ctx, -1);

        // API: older builds call this `llama_token_is_eog`.
        if (llama_vocab_is_eog(vocab, id)) break;

        char piece[256];
        const int32_t n = llama_token_to_piece(vocab, id, piece, sizeof(piece), 0, true);
        if (n < 0) break;
        const std::string tok(piece, (size_t) n);
        generated += tok;
        n_generated++;

        // Stop-string check on the accumulated text.
        bool hit_stop = false;
        if (s.stop) {
            for (int k = 0; s.stop[k] != nullptr; k++) {
                if (!*s.stop[k]) continue;
                if (generated.find(s.stop[k]) != std::string::npos) { hit_stop = true; break; }
            }
        }

        const bool keep_going = cb ? cb(tok.c_str(), user_data) : true;
        if (hit_stop || !keep_going) break;

        // Feed the sampled token back in for the next step.
        llama_sampler_accept(smpl, id);
        llama_batch next = llama_batch_get_one(const_cast<llama_token *>(&id), 1);
        if (llama_decode(m->ctx, next) != 0) break;
    }

    llama_sampler_free(smpl);
    return n_generated;
}

/* SPDX-License-Identifier: MIT */
/* Build with ASan/UBSan/LSan on Linux. Exercises ownership across SSL_CTX_free,
 * partial construction, failed key decryption and repeated independent objects. */
#include "../glue.c"
#include <assert.h>

int main(int argc, char **argv) {
    assert(argc == 2);
    char ca[4096], cert[4096], key[4096];
    assert(snprintf(ca, sizeof(ca), "%s/ca.pem", argv[1]) < (int)sizeof(ca));
    assert(snprintf(cert, sizeof(cert), "%s/server.pem", argv[1]) < (int)sizeof(cert));
    assert(snprintf(key, sizeof(key), "%s/encrypted.key", argv[1]) < (int)sizeof(key));
    for (int i = 0; i < 100; ++i) {
        tls_context *ctx = bmx_tls_context_new(0, ca, "", "", "", "", 0);
        assert(bmx_tls_context_valid(ctx));
        tls_connection *a = bmx_tls_new(ctx, -1, 0, "localhost");
        tls_connection *b = bmx_tls_new(ctx, -1, 0, "127.0.0.1");
        assert(bmx_tls_valid(a) && bmx_tls_valid(b));
        bmx_tls_context_free(ctx);
        assert(bmx_tls_handshake(a) == -1); /* invalid OS socket, clean fatal path */
        bmx_tls_free(a);
        bmx_tls_free(b);
        ctx = bmx_tls_context_new(1, "", "", cert, key, "wrong", 0);
        assert(ctx && !bmx_tls_context_valid(ctx));
        bmx_tls_context_free(ctx);
        ctx = bmx_tls_context_new(1, "", "", cert, key, "correct password", 0);
        assert(bmx_tls_context_valid(ctx));
        bmx_tls_context_free(ctx);
    }
    puts("Native lifecycle sanitizer checks passed");
    return 0;
}

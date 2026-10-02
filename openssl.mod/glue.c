/* SPDX-License-Identifier: MIT
 * OpenSSL owns TLS; BRL.Socket owns the full-width native socket handle.
 */
#ifdef BMX_TLS_UNSUPPORTED_TRANSPORT
#error Net.OpenSSL requires native TCP sockets and an OS-backed OpenSSL 3 port; browser and bare-metal transports need a separate backend
#endif
#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
typedef SOCKET tls_socket;
#else
#include <sys/socket.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <poll.h>
#include <fcntl.h>
#include <unistd.h>
#include <time.h>
#include <errno.h>
typedef int tls_socket;
#endif
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <limits.h>
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/x509v3.h>
#if OPENSSL_VERSION_MAJOR < 3
#error Net.OpenSSL requires OpenSSL 3 or later
#endif

typedef struct { SSL_CTX *ssl; char error[1024]; } tls_context;
typedef struct {
    SSL *ssl;
    BIO_METHOD *method;
    tls_socket socket;
    int socket_error;
    char error[1024];
} tls_connection;

static int socket_error(void) {
#ifdef _WIN32
    return WSAGetLastError();
#else
    return errno;
#endif
}
static int retry_error(int e) {
#ifdef _WIN32
    return e == WSAEWOULDBLOCK || e == WSAEINTR || e == WSAEINPROGRESS;
#else
    return e == EAGAIN || e == EWOULDBLOCK || e == EINTR || e == EINPROGRESS;
#endif
}
static void error_text(char *out, const char *operation) {
    unsigned long code = ERR_get_error();
    char detail[256] = "OpenSSL operation failed";
    if (code) ERR_error_string_n(code, detail, sizeof(detail));
    snprintf(out, 1024, "%s: %s", operation, detail);
    while (ERR_get_error()) { }
}

const char *bmx_tls_version(void) { return OpenSSL_version(OPENSSL_VERSION); }
int64_t bmx_tls_now(void) {
#ifdef _WIN32
    return (int64_t)GetTickCount64();
#else
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (int64_t)t.tv_sec * 1000 + t.tv_nsec / 1000000;
#endif
}
int bmx_tls_nonblock(int64_t fd) {
    tls_socket s = (tls_socket)fd;
    int type = 0;
#ifdef _WIN32
    int type_size = sizeof(type);
    if (getsockopt(s, SOL_SOCKET, SO_TYPE, (char *)&type, &type_size)) return socket_error();
    if (type != SOCK_STREAM) return WSAEPROTOTYPE;
    u_long enabled = 1;
    if (ioctlsocket(s, FIONBIO, &enabled)) return socket_error();
#else
    socklen_t type_size = sizeof(type);
    if (getsockopt(s, SOL_SOCKET, SO_TYPE, &type, &type_size)) return errno;
    if (type != SOCK_STREAM) return EPROTOTYPE;
    int flags = fcntl(s, F_GETFL, 0);
    if (flags < 0 || fcntl(s, F_SETFL, flags | O_NONBLOCK) < 0) return errno;
#ifdef SO_NOSIGPIPE
    int enabled = 1;
    if (setsockopt(s, SOL_SOCKET, SO_NOSIGPIPE, &enabled, sizeof(enabled))) return errno;
#endif
#endif
    return 0;
}
/* 1 = ready (including hangup, to be diagnosed by TLS), 0 = deadline,
 * negative = OS error. No fd_set or narrowing of Windows SOCKET. */
int bmx_tls_wait(int64_t fd, int writing, int64_t deadline) {
    for (;;) {
        int64_t left = deadline - bmx_tls_now();
        int timeout = left <= 0 ? 0 : left > INT_MAX ? INT_MAX : (int)left;
#ifdef _WIN32
        WSAPOLLFD p = { (SOCKET)fd, writing ? POLLWRNORM : POLLRDNORM, 0 };
        int result = WSAPoll(&p, 1, timeout);
#else
        struct pollfd p = { (int)fd, writing ? POLLOUT : POLLIN, 0 };
        int result = poll(&p, 1, timeout);
#endif
        if (result > 0) return 1;
        if (result == 0) return 0;
        int e = socket_error();
#ifdef _WIN32
        if (e != WSAEINTR) return -e;
#else
        if (e != EINTR) return -e;
#endif
        if (bmx_tls_now() >= deadline) return 0;
    }
}
/* Returns zero on success; timeout is -1; otherwise an OS error. */
int bmx_tls_connect(int64_t fd, struct addrinfo *info, int64_t deadline) {
    tls_socket s = (tls_socket)fd;
    int e = bmx_tls_nonblock(fd);
    if (e) return e;
    if (connect(s, info->ai_addr, (int)info->ai_addrlen) == 0) return 0;
    e = socket_error();
    if (!retry_error(e)) return e;
    int ready = bmx_tls_wait(fd, 1, deadline);
    if (!ready) return -1;
    if (ready < 0) return -ready;
#ifdef _WIN32
    int len = sizeof(e);
    if (getsockopt(s, SOL_SOCKET, SO_ERROR, (char *)&e, &len)) return socket_error();
#else
    socklen_t len = sizeof(e);
    if (getsockopt(s, SOL_SOCKET, SO_ERROR, &e, &len)) return socket_error();
#endif
    return e;
}

static int password_cb(char *buf, int size, int writing, void *data) {
    const char *password = (const char *)data;
    size_t n = password ? strlen(password) : 0;
    (void)writing;
    if (size <= 0 || n >= (size_t)size) return 0;
    if (n) memcpy(buf, password, n);
    buf[n] = 0;
    return (int)n;
}
tls_context *bmx_tls_context_new(int server, const char *ca, const char *ca_path,
        const char *cert, const char *key, const char *password, int require_client) {
    tls_context *c = calloc(1, sizeof(*c));
    if (!c) return NULL;
    ERR_clear_error();
    c->ssl = SSL_CTX_new(server ? TLS_server_method() : TLS_client_method());
    if (!c->ssl) goto fail;
    if (SSL_CTX_get_min_proto_version(c->ssl) < TLS1_2_VERSION &&
        !SSL_CTX_set_min_proto_version(c->ssl, TLS1_2_VERSION)) goto fail;
    SSL_CTX_set_options(c->ssl, SSL_OP_NO_COMPRESSION | SSL_OP_NO_RENEGOTIATION);
    /* Keep truncation detection and modern handshakes mandatory even when an
     * application's OpenSSL configuration enables compatibility exceptions. */
    SSL_CTX_clear_options(c->ssl, SSL_OP_IGNORE_UNEXPECTED_EOF |
                         SSL_OP_ALLOW_UNSAFE_LEGACY_RENEGOTIATION | SSL_OP_LEGACY_SERVER_CONNECT);
    if (SSL_CTX_get_security_level(c->ssl) < 2) SSL_CTX_set_security_level(c->ssl, 2);
    if (!server || require_client || *ca || *ca_path) {
        SSL_CTX_set_verify(c->ssl, SSL_VERIFY_PEER |
                ((server && require_client) ? SSL_VERIFY_FAIL_IF_NO_PEER_CERT : 0), NULL);
        if (*ca || *ca_path) {
            if (!SSL_CTX_load_verify_locations(c->ssl, *ca ? ca : NULL,
                                               *ca_path ? ca_path : NULL)) goto fail;
        } else if (!SSL_CTX_set_default_verify_paths(c->ssl)) goto fail;
    }
    if (server || *cert || *key) {
        if (!*cert || !*key) {
            snprintf(c->error, sizeof(c->error), "Both certificate chain and private key are required");
            goto invalid;
        }
        SSL_CTX_set_default_passwd_cb(c->ssl, password_cb);
        SSL_CTX_set_default_passwd_cb_userdata(c->ssl, (void *)password);
        int ok = SSL_CTX_use_certificate_chain_file(c->ssl, cert) == 1 &&
                 SSL_CTX_use_PrivateKey_file(c->ssl, key, SSL_FILETYPE_PEM) == 1 &&
                 SSL_CTX_check_private_key(c->ssl) == 1;
        /* The callback remains non-interactive but never retains caller memory. */
        SSL_CTX_set_default_passwd_cb_userdata(c->ssl, NULL);
        if (!ok) goto fail;
    }
    return c;
fail:
    error_text(c->error, "TLS context");
invalid:
    SSL_CTX_free(c->ssl);
    c->ssl = NULL;
    return c;
}
int bmx_tls_context_valid(tls_context *c) { return c && c->ssl; }
const char *bmx_tls_context_error(tls_context *c) { return c->error; }
void bmx_tls_context_free(tls_context *c) { if (c) { SSL_CTX_free(c->ssl); free(c); } }
void bmx_tls_wipe(void *data, int64_t length) { if (data && length > 0) OPENSSL_cleanse(data, (size_t)length); }

static int bio_create(BIO *bio) { BIO_set_init(bio, 1); return 1; }
static int bio_destroy(BIO *bio) { if (bio) BIO_set_data(bio, NULL); return 1; }
static int bio_read(BIO *bio, char *buf, int length) {
    tls_connection *c = BIO_get_data(bio);
    BIO_clear_retry_flags(bio);
    int n = (int)recv(c->socket, buf, length, 0);
    if (n < 0) {
        c->socket_error = socket_error();
        if (retry_error(c->socket_error)) BIO_set_retry_read(bio);
    }
    return n;
}
static int bio_write(BIO *bio, const char *buf, int length) {
    tls_connection *c = BIO_get_data(bio);
    BIO_clear_retry_flags(bio);
#ifdef MSG_NOSIGNAL
    int n = (int)send(c->socket, buf, length, MSG_NOSIGNAL);
#else
    int n = (int)send(c->socket, buf, length, 0);
#endif
    if (n < 0) {
        c->socket_error = socket_error();
        if (retry_error(c->socket_error)) BIO_set_retry_write(bio);
    }
    return n;
}
static long bio_ctrl(BIO *bio, int command, long num, void *ptr) {
    (void)bio; (void)num; (void)ptr;
    return command == BIO_CTRL_FLUSH ? 1 : 0;
}
tls_connection *bmx_tls_new(tls_context *context, int64_t fd, int server, const char *hostname) {
    tls_connection *c = calloc(1, sizeof(*c));
    if (!c) return NULL;
    c->socket = (tls_socket)fd;
    ERR_clear_error();
    c->ssl = SSL_new(context->ssl);
    c->method = BIO_meth_new(BIO_TYPE_SOURCE_SINK, "Net.OpenSSL BRL socket");
    if (!c->ssl || !c->method ||
        !BIO_meth_set_create(c->method, bio_create) || !BIO_meth_set_destroy(c->method, bio_destroy) ||
        !BIO_meth_set_read(c->method, bio_read) || !BIO_meth_set_write(c->method, bio_write) ||
        !BIO_meth_set_ctrl(c->method, bio_ctrl)) goto fail;
    BIO *bio = BIO_new(c->method);
    if (!bio) goto fail;
    BIO_set_data(bio, c);
    SSL_set_bio(c->ssl, bio, bio);
    if (server) {
        SSL_set_accept_state(c->ssl);
    } else {
        unsigned char ip[16];
        SSL_set_connect_state(c->ssl);
        X509_VERIFY_PARAM *param = SSL_get0_param(c->ssl);
        X509_VERIFY_PARAM_set_hostflags(param, X509_CHECK_FLAG_NO_PARTIAL_WILDCARDS);
        if (inet_pton(AF_INET, hostname, ip) == 1 || inet_pton(AF_INET6, hostname, ip) == 1) {
            if (!X509_VERIFY_PARAM_set1_ip_asc(param, hostname)) goto fail;
        } else {
            if (!SSL_set1_host(c->ssl, hostname) || !SSL_set_tlsext_host_name(c->ssl, hostname)) goto fail;
        }
    }
    return c;
fail:
    error_text(c->error, "TLS connection");
    SSL_free(c->ssl);
    c->ssl = NULL;
    return c;
}
int bmx_tls_valid(tls_connection *c) { return c && c->ssl; }
const char *bmx_tls_error(tls_connection *c) { return c->error; }
void bmx_tls_free(tls_connection *c) {
    if (c) { SSL_free(c->ssl); BIO_meth_free(c->method); free(c); }
}
/* Must be called immediately after the SSL operation, on this same thread. */
static int tls_result(tls_connection *c, int result, const char *operation) {
    int e = SSL_get_error(c->ssl, result);
    if (e == SSL_ERROR_WANT_READ) return 2;
    if (e == SSL_ERROR_WANT_WRITE) return 3;
    if (e == SSL_ERROR_ZERO_RETURN) return 0;
    error_text(c->error, operation);
    size_t n = strlen(c->error);
    snprintf(c->error + n, sizeof(c->error) - n, " (TLS error %d, certificate status %ld, socket error %d)",
             e, SSL_get_verify_result(c->ssl), c->socket_error);
    return -1;
}
/* >0 bytes; -2/-3 want read/write; 0 authenticated TLS EOF; -1 fatal. */
int bmx_tls_read(tls_connection *c, void *data, int length) {
    ERR_clear_error(); c->socket_error = 0;
    int n = SSL_read(c->ssl, data, length);
    if (n > 0) return n;
    int state = tls_result(c, n, "TLS read");
    return state > 0 ? -state : state;
}
int bmx_tls_write(tls_connection *c, const void *data, int length) {
    ERR_clear_error(); c->socket_error = 0;
    int n = SSL_write(c->ssl, data, length);
    if (n > 0) return n;
    int state = tls_result(c, n, "TLS write");
    return state > 0 ? -state : state;
}
int bmx_tls_handshake(tls_connection *c) {
    ERR_clear_error(); c->socket_error = 0;
    int result = SSL_do_handshake(c->ssl);
    return result == 1 ? 1 : tls_result(c, result, "TLS handshake");
}
int bmx_tls_shutdown(tls_connection *c) {
    ERR_clear_error(); c->socket_error = 0;
    int result = SSL_shutdown(c->ssl);
    if (result == 1) return 1;
    if (result == 0) return 4; /* Our close_notify sent; immediately attempt phase two. */
    return tls_result(c, result, "TLS shutdown");
}
const char *bmx_tls_protocol(tls_connection *c) { return SSL_get_version(c->ssl); }
const char *bmx_tls_cipher(tls_connection *c) { return SSL_get_cipher_name(c->ssl); }

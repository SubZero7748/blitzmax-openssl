# SPDX-License-Identifier: MIT
"""Independent Python ssl peers for the NG module. Loopback only.

Usage: python integration.py /absolute/path/to/driver[.exe] /local/test/output
Requires cryptography for ephemeral test certificates; no keys are distributed.
"""
import contextlib
import datetime as dt
import ipaddress
import json
import os
from pathlib import Path
import queue
import socket
import ssl
import struct
import subprocess
import sys
import threading
import time
import warnings

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID

EXE = str(Path(sys.argv[1]).resolve())
OUT = Path(sys.argv[2]).resolve()
OUT.mkdir(parents=True, exist_ok=True)
FIX = OUT / 'fixtures'
FIX.mkdir(exist_ok=True)
os.chmod(FIX, 0o700)
RESULTS = []


def fixtures():
    now = dt.datetime.now(dt.timezone.utc)

    def key():
        return ec.generate_private_key(ec.SECP256R1())

    def cert(name, public, issuer_name, issuer_key, *, ca=False, client=False, expired=False):
        subject = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, name)])
        builder = (x509.CertificateBuilder().subject_name(subject).issuer_name(issuer_name or subject)
                   .public_key(public).serial_number(x509.random_serial_number())
                   .not_valid_before(now - dt.timedelta(days=3))
                   .not_valid_after(now + dt.timedelta(days=-1 if expired else 2))
                   .add_extension(x509.BasicConstraints(ca=ca, path_length=0 if ca else None), critical=True))
        if not ca:
            alt_names = [x509.DNSName('localhost')]
            if name != 'dns-only':
                alt_names += [x509.IPAddress(ipaddress.ip_address('127.0.0.1')),
                              x509.IPAddress(ipaddress.ip_address('::1'))]
            builder = (builder.add_extension(x509.SubjectAlternativeName([
                *alt_names]), critical=False)
                .add_extension(x509.ExtendedKeyUsage([
                    ExtendedKeyUsageOID.CLIENT_AUTH if client else ExtendedKeyUsageOID.SERVER_AUTH]), critical=False))
        return builder.sign(issuer_key, hashes.SHA256())

    ca_key = key()
    ca = cert('Ephemeral NG TLS test CA', ca_key.public_key(), None, ca_key, ca=True)
    (FIX / 'ca.pem').write_bytes(ca.public_bytes(serialization.Encoding.PEM))
    for name in ('server', 'client', 'expired', 'rogue', 'wrong-purpose', 'dns-only'):
        k = key()
        issuer = ca.subject
        signing = ca_key
        if name == 'rogue':
            issuer = None
            signing = k
        c = cert(name, k.public_key(), issuer, signing,
                 client=name in ('client', 'wrong-purpose'), expired=name == 'expired')
        (FIX / (name + '.pem')).write_bytes(c.public_bytes(serialization.Encoding.PEM))
        private = FIX / (name + '.key')
        private.write_bytes(k.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                            serialization.NoEncryption()))
        os.chmod(private, 0o600)
        if name == 'server':
            private = FIX / 'encrypted.key'
            private.write_bytes(k.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                                serialization.BestAvailableEncryption(b'correct password')))
            os.chmod(private, 0o600)


def read_exact(s, n):
    parts = []
    while n:
        block = s.recv(n)
        if not block:
            raise AssertionError('Premature EOF from NG')
        parts.append(block)
        n -= len(block)
    return b''.join(parts)


def recv_frame(s):
    n, = struct.unpack('!I', read_exact(s, 4))
    assert n <= 16777216, n
    return read_exact(s, n)


def send_frame(s, payload, fragment=False):
    frame = struct.pack('!I', len(payload)) + payload
    if fragment:
        s.sendall(frame[:1])
        s.sendall(frame[1:3])
        for i in range(3, len(frame), 997):
            s.sendall(frame[i:i + 997])
    else:
        s.sendall(frame)


def server_context(cert_name='server', version=None, mtls=False):
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(FIX / (cert_name + '.pem'), FIX / (cert_name + '.key'))
    if version:
        ctx.minimum_version = version
        ctx.maximum_version = version
    if mtls:
        ctx.load_verify_locations(FIX / 'ca.pem')
        ctx.verify_mode = ssl.CERT_REQUIRED
    return ctx


@contextlib.contextmanager
def peer(action, *, cert_name='server', version=None, mtls=False, raw=False, reject=False, sni=None, bind_host='127.0.0.1'):
    listener = socket.socket(socket.AF_INET6 if ':' in bind_host else socket.AF_INET)
    listener.bind((bind_host, 0))
    listener.listen(1)
    listener.settimeout(7)
    port = listener.getsockname()[1]
    errors = []
    ctx = None if raw else server_context(cert_name, version, mtls)
    if ctx and sni is not None:
        ctx.set_servername_callback(lambda conn, name, context: sni.append(name))

    def worker():
        try:
            with listener.accept()[0] as conn:
                conn.settimeout(5)
                conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
                if raw:
                    action(conn)
                else:
                    with ctx.wrap_socket(conn, server_side=True) as secured:
                        action(secured)
        except (ssl.SSLError, ConnectionError) as e:
            if not reject:
                errors.append(repr(e))
        except Exception as e:
            errors.append(repr(e))

    t = threading.Thread(target=worker, daemon=True)
    t.start()
    failed = False
    try:
        yield port
    except BaseException:
        failed = True
        raise
    finally:
        t.join(8)
        listener.close()
        if not failed:
            assert not t.is_alive(), 'Python peer did not terminate'
            assert not errors, errors


def run(args, expected=None, env_override=None):
    env = None
    if env_override:
        env = os.environ.copy()
        env.update(env_override)
    result = subprocess.run([EXE, *map(str, args)], text=True, capture_output=True, timeout=12, env=env)
    output = result.stdout + result.stderr
    if expected is None:
        assert result.returncode == 0 and 'PASS' in output and 'ERROR' not in output, output
    else:
        assert result.returncode != 0 and 'ERROR' in output and expected.lower() in output.lower(), output
    return output.strip()


def check(name, action):
    if os.environ.get('NET_OPENSSL_TEST_FILTER', '') not in name:
        return
    started = time.monotonic()
    try:
        details = action()
        RESULTS.append(dict(name=name, passed=True, seconds=round(time.monotonic() - started, 3), detail=details))
        print('PASS', name, flush=True)
    except Exception as e:
        RESULTS.append(dict(name=name, passed=False, seconds=round(time.monotonic() - started, 3), detail=repr(e)))
        print('FAIL', name, repr(e), flush=True)


def echo(s):
    for _ in range(8):
        send_frame(s, recv_frame(s), fragment=True)
        send_frame(s, recv_frame(s), fragment=True)
    assert recv_frame(s) == b''
    send_frame(s, b'')
    s.unwrap().close()


def client_case(scenario, action, expected=None, host='127.0.0.1', env_override=None, **kwargs):
    with peer(action, **kwargs) as port:
        return run(['client', FIX, host, port, scenario], expected, env_override)


def ng_server_case(scenario, *, mtls=False, reject=False):
    process = subprocess.Popen([EXE, 'server', str(FIX), scenario], stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, bufsize=1)
    lines = []
    ports = queue.Queue()

    def collect():
        for line in process.stdout:
            lines.append(line)
            if line.startswith('PORT '):
                ports.put(int(line.split()[1]))
    reader = threading.Thread(target=collect, daemon=True)
    reader.start()
    clients = []
    try:
        port = ports.get(timeout=6)
        if scenario != 'accept-timeout':
            ctx = ssl.create_default_context(cafile=str(FIX / 'ca.pem'))
            if scenario == 'tls11':
                with warnings.catch_warnings():
                    warnings.simplefilter('ignore', DeprecationWarning)
                    ctx.minimum_version = ssl.TLSVersion.TLSv1_1
                    ctx.maximum_version = ssl.TLSVersion.TLSv1_1
                ctx.set_ciphers('DEFAULT:@SECLEVEL=0')
            if mtls:
                ctx.load_cert_chain(FIX / 'client.pem', FIX / 'client.key')
            try:
                for _ in range(2 if scenario == 'two' else 1):
                    s = ctx.wrap_socket(socket.create_connection(('127.0.0.1', port), timeout=4),
                                        server_hostname='localhost')
                    clients.append(s)
                for i, s in enumerate(clients):
                    payload = bytes(range(256)) * (700 + i)
                    send_frame(s, payload, fragment=True)
                    assert recv_frame(s) == payload
                    text = 'Python æΩ\0 UTF-8'.encode()
                    send_frame(s, text, fragment=True)
                    assert recv_frame(s) == text
                    s.unwrap().close()
            except (ssl.SSLError, ConnectionError):
                if not reject:
                    raise
        process.wait(timeout=8)
        reader.join(1)
        output = ''.join(lines)
        if reject:
            assert process.returncode != 0 and 'ERROR' in output, output
        else:
            assert process.returncode == 0 and 'PASS' in output, output
        return output.strip()
    finally:
        for s in clients:
            s.close()
        if process.poll() is None:
            process.kill()
            process.wait()


fixtures()
for name, error in [('missing', 'TLS context'), ('mismatch', 'TLS context'),
                    ('password', None), ('bad-password', 'TLS context'), ('nul', 'NUL')]:
    check('context-' + name, lambda name=name, error=error: run(['config', FIX, name], error))

for version in (ssl.TLSVersion.TLSv1_2, ssl.TLSVersion.TLSv1_3):
    check('client-binary-utf8-fragmented-' + version.name,
          lambda version=version: client_case('echo', echo, version=version))

def dns_sni():
    names = []
    result = client_case('echo', echo, host='localhost', sni=names)
    assert names == ['localhost'], names
    return result

check('DNS-identity-and-SNI', dns_sni)
def upgrade(conn):
    assert read_exact(conn, 10) == b'STARTTLS\r\n'
    conn.sendall(b'READY\r\n')
    with server_context().wrap_socket(conn, server_side=True) as secured:
        echo(secured)

check('STARTTLS-attach', lambda: client_case('attach', upgrade, host='localhost', raw=True))
check('IPv6-numeric-identity', lambda: client_case('echo', echo, host='::1', bind_host='::1'))
check('reject-IP-without-IP-SAN', lambda: client_case('echo', lambda s: None,
      'certificate verify failed', cert_name='dns-only', reject=True))
for name in ('rogue', 'expired', 'wrong-purpose'):
    check('reject-' + name, lambda name=name: client_case('echo', lambda s: None,
          'certificate verify failed', cert_name=name, reject=True))
check('reject-wrong-host', lambda: client_case('wrong-host', lambda s: None,
      'certificate verify failed', host='wrong.invalid', reject=True))
check('client-mutual-TLS', lambda: client_case('mtls', echo, mtls=True))
check('reject-missing-client-identity', lambda: client_case('echo', lambda s: None,
      'TLS', mtls=True, reject=True))
check('handshake-timeout', lambda: client_case('echo', lambda s: time.sleep(1.5), 'timeout', raw=True))
check('read-timeout', lambda: client_case('read-timeout', lambda s: time.sleep(1.2), 'timeout'))
check('write-timeout', lambda: client_case('write-timeout', lambda s: time.sleep(1.2), 'timeout'))
check('oversized-frame', lambda: client_case('oversize', lambda s: s.sendall(b'\xff\xff\xff\xff'), 'exceeds'))
check('truncated-frame', lambda: client_case('truncated', lambda s: s.sendall(b'\0\0\0\x10abc'), 'TLS read'))
check('authenticated-close-notify', lambda: client_case('clean-eof', lambda s: s.unwrap().close()))
check('reject-abrupt-TCP-EOF', lambda: client_case('abrupt-eof', lambda s: None, 'TLS read'))
policy = FIX / 'unsafe-eof-policy.cnf'
policy.write_text('openssl_conf = init\n[init]\nssl_conf = ssl\n[ssl]\nsystem_default = defaults\n'
                  '[defaults]\nOptions = IgnoreUnexpectedEOF\n', encoding='ascii')
check('reject-abrupt-EOF-despite-system-override', lambda: client_case('abrupt-eof', lambda s: None,
      'TLS read', env_override={'OPENSSL_CONF': str(policy)}))
check('NG-server-independent-connections-context-lifetime', lambda: ng_server_case('two'))
check('NG-server-mutual-TLS', lambda: ng_server_case('mtls', mtls=True))
check('NG-server-reject-missing-client-cert', lambda: ng_server_case('mtls', reject=True))
check('NG-server-reject-TLS-1.1', lambda: ng_server_case('tls11', reject=True))
check('NG-listener-accept-timeout', lambda: ng_server_case('accept-timeout'))

(OUT / 'results.json').write_text(json.dumps(dict(executable=EXE, python_ssl=ssl.OPENSSL_VERSION,
    tests=RESULTS), indent=2), encoding='utf-8')
failed = sum(not row['passed'] for row in RESULTS)
print(f'{len(RESULTS) - failed}/{len(RESULTS)} passed; results: {OUT / "results.json"}', flush=True)
sys.exit(bool(failed))

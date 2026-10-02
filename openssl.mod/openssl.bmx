'
'  Copyright (C) 2026 Kay Arnesen and Liz
'
'  SPDX-License-Identifier: MIT
'
'  Permission is hereby granted, free of charge, to any person obtaining a copy
'  of this software and associated documentation files (the "Software"), to deal
'  in the Software without restriction, including without limitation the rights
'  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
'  copies of the Software, and to permit persons to whom the Software is
'  furnished to do so, subject to the following conditions:
'
'  The above copyright notice and this permission notice shall be included in all
'  copies or substantial portions of the Software.
'
'  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
'  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
'  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
'  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
'  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
'  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
'  SOFTWARE.
'
SuperStrict

Rem
bbdoc: TLS client and server byte streams backed by OpenSSL 3.
about: Uses BRL sockets and streams. Clients always verify the certificate chain
and peer identity. TLS 1.2 is the minimum protocol version. See README.md.
End Rem
Module Net.OpenSSL

ModuleInfo "Version: 0.1.3"
ModuleInfo "License: MIT"
' BEGIN GENERATED PLATFORM OPTIONS
?win32 And x64
ModuleInfo "CC_OPTS: -I%PWD%/deps/win32.x64/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/win32.x64/lib"
?win32 And x86
ModuleInfo "CC_OPTS: -I%PWD%/deps/win32.x86/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/win32.x86/lib"
?win32 And (arm64 Or armv64)
ModuleInfo "CC_OPTS: -I%PWD%/deps/win32.arm64/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/win32.arm64/lib"
?win32 And armv7
ModuleInfo "CC_OPTS: -I%PWD%/deps/win32.armv7/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/win32.armv7/lib"
?(linux And Not (raspberrypi Or android) And x64) And openssl_local
ModuleInfo "CC_OPTS: -I%PWD%/deps/linux.x64/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/linux.x64/lib"
?(linux And Not (raspberrypi Or android) And x86) And openssl_local
ModuleInfo "CC_OPTS: -I%PWD%/deps/linux.x86/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/linux.x86/lib"
?(linux And Not (raspberrypi Or android) And (arm Or armv7)) And openssl_local
ModuleInfo "CC_OPTS: -I%PWD%/deps/linux.arm/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/linux.arm/lib"
?(linux And Not (raspberrypi Or android) And arm64) And openssl_local
ModuleInfo "CC_OPTS: -I%PWD%/deps/linux.arm64/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/linux.arm64/lib"
?(linux And Not android And riscv32) And openssl_local
ModuleInfo "CC_OPTS: -I%PWD%/deps/linux.riscv32/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/linux.riscv32/lib"
?(linux And Not android And riscv64) And openssl_local
ModuleInfo "CC_OPTS: -I%PWD%/deps/linux.riscv64/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/linux.riscv64/lib"
?(raspberrypi And (arm Or armv7)) And openssl_local
ModuleInfo "CC_OPTS: -I%PWD%/deps/raspberrypi.arm/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/raspberrypi.arm/lib"
?(raspberrypi And arm64) And openssl_local
ModuleInfo "CC_OPTS: -I%PWD%/deps/raspberrypi.arm64/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/raspberrypi.arm64/lib"
?(macos And Not ios And x64) And openssl_local
ModuleInfo "CC_OPTS: -I%PWD%/deps/macos.x64/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/macos.x64/lib"
?(macos And Not ios And arm64) And openssl_local
ModuleInfo "CC_OPTS: -I%PWD%/deps/macos.arm64/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/macos.arm64/lib"
?(haiku And x86) And openssl_local
ModuleInfo "CC_OPTS: -I%PWD%/deps/haiku.x86/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/haiku.x86/lib"
?(haiku And x64) And openssl_local
ModuleInfo "CC_OPTS: -I%PWD%/deps/haiku.x64/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/haiku.x64/lib"
?android And (arm Or armv7 Or armeabi Or armeabiv7a) And Not arm64v8a
ModuleInfo "CC_OPTS: -I%PWD%/deps/android.armv7/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/android.armv7/lib"
?android And (arm64 Or arm64v8a)
ModuleInfo "CC_OPTS: -I%PWD%/deps/android.arm64/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/android.arm64/lib"
?android And x86
ModuleInfo "CC_OPTS: -I%PWD%/deps/android.x86/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/android.x86/lib"
?android And x64
ModuleInfo "CC_OPTS: -I%PWD%/deps/android.x64/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/android.x64/lib"
?android And riscv64
ModuleInfo "CC_OPTS: -I%PWD%/deps/android.riscv64/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/android.riscv64/lib"
?ios And armv7
ModuleInfo "CC_OPTS: -I%PWD%/deps/ios.armv7/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/ios.armv7/lib"
?ios And arm64 And Not openssl_ios_simulator
ModuleInfo "CC_OPTS: -I%PWD%/deps/ios.arm64/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/ios.arm64/lib"
?ios And x86
ModuleInfo "CC_OPTS: -I%PWD%/deps/ios.simulator.x86/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/ios.simulator.x86/lib"
?ios And x64
ModuleInfo "CC_OPTS: -I%PWD%/deps/ios.simulator.x64/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/ios.simulator.x64/lib"
?ios And arm64 And openssl_ios_simulator
ModuleInfo "CC_OPTS: -I%PWD%/deps/ios.simulator.arm64/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/ios.simulator.arm64/lib"
?nx
ModuleInfo "CC_OPTS: -I%PWD%/deps/nx.arm64/include"
ModuleInfo "LD_OPTS: -L%PWD%/deps/nx.arm64/lib"
?((macos And Not ios) Or haiku) And Not openssl_local
ModuleInfo "CC_OPTS: `pkg-config --cflags openssl`"
ModuleInfo "LD_OPTS: `pkg-config --libs-only-L openssl`"
?emscripten Or embedded
ModuleInfo "CC_OPTS: -DBMX_TLS_UNSUPPORTED_TRANSPORT"
?
' END GENERATED PLATFORM OPTIONS
Import BRL.Socket
Import BRL.Stream
Import "glue.c"
?win32
Import "-l:libssl.dll.a"
Import "-l:libcrypto.dll.a"
?Not win32
Import "-lssl"
Import "-lcrypto"
?

Rem
bbdoc: A TLS, transport, certificate or deadline failure.
about: Fatal connection errors close that stream. Argument errors do not.
End Rem
Type TOpenSSLException Extends TStreamException

	Field message:String

	Method New(message:String)
		Self.message = message
	End Method

	Method ToString:String() Override
		Return message
	End Method
End Type

Rem
bbdoc: Immutable TLS configuration. Connections hold their own OpenSSL references.
about: Explicitly close contexts when finished creating connections. Closing a
context does not close existing streams. Do not close a context concurrently
with another operation using it. No instance supports concurrent mutation.
End Rem
Type TOpenSSLContext Implements ICloseable

	Rem
	bbdoc: Creates a verified client configuration, optionally with a client identity.
	about: Empty CA arguments select OpenSSL's default trust locations. Windows
	system certificates are not imported automatically. Supply a PEM CA bundle.
	End Rem
	Function CreateClient:TOpenSSLContext(caFile:String = "", caPath:String = "", certFile:String = "", keyFile:String = "", password:String = "")
		Return _Create(False, caFile, caPath, certFile, keyFile, password, False)
	End Function

	Rem
	bbdoc: Creates a server configuration with a PEM certificate chain and private key.
	about: Set requireClientCertificate for mutual TLS. If CA locations are supplied
	without that flag, presented client certificates are verified but not mandatory.
	End Rem
	Function CreateServer:TOpenSSLContext(certFile:String, keyFile:String, password:String = "", caFile:String = "", caPath:String = "", requireClientCertificate:Int = False)
		Return _Create(True, caFile, caPath, certFile, keyFile, password, requireClientCertificate)
	End Function

	Method Close() Override
		If _handle Then
			bmx_tls_context_free(_handle)
			_handle = Null
		End If
	End Method

	Method Delete()
		Close()
	End Method

	Internal
	Field _handle:Byte Ptr
	Field _server:Int

	Method _Check()
		If Not _handle Then Throw New TOpenSSLException("TLS context is closed or uninitialized")
	End Method

	Function _Create:TOpenSSLContext(server:Int, ca:String, caPath:String, cert:String, key:String, password:String, requireClient:Int)
		Local values:String[] = [ca, caPath, cert, key, password]
		For Local value:String = EachIn values
			_CheckCString(value)
		Next
		Local p:Byte Ptr[5]
		Local passLength:Size_T
		Try
			For Local i:Int = 0 Until 4
				p[i] = values[i].ToUTF8String()
			Next
			p[4] = password.ToUTF8String(passLength)
			Local ctx:TOpenSSLContext = New TOpenSSLContext
			ctx._server = server
			ctx._handle = bmx_tls_context_new(server, p[0], p[1], p[2], p[3], p[4], requireClient)
			If Not ctx._handle Then Throw New TOpenSSLException("Unable to allocate TLS context")
			If Not bmx_tls_context_valid(ctx._handle) Then
				Local message:String = String.FromUTF8String(bmx_tls_context_error(ctx._handle))
				ctx.Close()
				Throw New TOpenSSLException(message)
			End If
			Return ctx
		Finally
			bmx_tls_wipe(p[4], Long(passLength))
			For Local i:Int = 0 Until 5
				MemFree(p[i])
			Next
		End Try
	End Function
End Type

Rem
bbdoc: An authenticated TLS byte stream for any application protocol.
about: This synchronous API uses nonblocking sockets internally with deadlines.
Read may return fewer bytes; ReadBytes and WriteBytes transfer an exact count.
TLS records are not messages. Use the optional bounded framing helpers only
when both endpoints agree on that application protocol.
End Rem
Type TOpenSSLStream Extends TStream

	Rem
	bbdoc: Connects TCP and completes a verified client handshake.
	about: One deadline covers TCP address attempts and TLS, after synchronous DNS.
	The host is also the verified peer identity (DNS name or numeric IP address).
	End Rem
	Function Connect:TOpenSSLStream(context:TOpenSSLContext, host:String, port:Int, timeoutMillis:Int = 10000)
		If Not context Then IllegalArgumentError "A TLS context is required"
		context._Check()
		If context._server Then IllegalArgumentError "Connect requires a client context"
		_CheckHost(host)
		If port < 1 Or port > 65535 Then IllegalArgumentError "Invalid TCP port"
		_CheckTimeout(timeoutMillis)
		Local addresses:TAddrInfo[] = AddrInfo(host, String(port), New TAddrInfo(AF_UNSPEC_, SOCK_STREAM_))
		Local deadline:Long = bmx_tls_now() + timeoutMillis
		Local lastError:Int
		For Local index:Int = 0 Until addresses.length
			If bmx_tls_now() >= deadline Then Exit
			Local address:TAddrInfo = addresses[index]
			Local socket:TSocket = TSocket.Create(address)
			If Not socket Then Continue
			Local now:Long = bmx_tls_now()
			Local attemptDeadline:Long = now + Max(1:Long, (deadline - now) / (addresses.length - index))
			lastError = bmx_tls_connect(Long(socket.Socket()), address.infoPtr, attemptDeadline)
			If Not lastError Then
				socket.UpdateLocalName()
				socket.UpdateRemoteName()
				Return _Attach(context, socket, host, deadline)
			End If
			socket.Close()
			If bmx_tls_now() >= deadline Then Exit
		Next
		If Not addresses.length Then Throw New TOpenSSLException("DNS resolution returned no TCP addresses for " + host)
		Throw New TOpenSSLException("TCP connect failed (socket error " + lastError + ", -1 means timeout)")
	End Function

	Rem
	bbdoc: Takes ownership of an already connected TCP socket and performs TLS.
	about: Suitable for STARTTLS after the plaintext upgrade has been agreed.
	No plaintext bytes may remain buffered outside the socket. After argument
	validation, the socket is closed on failure and belongs exclusively to this
	stream on success. Clients must supply the expected certificate identity.
	End Rem
	Function Attach:TOpenSSLStream(context:TOpenSSLContext, socket:TSocket, peerName:String = "", timeoutMillis:Int = 10000)
		If Not context Or Not socket Then IllegalArgumentError "A context and socket are required"
		If Not socket._autoClose Then IllegalArgumentError "Attach requires a TSocket that owns its native socket"
		context._Check()
		If Not context._server Then _CheckHost(peerName)
		_CheckTimeout(timeoutMillis)
		Return _Attach(context, socket, peerName, bmx_tls_now() + timeoutMillis)
	End Function

	Rem
	bbdoc: Sets the deadline in milliseconds for each subsequent I/O operation.
	about: Exact byte operations and frames use one deadline for the entire operation.
	End Rem
	Method SetTimeout(timeoutMillis:Int)
		_CheckTimeout(timeoutMillis)
		_timeout = timeoutMillis
	End Method

	Method Read:Long(buffer:Byte Ptr, count:Long) Override
		_CheckBuffer(buffer, count)
		_Check()
		If Not count Or _eof Then Return 0
		Return _Read(buffer, Int(Min(count, 2147483647:Long)), bmx_tls_now() + _timeout)
	End Method

	Method Write:Long(buffer:Byte Ptr, count:Long) Override
		_CheckBuffer(buffer, count)
		_Check()
		If Not count Then Return 0
		Return _Write(buffer, Int(Min(count, 2147483647:Long)), bmx_tls_now() + _timeout)
	End Method

	Method ReadBytes:Long(buffer:Byte Ptr, count:Long) Override
		_CheckBuffer(buffer, count)
		_Check()
		_ReadExact(buffer, count, bmx_tls_now() + _timeout)
		Return count
	End Method

	Method WriteBytes:Long(buffer:Byte Ptr, count:Long) Override
		_CheckBuffer(buffer, count)
		_Check()
		_WriteExact(buffer, count, bmx_tls_now() + _timeout)
		Return count
	End Method

	Rem
	bbdoc: Writes an unsigned 32-bit big-endian length followed by payload bytes.
	about: maxBytes defaults to 16 MiB and is checked before anything is sent.
	End Rem
	Method WriteFrame(data:Byte[], maxBytes:Int = 16777216)
		If maxBytes < 0 Or data.length > maxBytes Then IllegalArgumentError "Frame exceeds configured limit"
		_Check()
		Local header:Byte[4]
		For Local i:Int = 0 Until 4
			header[i] = data.length Shr (24 - i * 8)
		Next
		Local deadline:Long = bmx_tls_now() + _timeout
		_WriteExact(header, 4, deadline)
		_WriteExact(data, data.length, deadline)
	End Method

	Rem
	bbdoc: Reads a frame, checking its length before allocating the payload.
	about: Oversized or truncated frames close the connection and throw.
	End Rem
	Method ReadFrame:Byte[](maxBytes:Int = 16777216)
		If maxBytes < 0 Then IllegalArgumentError "Negative frame limit"
		_Check()
		Local deadline:Long = bmx_tls_now() + _timeout
		Local header:Byte[4]
		_ReadExact(header, 4, deadline)
		Local length:Long
		For Local i:Int = 0 Until 4
			length = (length Shl 8) | Long(header[i])
		Next
		If length > maxBytes Then _Fail("Received frame exceeds configured limit")
		Local data:Byte[] = New Byte[Int(length)]
		_ReadExact(data, length, deadline)
		Return data
	End Method

	Rem
	bbdoc: Sends UTF-8 text as a length-prefixed frame, preserving embedded NULs.
	End Rem
	Method WriteText(value:String, maxBytes:Int = 16777216)
		If maxBytes < 0 Or value.length > maxBytes Then IllegalArgumentError "Text exceeds configured limit"
		Local length:Size_T
		Local p:Byte Ptr = value.ToUTF8String(length)
		Try
			If maxBytes < 0 Or length > Size_T(maxBytes) Then IllegalArgumentError "Text exceeds configured limit"
			Local data:Byte[] = New Byte[Int(length)]
			If length Then MemCopy(data, p, length)
			WriteFrame(data, maxBytes)
		Finally
			MemFree(p)
		End Try
	End Method

	Method ReadText:String(maxBytes:Int = 16777216)
		Local data:Byte[] = ReadFrame(maxBytes)
		Return String.FromUTF8Bytes(data, data.length)
	End Method

	Method Protocol:String()
		_Check()
		Return String.FromCString(bmx_tls_protocol(_handle))
	End Method

	Method Cipher:String()
		_Check()
		Return String.FromCString(bmx_tls_cipher(_handle))
	End Method

	Method Eof:Int() Override
		Return _eof Or Not _handle
	End Method

	Rem
	bbdoc: Exchanges TLS close notifications, then closes the socket.
	about: The peer must participate. Pending application data must be consumed
	first. A timeout or TLS failure throws and still closes the stream.
	End Rem
	Method Shutdown(timeoutMillis:Int = 5000)
		_CheckTimeout(timeoutMillis)
		If Not _handle Then Return
		Local deadline:Long = bmx_tls_now() + timeoutMillis
		Try
			Repeat
				If bmx_tls_now() >= deadline Then _Fail("TLS shutdown: timeout")
				Local state:Int = bmx_tls_shutdown(_handle)
				If state = 1 Then Exit
				If state = 4 Then Continue
				_Await(state, deadline, "TLS shutdown")
			Forever
		Finally
			Close()
		End Try
	End Method

	Rem
	bbdoc: Immediately releases TLS and TCP resources. Idempotent and nonblocking.
	about: Use Shutdown for an orderly TLS close; Close is also the failure path.
	End Rem
	Method Close() Override
		If _handle Then
			bmx_tls_free(_handle)
			_handle = Null
		End If
		If _socket Then
			_socket.Close()
			_socket = Null
		End If
	End Method

	Method Delete()
		Close()
	End Method

	Private
	Field _handle:Byte Ptr
	Field _socket:TSocket
	Field _timeout:Int = 30000
	Field _eof:Int

	Function _Attach:TOpenSSLStream(context:TOpenSSLContext, socket:TSocket, peerName:String, deadline:Long)
		Local stream:TOpenSSLStream = New TOpenSSLStream
		stream._socket = socket
		Local name:Byte Ptr
		Try
			Local error:Int = bmx_tls_nonblock(Long(socket.Socket()))
			If error Then Throw New TOpenSSLException("Cannot configure TCP socket: " + error)
			name = peerName.ToUTF8String()
			stream._handle = bmx_tls_new(context._handle, Long(socket.Socket()), context._server, name)
			If Not stream._handle Then Throw New TOpenSSLException("Unable to allocate TLS connection")
			If Not bmx_tls_valid(stream._handle) Then stream._FailNative()
			Repeat
				If bmx_tls_now() >= deadline Then stream._Fail("TLS handshake: timeout")
				Local state:Int = bmx_tls_handshake(stream._handle)
				If state = 1 Then Exit
				stream._Await(state, deadline, "TLS handshake")
			Forever
			Return stream
		Catch error:Object
			stream.Close()
			Throw error
		Finally
			MemFree(name)
		End Try
	End Function

	Method _Check()
		If Not _handle Then Throw New TOpenSSLException("TLS stream is closed or uninitialized")
	End Method

	Method _Fail(message:String)
		Close()
		Throw New TOpenSSLException(message)
	End Method

	Method _FailNative()
		_Fail(String.FromUTF8String(bmx_tls_error(_handle)))
	End Method

	Method _Await(state:Int, deadline:Long, operation:String)
		If state = -1 Then _FailNative()
		If state <> 2 And state <> 3 Then _Fail(operation + ": connection closed")
		If bmx_tls_now() >= deadline Then _Fail(operation + ": timeout")
		Local ready:Int = bmx_tls_wait(Long(_socket.Socket()), state = 3, deadline)
		If Not ready Then _Fail(operation + ": timeout")
		If ready < 0 Then _Fail(operation + ": socket error " + (-ready))
	End Method

	Method _Read:Int(buffer:Byte Ptr, count:Int, deadline:Long)
		If _eof Then Return 0
		Repeat
			Local n:Int = bmx_tls_read(_handle, buffer, count)
			If n > 0 Then Return n
			If Not n Then
				_eof = True
				Return 0
			End If
			If n = -1 Then _FailNative()
			_Await(-n, deadline, "TLS read")
		Forever
	End Method

	Method _Write:Int(buffer:Byte Ptr, count:Int, deadline:Long)
		Repeat
			Local n:Int = bmx_tls_write(_handle, buffer, count)
			If n > 0 Then Return n
			If n = -1 Then _FailNative()
			_Await(-n, deadline, "TLS write")
		Forever
	End Method

	Method _ReadExact(buffer:Byte Ptr, count:Long, deadline:Long)
		While count > 0
			If bmx_tls_now() >= deadline Then _Fail("TLS read: timeout")
			Local n:Int = _Read(buffer, Int(Min(count, 65536:Long)), deadline)
			If Not n Then _Fail("TLS stream ended before the requested bytes arrived")
			buffer :+ n
			count :- n
		Wend
	End Method

	Method _WriteExact(buffer:Byte Ptr, count:Long, deadline:Long)
		While count > 0
			If bmx_tls_now() >= deadline Then _Fail("TLS write: timeout")
			Local n:Int = _Write(buffer, Int(Min(count, 65536:Long)), deadline)
			buffer :+ n
			count :- n
		Wend
	End Method
End Type

Rem
bbdoc: A TCP listener that accepts independent TLS streams.
about: Bind defaults to loopback. Set the address explicitly to expose a service.
Accept and handshakes are synchronous; a concurrent server must dispatch accepted
TCP sockets to workers and call Attach there, with its own admission limits.
End Rem
Type TOpenSSLListener Implements ICloseable

	Function Bind:TOpenSSLListener(context:TOpenSSLContext, port:Int, host:String = "127.0.0.1", backlog:Int = 16)
		If Not context Then IllegalArgumentError "A TLS context is required"
		context._Check()
		If Not context._server Then IllegalArgumentError "Bind requires a server context"
		_CheckHost(host)
		If port < 0 Or port > 65535 Or backlog < 1 Then IllegalArgumentError "Invalid port or backlog"
		Local addresses:TAddrInfo[] = AddrInfo(host, String(port), New TAddrInfo(AF_UNSPEC_, SOCK_STREAM_))
		For Local address:TAddrInfo = EachIn addresses
			Local socket:TSocket = TSocket.Create(address)
			If Not socket Then Continue
			If socket.Bind(address) And socket.Listen(backlog) And Not bmx_tls_nonblock(Long(socket.Socket())) Then
				Local listener:TOpenSSLListener = New TOpenSSLListener
				listener._socket = socket
				listener._context = context
				Return listener
			End If
			socket.Close()
		Next
		Throw New TOpenSSLException("Unable to bind TLS listener to " + host + ":" + port)
	End Function

	Rem
	bbdoc: Waits for a connection then performs TLS, with separate bounded deadlines.
	about: Returns Null if the accept deadline expires. Handshake failures throw.
	End Rem
	Method Accept:TOpenSSLStream(timeoutMillis:Int = 10000, handshakeMillis:Int = 10000)
		_CheckTimeout(timeoutMillis)
		_CheckTimeout(handshakeMillis)
		If Not _socket Then Throw New TOpenSSLException("TLS listener is closed")
		_context._Check()
		Local deadline:Long = bmx_tls_now() + timeoutMillis
		Repeat
			Local ready:Int = bmx_tls_wait(Long(_socket.Socket()), False, deadline)
			If Not ready Then Return Null
			If ready < 0 Then Throw New TOpenSSLException("TLS accept: socket error " + (-ready))
			Local socket:TSocket = _socket.Accept()
			If socket Then Return TOpenSSLStream.Attach(_context, socket, "", handshakeMillis)
			If bmx_tls_now() >= deadline Then Return Null
		Forever
	End Method

	Method LocalPort:Int()
		If Not _socket Then Return -1
		Return _socket.LocalPort()
	End Method

	Method Close() Override
		If _socket Then _socket.Close()
		_socket = Null
		_context = Null
	End Method

	Method Delete()
		Close()
	End Method

	Private
	Field _socket:TSocket
	Field _context:TOpenSSLContext
End Type

Function OpenSSLVersion:String()
	Return String.FromCString(bmx_tls_version())
End Function

Private

Function _CheckCString(value:String)
	If value.Find(Chr(0)) >= 0 Then IllegalArgumentError "Embedded NUL is not permitted in a TLS name, path or password"
End Function

Function _CheckHost(host:String)
	_CheckCString(host)
	If Not host.length Then IllegalArgumentError "A peer name or numeric IP address is required"
	For Local i:Int = 0 Until host.length
		If host[i] < 33 Or host[i] > 126 Then IllegalArgumentError "Use an ASCII DNS name (IDNA A-label) or unbracketed numeric IP address"
	Next
End Function

Function _CheckTimeout(timeoutMillis:Int)
	If timeoutMillis < 1 Then IllegalArgumentError "TLS timeout must be positive"
End Function

Function _CheckBuffer(buffer:Byte Ptr, count:Long)
	If count < 0 Or (count > 0 And Not buffer) Then IllegalArgumentError "Invalid TLS buffer or length"
End Function

Extern "C"
	Function bmx_tls_version:Byte Ptr()
	Function bmx_tls_now:Long()
	Function bmx_tls_nonblock:Int(fd:Long)
	Function bmx_tls_wait:Int(fd:Long, writing:Int, deadline:Long)
	Function bmx_tls_connect:Int(fd:Long, info:Byte Ptr, deadline:Long)
	Function bmx_tls_context_new:Byte Ptr(server:Int, ca:Byte Ptr, caPath:Byte Ptr, cert:Byte Ptr, key:Byte Ptr, password:Byte Ptr, requireClient:Int)
	Function bmx_tls_context_valid:Int(handle:Byte Ptr)
	Function bmx_tls_context_error:Byte Ptr(handle:Byte Ptr)
	Function bmx_tls_context_free(handle:Byte Ptr)
	Function bmx_tls_wipe(data:Byte Ptr, length:Long)
	Function bmx_tls_new:Byte Ptr(context:Byte Ptr, fd:Long, server:Int, host:Byte Ptr)
	Function bmx_tls_valid:Int(handle:Byte Ptr)
	Function bmx_tls_error:Byte Ptr(handle:Byte Ptr)
	Function bmx_tls_free(handle:Byte Ptr)
	Function bmx_tls_handshake:Int(handle:Byte Ptr)
	Function bmx_tls_read:Int(handle:Byte Ptr, data:Byte Ptr, count:Int)
	Function bmx_tls_write:Int(handle:Byte Ptr, data:Byte Ptr, count:Int)
	Function bmx_tls_shutdown:Int(handle:Byte Ptr)
	Function bmx_tls_protocol:Byte Ptr(handle:Byte Ptr)
	Function bmx_tls_cipher:Byte Ptr(handle:Byte Ptr)
End Extern

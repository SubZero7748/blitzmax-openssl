' SPDX-License-Identifier: MIT
SuperStrict
Framework BRL.StandardIO
Import Net.OpenSSL
Import BRL.System

Function Check(condition:Int, message:String)
	If Not condition Then Throw New TOpenSSLException("TEST: " + message)
End Function

Function Echo(stream:TOpenSSLStream)
	Local data:Byte[] = stream.ReadFrame()
	stream.WriteFrame(data)
	stream.WriteText(stream.ReadText())
End Function

Try
	Local mode:String = AppArgs[1]
	Local fixtures:String = AppArgs[2] + "/"
	If mode = "config" Then
		Local name:String = AppArgs[3]
		Local ctx:TOpenSSLContext
		Select name
			Case "missing"
				ctx = TOpenSSLContext.CreateClient(fixtures + "missing.pem")
			Case "mismatch"
				ctx = TOpenSSLContext.CreateServer(fixtures + "server.pem", fixtures + "client.key")
			Case "password"
				ctx = TOpenSSLContext.CreateServer(fixtures + "server.pem", fixtures + "encrypted.key", "correct password")
			Case "bad-password"
				ctx = TOpenSSLContext.CreateServer(fixtures + "server.pem", fixtures + "encrypted.key", "incorrect")
			Case "nul"
				ctx = TOpenSSLContext.CreateClient(fixtures + "ca.pem" + Chr(0) + "ignored")
		End Select
		ctx.Close()
		ctx.Close()
	Else If mode = "server" Then
		Local scenario:String = AppArgs[3]
		Local ctx:TOpenSSLContext = TOpenSSLContext.CreateServer(fixtures + "server.pem", fixtures + "server.key", "", fixtures + "ca.pem", "", scenario = "mtls")
		Local listener:TOpenSSLListener = TOpenSSLListener.Bind(ctx, 0)
		Print "PORT " + listener.LocalPort()
		If scenario = "accept-timeout" Then
			Check(Not listener.Accept(100), "Accept should time out")
		Else
			Local first:TOpenSSLStream = listener.Accept(5000, 2000)
			Check(first <> Null, "First connection missing")
			Local second:TOpenSSLStream
			If scenario = "two" Then
				second = listener.Accept(5000, 2000)
				Check(second <> Null, "Second connection missing")
			End If
			ctx.Close() ' Live SSL objects must retain their configuration.
			listener.Close()
			Echo(first)
			first.Shutdown()
			first.Close()
			If second Then
				Echo(second)
				second.Shutdown()
			End If
		End If
		listener.Close()
		ctx.Close()
	Else
		Local host:String = AppArgs[3]
		Local port:Int = Int(AppArgs[4])
		Local scenario:String = AppArgs[5]
		Local ctx:TOpenSSLContext
		If scenario = "mtls" Then
			ctx = TOpenSSLContext.CreateClient(fixtures + "ca.pem", "", fixtures + "client.pem", fixtures + "client.key")
		Else
			ctx = TOpenSSLContext.CreateClient(fixtures + "ca.pem")
		End If
		Local stream:TOpenSSLStream
		If scenario = "attach" Or scenario = "wrong-host" Then
			Local addresses:TAddrInfo[] = AddrInfo("127.0.0.1", String(port), New TAddrInfo(AF_INET_, SOCK_STREAM_))
			Local socket:TSocket = TSocket.Create(addresses[0])
			Check(socket.Connect(addresses[0]), "Plain TCP connect failed")
			If scenario = "attach" Then
				Local request:Byte Ptr = "STARTTLS~r~n".ToUTF8String()
				Check(socket.Send(request, 10) = 10, "STARTTLS request")
				MemFree(request)
				Local response:Byte[7]
				Local offset:Int
				While offset < 7
					Local n:Int = Int(socket.Recv(Varptr response[offset], Size_T(7 - offset)))
					Check(n > 0, "STARTTLS response ended early")
					offset :+ n
				Wend
				Check(String.FromUTF8Bytes(response, 7) = "READY~r~n", "STARTTLS response")
			End If
			stream = TOpenSSLStream.Attach(ctx, socket, host, 1000)
		Else
			stream = TOpenSSLStream.Connect(ctx, host, port, 1000)
		End If
		ctx.Close()
		stream.SetTimeout(700)
		Select scenario
			Case "echo", "mtls", "attach"
				Print "PROTOCOL " + stream.Protocol() + " " + stream.Cipher()
				For Local round:Int = 0 Until 8
					Local data:Byte[] = New Byte[131123 + round]
					For Local i:Int = 0 Until data.length
						data[i] = (i * 31 + round) & 255
					Next
					stream.WriteFrame(data)
					Local received:Byte[] = stream.ReadFrame()
					Check(received.length = data.length, "Binary length")
					For Local i:Int = 0 Until data.length
						Check(received[i] = data[i], "Binary content")
					Next
					Local value:String = "TLS " + Chr($00E6) + Chr($03A9) + Chr(0) + " payload"
					stream.WriteText(value)
					Check(stream.ReadText() = value, "UTF-8 or embedded NUL")
				Next
				stream.WriteFrame(New Byte[0])
				Check(stream.ReadFrame().length = 0, "Empty frame")
				stream.Shutdown()
			Case "oversize"
				stream.ReadFrame(1024)
			Case "read-timeout", "truncated"
				stream.ReadFrame()
			Case "write-timeout"
				Local data:Byte[] = New Byte[16777216]
				stream.WriteFrame(data)
			Case "clean-eof", "abrupt-eof"
				Local byteValue:Byte
				Check(stream.Read(Varptr byteValue, 1) = 0, "Expected EOF")
				Check(stream.Eof(), "EOF flag")
				stream.Shutdown()
		End Select
		stream.Close()
		stream.Close()
		ctx.Close()
	End If
	Print "PASS"
Catch error:Object
	Print "ERROR " + error.ToString()
	exit_(1)
End Try

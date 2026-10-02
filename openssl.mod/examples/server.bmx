' SPDX-License-Identifier: MIT
SuperStrict
Framework BRL.StandardIO
Import Net.OpenSSL

' One-connection loopback demonstration. Supply your own certificate and key.
' Usage: server server-chain.pem server.key 8443
If AppArgs.length <> 4 Then
	Print "Usage: server certificate-chain private-key port"
	End
End If

Local context:TOpenSSLContext
Local listener:TOpenSSLListener
Local stream:TOpenSSLStream
Try
	context = TOpenSSLContext.CreateServer(AppArgs[1], AppArgs[2])
	listener = TOpenSSLListener.Bind(context, Int(AppArgs[3]))
	Print "Listening on 127.0.0.1:" + listener.LocalPort()
	stream = listener.Accept(30000)
	If stream Then
		stream.WriteText(stream.ReadText(65536), 65536)
		stream.Shutdown()
	End If
Catch error:Object
	Print error.ToString()
Finally
	If stream Then stream.Close()
	If listener Then listener.Close()
	If context Then context.Close()
End Try

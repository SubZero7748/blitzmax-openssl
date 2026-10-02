' SPDX-License-Identifier: MIT
SuperStrict
Framework BRL.StandardIO
Import Net.OpenSSL

' Run the companion server first. Supply a CA bundle which trusts its certificate.
' Usage: client ca.pem localhost 8443
If AppArgs.length <> 4 Then
	Print "Usage: client CA-file server-name port"
	End
End If

Local context:TOpenSSLContext
Local stream:TOpenSSLStream
Try
	context = TOpenSSLContext.CreateClient(AppArgs[1])
	stream = TOpenSSLStream.Connect(context, AppArgs[2], Int(AppArgs[3]))
	Print stream.Protocol() + " / " + stream.Cipher()
	stream.WriteText("Hello from BlitzMax-NG")
	Print stream.ReadText()
	stream.Shutdown()
Catch error:Object
	Print error.ToString()
Finally
	If stream Then stream.Close()
	If context Then context.Close()
End Try

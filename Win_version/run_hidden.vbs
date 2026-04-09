Set objShell = CreateObject("WScript.Shell")
strPath = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
' CMD penceresini sifir(0) parametresi ile tamamen gizli baslatir ve login-wifi.py'i calistirir
objShell.Run "cmd.exe /c cd /d """ & strPath & """ && python login-wifi.py", 0, False
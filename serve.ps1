# Minimal static file server for the zatoumushi preview (no Python/Node on this machine)
$root = "D:\brender\Claude_code"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:8124/")
$listener.Start()
Write-Output "Serving $root on http://localhost:8124/"
$mime = @{ ".html"="text/html; charset=utf-8"; ".js"="text/javascript"; ".css"="text/css"; ".png"="image/png"; ".jpg"="image/jpeg"; ".svg"="image/svg+xml"; ".json"="application/json" }
while ($listener.IsListening) {
    try {
        $ctx = $listener.GetContext()
        $path = $ctx.Request.Url.AbsolutePath
        if ($ctx.Request.HttpMethod -eq "POST" -and $path -eq "/shot") {
            $reader = New-Object System.IO.StreamReader($ctx.Request.InputStream, $ctx.Request.ContentEncoding)
            $body = $reader.ReadToEnd()
            $b64 = $body -replace "^data:image/\w+;base64,", ""
            [System.IO.File]::WriteAllBytes((Join-Path $root "shot.jpg"), [Convert]::FromBase64String($b64))
            $ctx.Response.StatusCode = 200
            $ctx.Response.Close()
            continue
        }
        if ($path -eq "/") { $path = "/index.html" }
        $file = Join-Path $root ($path -replace "/", "\")
        if (Test-Path $file -PathType Leaf) {
            $bytes = [System.IO.File]::ReadAllBytes($file)
            $ext = [System.IO.Path]::GetExtension($file).ToLower()
            if ($mime.ContainsKey($ext)) { $ctx.Response.ContentType = $mime[$ext] }
            $ctx.Response.ContentLength64 = $bytes.Length
            $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $ctx.Response.StatusCode = 404
        }
        $ctx.Response.Close()
    } catch {
        # keep serving
    }
}

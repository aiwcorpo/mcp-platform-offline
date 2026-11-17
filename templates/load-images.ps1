# Checks the image files against SHA256SUMS and loads them into the local Docker. Nothing is pulled from the network.
# Run in PowerShell: powershell -ExecutionPolicy Bypass -File .\load-images.ps1
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

foreach ($line in Get-Content 'SHA256SUMS') {
    if ($line -notmatch '^([0-9a-f]{64})\s+\*?(.+)$') { throw "unexpected line in SHA256SUMS: $line" }
    $expected = $Matches[1]
    $name = $Matches[2]
    $actual = (Get-FileHash -Algorithm SHA256 -Path (Join-Path 'images' $name)).Hash.ToLower()
    if ($actual -ne $expected) { throw "checksum mismatch: images/$name" }
    Write-Host "${name}: OK"
}

foreach ($file in Get-ChildItem 'images' -Filter '*.tar') {
    docker load -i $file.FullName
    if ($LASTEXITCODE -ne 0) { throw "docker load failed: $($file.Name)" }
}
Write-Host 'ok    all images loaded'

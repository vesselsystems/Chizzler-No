param(
    [string]$Configuration = "Release",
    [ValidateSet("win-x64", "win-arm64")]
    [string]$Runtime = "win-x64",
    [string]$Version = $(if ($env:MARKETING_VERSION) { $env:MARKETING_VERSION } else { "1.0.0" }),
    [switch]$SkipMsi
)

$ErrorActionPreference = "Stop"

$RootDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$AppName = "ThoughtRecorder"
$ProjectPath = Join-Path $RootDir "windows\ThoughtRecorder.Windows\ThoughtRecorder.Windows.csproj"
$InstallerPath = Join-Path $RootDir "windows\Installer\ThoughtRecorder.wxs"
$BuildDir = Join-Path $RootDir "build\windows"
$PublishDir = Join-Path $BuildDir "publish\$Runtime"
$DistDir = Join-Path $RootDir "dist"
$ZipPath = Join-Path $DistDir "$AppName-$Version-windows-$Runtime.zip"
$MsiPath = Join-Path $DistDir "$AppName-$Version-windows-$Runtime.msi"

function Write-Sha256File {
    param([Parameter(Mandatory = $true)][string]$Path)

    $hash = Get-FileHash -Algorithm SHA256 -Path $Path
    $fileName = Split-Path -Leaf $Path
    "$($hash.Hash.ToLowerInvariant())  $fileName" | Set-Content -NoNewline -Encoding ascii "$Path.sha256"
}

New-Item -ItemType Directory -Force -Path $BuildDir, $DistDir | Out-Null
Remove-Item -Recurse -Force $PublishDir -ErrorAction SilentlyContinue
Remove-Item -Force $ZipPath, "$ZipPath.sha256", $MsiPath, "$MsiPath.sha256" -ErrorAction SilentlyContinue

dotnet restore $ProjectPath

dotnet publish $ProjectPath `
    --configuration $Configuration `
    --runtime $Runtime `
    --self-contained true `
    --output $PublishDir `
    /p:PublishSingleFile=true `
    /p:IncludeNativeLibrariesForSelfExtract=true `
    /p:EnableCompressionInSingleFile=true `
    /p:PublishReadyToRun=true `
    /p:DebugType=none `
    /p:DebugSymbols=false `
    /p:Version=$Version `
    /p:InformationalVersion=$Version

Compress-Archive -Path (Join-Path $PublishDir "*") -DestinationPath $ZipPath -CompressionLevel Optimal
Write-Sha256File -Path $ZipPath
Write-Host "Packaged: $ZipPath"

if (-not $SkipMsi) {
    dotnet tool restore

    $wixArchitecture = if ($Runtime -eq "win-arm64") { "arm64" } else { "x64" }
    dotnet tool run wix -- build $InstallerPath `
        -arch $wixArchitecture `
        -out $MsiPath `
        -d "PublishDir=$PublishDir" `
        -d "ProductVersion=$Version"

    Write-Sha256File -Path $MsiPath
    Write-Host "Packaged: $MsiPath"
}

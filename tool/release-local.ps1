param(
    [switch]$Publish,
    [string]$NotesFile
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($env:OS -ne 'Windows_NT') {
    throw 'The complete ClassSync release must run on Windows.'
}

function Assert-LastExitCode([string]$Step) {
    if ($LASTEXITCODE -ne 0) {
        throw "$Step failed with exit code $LASTEXITCODE."
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$clientRoot = Join-Path $repoRoot 'apps\client'
$pubspec = Join-Path $clientRoot 'pubspec.yaml'
$versionLine = Select-String -Path $pubspec -Pattern '^version:\s+(.+)$'
if (-not $versionLine) {
    throw 'Could not read the ClassSync version from pubspec.yaml.'
}
$version = $versionLine.Matches[0].Groups[1].Value.Split('+')[0]
$tag = "v$version"
$releaseDir = Join-Path $repoRoot "dist\release-$version"
$expectedAndroidCertSha256 = 'c1b5b4db5e23e2f468dab06262bf149cb03ad3f9562307d7dfc8946092ded30d'

Push-Location $repoRoot
try {
    if (git status --porcelain) {
        throw 'Commit or stash local changes before building a release.'
    }
    if (Test-Path $releaseDir) {
        throw "Release directory already exists: $releaseDir"
    }
    if (-not (Test-Path (Join-Path $clientRoot 'android\key.properties'))) {
        throw 'android\key.properties is required to sign the release APK.'
    }

    pnpm install --frozen-lockfile
    Assert-LastExitCode 'pnpm install'
    pnpm relay:check
    Assert-LastExitCode 'Relay validation'

    Push-Location $clientRoot
    try {
        flutter pub get
        Assert-LastExitCode 'flutter pub get'
        dart format --output=none --set-exit-if-changed lib test tool
        Assert-LastExitCode 'Dart formatting check'
        flutter analyze
        Assert-LastExitCode 'Flutter analyzer'
        flutter test --coverage
        Assert-LastExitCode 'Flutter tests'
        dart run tool/check_coverage.dart coverage/lcov.info 50
        Assert-LastExitCode 'Coverage threshold'
        flutter build windows --release
        Assert-LastExitCode 'Windows release build'
        flutter build apk --release
        Assert-LastExitCode 'Android release build'
    }
    finally {
        Pop-Location
    }

    $androidApk = Join-Path $clientRoot 'build\app\outputs\flutter-apk\app-release.apk'
    $apksigner = Get-Command apksigner.bat -ErrorAction SilentlyContinue
    if (-not $apksigner) {
        $adb = Get-Command adb.exe -ErrorAction SilentlyContinue
        $androidSdkCandidates = @()
        if ($adb) {
            $androidSdkCandidates += Split-Path (Split-Path $adb.Source -Parent) -Parent
        }
        if ($env:ANDROID_SDK_ROOT) {
            $androidSdkCandidates += $env:ANDROID_SDK_ROOT
        }
        if ($env:ANDROID_HOME) {
            $androidSdkCandidates += $env:ANDROID_HOME
        }
        if ($env:LOCALAPPDATA) {
            $androidSdkCandidates += Join-Path $env:LOCALAPPDATA 'Android\Sdk'
        }

        foreach ($androidSdk in $androidSdkCandidates | Select-Object -Unique) {
            $buildToolsRoot = Join-Path $androidSdk 'build-tools'
            if (Test-Path $buildToolsRoot) {
                $latestBuildTools = Get-ChildItem $buildToolsRoot -Directory |
                    Sort-Object { try { [version]$_.Name } catch { [version]'0.0' } } -Descending |
                    Select-Object -First 1
                if ($latestBuildTools) {
                    $candidate = Join-Path $latestBuildTools.FullName 'apksigner.bat'
                    if (Test-Path $candidate) {
                        $apksigner = Get-Item $candidate
                        break
                    }
                }
            }
        }
    }
    if (-not $apksigner) {
        throw 'Could not find apksigner.bat. Install Android SDK Build Tools or add apksigner to PATH.'
    }

    $apksignerPath = if ($apksigner -is [System.IO.FileInfo]) {
        $apksigner.FullName
    }
    else {
        $apksigner.Source
    }
    $certOutput = & $apksignerPath verify --print-certs $androidApk 2>&1
    Assert-LastExitCode 'Android APK signature verification'
    $certLine = $certOutput | Select-String -Pattern '(?:Signer #1|V2 Signer) certificate SHA-256 digest:\s*([0-9a-fA-F]+)' | Select-Object -First 1
    if (-not $certLine) {
        throw 'Could not read the Android signing certificate SHA-256 fingerprint from the release APK.'
    }
    $actualAndroidCertSha256 = $certLine.Matches[0].Groups[1].Value.ToLowerInvariant()
    if ($actualAndroidCertSha256 -ne $expectedAndroidCertSha256) {
        throw "Android release signing certificate mismatch. Expected $expectedAndroidCertSha256 but got $actualAndroidCertSha256. Refusing to create release artifacts."
    }
    Write-Host "Android signing certificate verified: $actualAndroidCertSha256"

    $iscc = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if (-not $iscc) {
        $isccPath = @(
            'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
            'C:\Program Files\Inno Setup 6\ISCC.exe'
            (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
        ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if (-not $isccPath) {
            throw 'Install Inno Setup 6 or add ISCC.exe to PATH.'
        }
    }
    else {
        $isccPath = $iscc.Source
    }
    & $isccPath "/DMyAppVersion=$version" (Join-Path $repoRoot 'packaging\windows\classsync.iss')
    Assert-LastExitCode 'Windows installer build'

    New-Item -ItemType Directory -Path $releaseDir | Out-Null
    Copy-Item $androidApk (Join-Path $releaseDir 'ClassSync-Android.apk')
    Copy-Item (Join-Path $repoRoot "dist\ClassSync-Setup-$version.exe") $releaseDir

    $artifacts = Get-ChildItem $releaseDir -File | Sort-Object Name
    $checksums = foreach ($artifact in $artifacts) {
        $hash = (Get-FileHash $artifact.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $($artifact.Name)"
    }
    Set-Content -Path (Join-Path $releaseDir 'SHA256SUMS.txt') -Value $checksums -Encoding ascii

    if ($Publish) {
        if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
            throw 'GitHub CLI is required when -Publish is used.'
        }
        gh auth status
        Assert-LastExitCode 'GitHub authentication check'
        $commitMessage = git log -1 --pretty=%B
        if ($commitMessage -notmatch '\[(skip ci|ci skip)\]') {
            throw 'The release commit must contain [skip ci] so the tag push cannot start GitHub Actions.'
        }
        $existingTag = git ls-remote --exit-code --tags origin "refs/tags/$tag"
        if ($LASTEXITCODE -eq 0) {
            throw "Remote tag $tag already exists."
        }
        if ($LASTEXITCODE -ne 2) {
            throw "Could not check remote tag $tag."
        }
        git tag -a $tag -m "ClassSync $tag [skip ci]"
        Assert-LastExitCode 'Local tag creation'
        git push origin $tag
        Assert-LastExitCode 'Tag push'

        $releaseArgs = @(
            'release', 'create', $tag,
            (Join-Path $releaseDir 'ClassSync-Android.apk') + '#ClassSync Android APK',
            (Join-Path $releaseDir "ClassSync-Setup-$version.exe") + '#ClassSync Windows installer',
            (Join-Path $releaseDir 'SHA256SUMS.txt') + '#SHA-256 checksums',
            '--title', "ClassSync $tag",
            '--verify-tag'
        )
        if ($NotesFile) {
            $releaseArgs += @('--notes-file', (Resolve-Path $NotesFile).Path)
        }
        else {
            $releaseArgs += '--generate-notes'
        }
        gh @releaseArgs
        Assert-LastExitCode 'GitHub release publication'
    }

    Write-Host "Release artifacts: $releaseDir"
}
finally {
    Pop-Location
}

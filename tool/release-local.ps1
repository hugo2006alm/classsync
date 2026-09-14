param(
    [switch]$Publish,
    [string]$NotesFile,
    [switch]$Yes
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

$expectedAndroidCertSha256 =
    'c1b5b4db5e23e2f468dab06262bf149cb03ad3f9562307d7dfc8946092ded30d'

Push-Location $repoRoot

try {
    # -------------------------------------------------------------------------
    # Repository preflight
    # -------------------------------------------------------------------------

    if (git status --porcelain) {
        throw 'Commit or stash local changes before building a release.'
    }

    if (Test-Path $releaseDir) {
        throw "Release directory already exists: $releaseDir"
    }

    if (-not (Test-Path (Join-Path $clientRoot 'android\key.properties'))) {
        throw 'android\key.properties is required to sign the release APK.'
    }

    if ($NotesFile -and -not (Test-Path -LiteralPath $NotesFile)) {
        throw "Release notes file does not exist: $NotesFile"
    }

    if ($Publish) {
        if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
            throw 'GitHub CLI is required when -Publish is used.'
        }

        gh auth status
        Assert-LastExitCode 'GitHub authentication check'

        $currentBranch = (git rev-parse --abbrev-ref HEAD).Trim()
        Assert-LastExitCode 'Current branch check'

        if ($currentBranch -ne 'main') {
            throw "Publishing is only allowed from main. Current branch: $currentBranch"
        }

        git fetch origin main --quiet
        Assert-LastExitCode 'Fetch origin/main'

        $headSha = (git rev-parse HEAD).Trim()
        Assert-LastExitCode 'Read local HEAD'

        $originMainSha = (git rev-parse origin/main).Trim()
        Assert-LastExitCode 'Read origin/main'

        if ($headSha -ne $originMainSha) {
            throw @"
Local main is not exactly synchronized with origin/main.

Local HEAD:  $headSha
origin/main: $originMainSha

Pull/push the repository before publishing.
"@
        }

        $commitMessage = git log -1 --pretty=%B
        Assert-LastExitCode 'Read release commit message'

        if ($commitMessage -notmatch '\[(skip ci|ci skip)\]') {
            throw 'The release commit must contain [skip ci] so the tag push cannot start GitHub Actions.'
        }

        git ls-remote --exit-code --tags origin "refs/tags/$tag" *> $null
        $remoteTagExitCode = $LASTEXITCODE

        if ($remoteTagExitCode -eq 0) {
            throw "Remote tag $tag already exists."
        }

        if ($remoteTagExitCode -ne 2) {
            throw "Could not check whether remote tag $tag exists."
        }

        $localTag = git tag --list $tag
        Assert-LastExitCode 'Local tag check'

        if ($localTag) {
            throw "Local tag $tag already exists."
        }

        Write-Host ""
        Write-Host "Release preflight OK:"
        Write-Host "  Version: $version"
        Write-Host "  Tag:     $tag"
        Write-Host "  Commit:  $headSha"
        Write-Host ""
    }

    # -------------------------------------------------------------------------
    # Dependencies and validation
    # -------------------------------------------------------------------------

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

    # -------------------------------------------------------------------------
    # Android signature verification
    # -------------------------------------------------------------------------

    $androidApk = Join-Path `
        $clientRoot `
        'build\app\outputs\flutter-apk\app-release.apk'

    if (-not (Test-Path -LiteralPath $androidApk)) {
        throw "Android APK was not generated: $androidApk"
    }

    $apksigner = Get-Command apksigner.bat -ErrorAction SilentlyContinue

    if (-not $apksigner) {
        $adb = Get-Command adb.exe -ErrorAction SilentlyContinue
        $androidSdkCandidates = @()

        if ($adb) {
            $androidSdkCandidates +=
                Split-Path (Split-Path $adb.Source -Parent) -Parent
        }

        if ($env:ANDROID_SDK_ROOT) {
            $androidSdkCandidates += $env:ANDROID_SDK_ROOT
        }

        if ($env:ANDROID_HOME) {
            $androidSdkCandidates += $env:ANDROID_HOME
        }

        if ($env:LOCALAPPDATA) {
            $androidSdkCandidates +=
                Join-Path $env:LOCALAPPDATA 'Android\Sdk'
        }

        foreach ($androidSdk in $androidSdkCandidates | Select-Object -Unique) {
            $buildToolsRoot = Join-Path $androidSdk 'build-tools'

            if (-not (Test-Path $buildToolsRoot)) {
                continue
            }

            $latestBuildTools =
                Get-ChildItem $buildToolsRoot -Directory |
                Sort-Object {
                    try {
                        [version]$_.Name
                    }
                    catch {
                        [version]'0.0'
                    }
                } -Descending |
                Select-Object -First 1

            if ($latestBuildTools) {
                $candidate =
                    Join-Path $latestBuildTools.FullName 'apksigner.bat'

                if (Test-Path $candidate) {
                    $apksigner = Get-Item $candidate
                    break
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

    #
    # Windows PowerShell 5 can turn harmless native stderr output into a
    # NativeCommandError when ErrorActionPreference is Stop.
    #
    # Newer Java runtimes currently emit a "restricted method" warning through
    # stderr when apksigner starts. Capture that output without treating it as a
    # failed verification, and use apksigner's real exit code instead.
    #
    $previousErrorActionPreference = $ErrorActionPreference
    $certOutputRaw = @()
    $apksignerExitCode = -1

    try {
        $ErrorActionPreference = 'Continue'

        $certOutputRaw =
            & $apksignerPath verify --print-certs $androidApk 2>&1

        $apksignerExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    $certOutput = @(
        $certOutputRaw |
        ForEach-Object {
            $_.ToString()
        }
    )

    if ($apksignerExitCode -ne 0) {
        $details = $certOutput -join [Environment]::NewLine

        throw @"
Android APK signature verification failed with exit code $apksignerExitCode.

apksigner output:
$details
"@
    }

    $certLine =
        $certOutput |
        Select-String `
            -Pattern '(?:Signer #1|V2 Signer):? certificate SHA-256 digest:\s*([0-9a-fA-F]+)' |
        Select-Object -First 1

    if (-not $certLine) {
        $details = $certOutput -join [Environment]::NewLine

        throw @"
Could not read the Android signing certificate SHA-256 fingerprint from the release APK.

apksigner output:
$details
"@
    }

    $actualAndroidCertSha256 =
        $certLine.Matches[0].Groups[1].Value.ToLowerInvariant()

    if ($actualAndroidCertSha256 -ne $expectedAndroidCertSha256) {
        throw @"
Android release signing certificate mismatch.

Expected:
$expectedAndroidCertSha256

Actual:
$actualAndroidCertSha256

Refusing to create release artifacts.
"@
    }

    Write-Host ""
    Write-Host "Android signing certificate verified:"
    Write-Host "  $actualAndroidCertSha256"
    Write-Host ""

    # -------------------------------------------------------------------------
    # Windows installer
    # -------------------------------------------------------------------------

    $iscc = Get-Command ISCC.exe -ErrorAction SilentlyContinue

    if (-not $iscc) {
        $isccPath = @(
            'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
            'C:\Program Files\Inno Setup 6\ISCC.exe'
            (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
        ) |
        Where-Object {
            Test-Path -LiteralPath $_
        } |
        Select-Object -First 1

        if (-not $isccPath) {
            throw 'Install Inno Setup 6 or add ISCC.exe to PATH.'
        }
    }
    else {
        $isccPath = $iscc.Source
    }

    & $isccPath `
        "/DMyAppVersion=$version" `
        (Join-Path $repoRoot 'packaging\windows\classsync.iss')

    Assert-LastExitCode 'Windows installer build'

    $windowsInstaller =
        Join-Path $repoRoot "dist\ClassSync-Setup-$version.exe"

    if (-not (Test-Path -LiteralPath $windowsInstaller)) {
        throw "Windows installer was not generated: $windowsInstaller"
    }

    # -------------------------------------------------------------------------
    # Release artifacts
    # -------------------------------------------------------------------------

    New-Item `
        -ItemType Directory `
        -Path $releaseDir `
        -ErrorAction Stop |
        Out-Null

    Copy-Item `
        $androidApk `
        (Join-Path $releaseDir 'ClassSync-Android.apk')

    Copy-Item `
        $windowsInstaller `
        $releaseDir

    $artifacts =
        Get-ChildItem $releaseDir -File |
        Sort-Object Name

    $checksums = foreach ($artifact in $artifacts) {
        $hash =
            (Get-FileHash $artifact.FullName -Algorithm SHA256).
            Hash.
            ToLowerInvariant()

        "$hash  $($artifact.Name)"
    }

    $checksumFile = Join-Path $releaseDir 'SHA256SUMS.txt'

    Set-Content `
        -Path $checksumFile `
        -Value $checksums `
        -Encoding ascii

    Write-Host "Release artifacts validated:"
    Get-ChildItem $releaseDir -File |
        ForEach-Object {
            Write-Host "  $($_.Name)"
        }

    Write-Host ""

    # -------------------------------------------------------------------------
    # GitHub publication
    # -------------------------------------------------------------------------

    if ($Publish) {
        if (-not $Yes) {
            Write-Host "Everything passed."
            Write-Host ""
            Write-Host "About to publish:"
            Write-Host "  GitHub tag:     $tag"
            Write-Host "  GitHub release: ClassSync $tag"
            Write-Host "  Source commit:  $headSha"
            Write-Host ""

            $confirmation =
                Read-Host "Type PUBLISH to create the tag and GitHub release"

            if ($confirmation -cne 'PUBLISH') {
                Write-Host ""
                Write-Host 'Publication cancelled. Built artifacts were kept.'
                Write-Host "Artifacts: $releaseDir"
                return
            }
        }

        Write-Host ""
        Write-Host "Creating tag $tag..."

        git tag -a $tag -m "ClassSync $tag [skip ci]"
        Assert-LastExitCode 'Local tag creation'

        git push origin $tag
        Assert-LastExitCode 'Tag push'

        $androidAsset =
            (Join-Path $releaseDir 'ClassSync-Android.apk') +
            '#ClassSync Android APK'

        $windowsAsset =
            (Join-Path $releaseDir "ClassSync-Setup-$version.exe") +
            '#ClassSync Windows installer'

        $checksumsAsset =
            $checksumFile +
            '#SHA-256 checksums'

        $releaseArgs = @(
            'release'
            'create'
            $tag
            $androidAsset
            $windowsAsset
            $checksumsAsset
            '--title'
            "ClassSync $tag"
            '--verify-tag'
        )

        if ($NotesFile) {
            $releaseArgs += @(
                '--notes-file'
                (Resolve-Path $NotesFile).Path
            )
        }
        else {
            $releaseArgs += '--generate-notes'
        }

        gh @releaseArgs
        Assert-LastExitCode 'GitHub release publication'

        Write-Host ""
        Write-Host "Release published successfully: $tag"

        gh release view $tag --web:$false
        Assert-LastExitCode 'GitHub release verification'
    }

    Write-Host ""
    Write-Host "Release artifacts: $releaseDir"
}
finally {
    Pop-Location
}
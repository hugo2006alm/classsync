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

    $iscc = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if (-not $iscc) {
        $defaultIscc = 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
        if (-not (Test-Path $defaultIscc)) {
            throw 'Install Inno Setup 6 or add ISCC.exe to PATH.'
        }
        $isccPath = $defaultIscc
    }
    else {
        $isccPath = $iscc.Source
    }
    & $isccPath "/DMyAppVersion=$version" (Join-Path $repoRoot 'packaging\windows\classsync.iss')
    Assert-LastExitCode 'Windows installer build'

    New-Item -ItemType Directory -Path $releaseDir | Out-Null
    Copy-Item (Join-Path $clientRoot 'build\app\outputs\flutter-apk\app-release.apk') (Join-Path $releaseDir 'ClassSync-Android.apk')
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

param(
    [switch]$UpdateGitHubSecrets,
    [switch]$ConfirmRotation
)

$ErrorActionPreference = 'Stop'

if (-not $ConfirmRotation) {
    throw 'Key rotation changes Android update identity. Re-run with -ConfirmRotation only when intentional.'
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$androidRoot = Join-Path $repoRoot 'apps\client\android'
$appRoot = Join-Path $androidRoot 'app'
$keyPath = Join-Path $appRoot 'classsync-release.jks'
$backupPath = Join-Path $appRoot 'classsync-release-pre-0.3.11.jks'
$temporaryKeyPath = Join-Path $appRoot 'classsync-release-new.jks'
$keyPropertiesPath = Join-Path $androidRoot 'key.properties'
$vaultDirectory = Join-Path $env:LOCALAPPDATA 'ClassSync'
$vaultPath = Join-Path $vaultDirectory 'android-signing.dpapi'
$keyAlias = 'classsync-release'

if (Test-Path -LiteralPath $temporaryKeyPath) {
    throw "Temporary signing key already exists: $temporaryKeyPath"
}

$secretBytes = New-Object byte[] 36
[System.Security.Cryptography.RandomNumberGenerator]::Fill($secretBytes)
$password = [Convert]::ToBase64String($secretBytes).
    TrimEnd('=').
    Replace('+', '-').
    Replace('/', '_')

try {
    $generateArguments = @(
        '-genkeypair',
        '-v',
        '-keystore', $temporaryKeyPath,
        '-storetype', 'PKCS12',
        '-storepass', $password,
        '-keypass', $password,
        '-alias', $keyAlias,
        '-keyalg', 'RSA',
        '-keysize', '4096',
        '-validity', '10000',
        '-dname', 'CN=ClassSync, OU=Release, O=ClassSync, L=Porto, C=PT'
    )
    & keytool @generateArguments 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $temporaryKeyPath)) {
        throw 'New Android release keystore generation failed.'
    }

    if (Test-Path -LiteralPath $keyPath) {
        if (-not (Test-Path -LiteralPath $backupPath)) {
            Copy-Item -LiteralPath $keyPath -Destination $backupPath
        }
        [IO.File]::Delete($keyPath)
    }
    [IO.File]::Move($temporaryKeyPath, $keyPath)

    $properties = @(
        "storePassword=$password"
        "keyPassword=$password"
        "keyAlias=$keyAlias"
        'storeFile=classsync-release.jks'
    ) -join [Environment]::NewLine
    [IO.File]::WriteAllText(
        $keyPropertiesPath,
        $properties + [Environment]::NewLine,
        [Text.Encoding]::ASCII
    )

    $listArguments = @(
        '-list',
        '-v',
        '-keystore', $keyPath,
        '-storepass', $password,
        '-alias', $keyAlias
    )
    $certificateOutput = & keytool @listArguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw 'New Android release keystore verification failed.'
    }
    $certificateMatch = [regex]::Match(
        ($certificateOutput -join "`n"),
        'SHA256:\s*([0-9A-F:]+)'
    )
    if (-not $certificateMatch.Success) {
        throw 'Could not determine the new Android certificate fingerprint.'
    }
    $fingerprint = $certificateMatch.Groups[1].Value.Replace(':', '').ToLowerInvariant()

    [IO.Directory]::CreateDirectory($vaultDirectory) | Out-Null
    $vaultJson = @{
        keyAlias = $keyAlias
        storePassword = $password
        keyPassword = $password
        storeFile = $keyPath
        certificateSha256 = $fingerprint
    } | ConvertTo-Json -Compress
    $entropy = [Text.Encoding]::UTF8.GetBytes('ClassSync.AndroidSigning.v1')
    $protected = [Security.Cryptography.ProtectedData]::Protect(
        [Text.Encoding]::UTF8.GetBytes($vaultJson),
        $entropy,
        [Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    [IO.File]::WriteAllBytes($vaultPath, $protected)

    if ($UpdateGitHubSecrets) {
        $keystoreBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($keyPath))
        $keystoreBase64 | gh secret set ANDROID_KEYSTORE_BASE64
        if ($LASTEXITCODE -ne 0) { throw 'Could not update ANDROID_KEYSTORE_BASE64.' }
        $password | gh secret set ANDROID_KEYSTORE_PASSWORD
        if ($LASTEXITCODE -ne 0) { throw 'Could not update ANDROID_KEYSTORE_PASSWORD.' }
        $keyAlias | gh secret set ANDROID_KEY_ALIAS
        if ($LASTEXITCODE -ne 0) { throw 'Could not update ANDROID_KEY_ALIAS.' }
        $password | gh secret set ANDROID_KEY_PASSWORD
        if ($LASTEXITCODE -ne 0) { throw 'Could not update ANDROID_KEY_PASSWORD.' }
    }

    [pscustomobject]@{
        CertificateSha256 = $fingerprint
        Keystore = $keyPath
        PreviousKeystoreBackup = $backupPath
        DpapiVault = $vaultPath
        GitHubSecretsUpdated = [bool]$UpdateGitHubSecrets
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryKeyPath) {
        [IO.File]::Delete($temporaryKeyPath)
    }
    if ($secretBytes) {
        [Array]::Clear($secretBytes, 0, $secretBytes.Length)
    }
    $password = $null
}

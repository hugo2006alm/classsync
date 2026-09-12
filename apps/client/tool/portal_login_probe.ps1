param(
  [switch]$UseSaved,
  [switch]$ForgetSaved
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Security

$clientRoot = Split-Path $PSScriptRoot -Parent
$dartCommand = (Get-Command dart -ErrorAction Stop).Source
$dartExecutable = Join-Path (Split-Path $dartCommand -Parent) 'cache/dart-sdk/bin/dart.exe'
$packagesPath = Join-Path $clientRoot '.dart_tool/package_config.json'
$probePath = Join-Path $PSScriptRoot 'portal_login_probe.dart'
$credentialDirectory = Join-Path $env:LOCALAPPDATA 'ClassSync'
$credentialPath = Join-Path $credentialDirectory 'portal-probe.dpapi'
$reportPath = Join-Path $env:TEMP 'classsync-portal-probe-result.json'

if (!(Test-Path $packagesPath)) { throw 'Run flutter pub get from apps/client first.' }

function Invoke-PortalProbe([string]$credentialJson) {
  $start = New-Object System.Diagnostics.ProcessStartInfo
  $start.FileName = $dartExecutable
  $start.ArgumentList.Add("--packages=$packagesPath")
  $start.ArgumentList.Add($probePath)
  $start.UseShellExecute = $false
  $start.CreateNoWindow = $true
  $start.RedirectStandardInput = $true
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  $proc = [System.Diagnostics.Process]::Start($start)
  try {
    $proc.StandardInput.WriteLine($credentialJson)
    $proc.StandardInput.Close()
    $result = $proc.StandardOutput.ReadToEnd()
    $proc.WaitForExit()
    if ($proc.ExitCode -ne 0 -or !$result.StartsWith('{')) {
      throw 'The local Portal probe did not return a sanitized report.'
    }
    return $result | ConvertFrom-Json
  } finally {
    if (!$proc.HasExited) { $proc.Kill() }
    $proc.Dispose()
  }
}

function Save-ProbeCredential([string]$credentialJson) {
  [byte[]]$plainBytes = [System.Text.Encoding]::UTF8.GetBytes($credentialJson)
  try {
    [byte[]]$protectedBytes = [System.Security.Cryptography.ProtectedData]::Protect(
      $plainBytes,
      $null,
      [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    [System.IO.Directory]::CreateDirectory($credentialDirectory) | Out-Null
    [System.IO.File]::WriteAllBytes($credentialPath, $protectedBytes)
  } finally {
    if ($null -ne $plainBytes) { [System.Array]::Clear($plainBytes, 0, $plainBytes.Length) }
  }
}

function Read-ProbeCredential {
  if (!(Test-Path -LiteralPath $credentialPath)) {
    throw 'No saved Portal probe login. Run this script without -UseSaved first.'
  }
  [byte[]]$protectedBytes = [System.IO.File]::ReadAllBytes($credentialPath)
  [byte[]]$plainBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
    $protectedBytes,
    $null,
    [System.Security.Cryptography.DataProtectionScope]::CurrentUser
  )
  try {
    return [System.Text.Encoding]::UTF8.GetString($plainBytes)
  } finally {
    [System.Array]::Clear($plainBytes, 0, $plainBytes.Length)
  }
}

function Save-SanitizedReport($report) {
  $report | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 -LiteralPath $reportPath
}

if ($ForgetSaved) {
  if (Test-Path -LiteralPath $credentialPath) {
    Remove-Item -LiteralPath $credentialPath -Force
  }
  Write-Output 'Saved Portal probe login removed.'
  exit 0
}

if ($UseSaved) {
  $credentialJson = Read-ProbeCredential
  try {
    $report = Invoke-PortalProbe $credentialJson
    Save-SanitizedReport $report
    $report | ConvertTo-Json -Depth 10
  } finally {
    $credentialJson = $null
  }
  exit 0
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'ClassSync — local Portal login test'
$form.Size = New-Object System.Drawing.Size(620,620)
$form.StartPosition = 'CenterScreen'
$label = New-Object System.Windows.Forms.Label
$label.Text = "Test the read-only ISEP Portal connection from ClassSync.`r`nThe login is encrypted with Windows DPAPI for this user. It is never printed, logged, or stored in the repository."
$label.SetBounds(20,15,560,55)
$userLabel = New-Object System.Windows.Forms.Label
$userLabel.Text = 'Portal username or ISEP email'
$userLabel.SetBounds(20,72,220,20)
$userBox = New-Object System.Windows.Forms.TextBox
$userBox.SetBounds(20,92,420,25)
$passLabel = New-Object System.Windows.Forms.Label
$passLabel.Text = 'Password'
$passLabel.SetBounds(20,122,100,20)
$passBox = New-Object System.Windows.Forms.TextBox
$passBox.UseSystemPasswordChar = $true
$passBox.SetBounds(20,142,420,25)
$saveBox = New-Object System.Windows.Forms.CheckBox
$saveBox.Text = 'Save encrypted for repeat local tests'
$saveBox.Checked = $true
$saveBox.SetBounds(20,174,310,25)
$button = New-Object System.Windows.Forms.Button
$button.Text = 'Test login'
$button.SetBounds(20,210,160,32)
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.SetBounds(190,210,370,32)
$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Multiline = $true
$outputBox.ReadOnly = $true
$outputBox.ScrollBars = 'Vertical'
$outputBox.SetBounds(20,255,560,275)
$privacyLabel = New-Object System.Windows.Forms.Label
$privacyLabel.Text = "Saved at %LOCALAPPDATA%\ClassSync\portal-probe.dpapi and decryptable only by your Windows account.`r`nRun with -ForgetSaved to remove it. The displayed report contains structure and counts only."
$privacyLabel.SetBounds(20,535,560,40)
$button.Add_Click({
  $button.Enabled = $false
  $statusLabel.Text = 'Testing…'
  $form.Refresh()
  $credentialJson = $null
  try {
    $credentialJson = @{username=$userBox.Text; password=$passBox.Text} | ConvertTo-Json -Compress
    $passBox.Clear()
    $report = Invoke-PortalProbe $credentialJson
    $outputBox.Text = $report | ConvertTo-Json -Depth 10
    $statusLabel.Text = "Result: $($report.result)"
    Save-SanitizedReport $report
    if ($report.result -eq 'success' -and $saveBox.Checked) {
      Save-ProbeCredential $credentialJson
      $statusLabel.Text = 'Success — encrypted login saved'
    }
  } catch {
    $statusLabel.Text = 'Test failed to run. Return to Codex.'
  } finally {
    $credentialJson = $null
    $button.Enabled = $true
  }
})
$form.Controls.AddRange(@(
  $label,$userLabel,$userBox,$passLabel,$passBox,$saveBox,$button,
  $statusLabel,$outputBox,$privacyLabel
))
$form.AcceptButton = $button
[void]$form.ShowDialog()

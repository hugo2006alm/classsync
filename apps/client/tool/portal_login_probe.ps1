Add-Type -AssemblyName System.Windows.Forms
$clientRoot = Split-Path $PSScriptRoot -Parent
$dartCommand = (Get-Command dart -ErrorAction Stop).Source
$dartExecutable = Join-Path (Split-Path $dartCommand -Parent) 'cache/dart-sdk/bin/dart.exe'
$packagesPath = Join-Path $clientRoot '.dart_tool/package_config.json'
$probePath = Join-Path $PSScriptRoot 'portal_login_probe.dart'
if (!(Test-Path $packagesPath)) { throw 'Run flutter pub get from apps/client first.' }
$form = New-Object System.Windows.Forms.Form
$form.Text = 'ClassSync — local Portal login test'
$form.Size = New-Object System.Drawing.Size(620,570)
$form.StartPosition = 'CenterScreen'
$label = New-Object System.Windows.Forms.Label
$label.Text = "Test Portal login directly from ClassSync code.`r`nPassword goes only to ISEP. No password saved or logged."
$label.SetBounds(20,15,430,45)
$userBox = New-Object System.Windows.Forms.TextBox
$userBox.SetBounds(20,70,420,25)
$passBox = New-Object System.Windows.Forms.TextBox
$passBox.UseSystemPasswordChar = $true
$passBox.SetBounds(20,105,420,25)
$button = New-Object System.Windows.Forms.Button
$button.Text = 'Test login'
$button.SetBounds(20,145,160,32)
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.SetBounds(190,145,250,45)
$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Multiline = $true
$outputBox.ReadOnly = $true
$outputBox.ScrollBars = 'Vertical'
$outputBox.SetBounds(20,200,560,300)
$button.Add_Click({
  $button.Enabled = $false
  $statusLabel.Text = 'Testing…'
  $form.Refresh()
  try {
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
    $proc.StandardInput.WriteLine((@{username=$userBox.Text; password=$passBox.Text} | ConvertTo-Json -Compress))
    $proc.StandardInput.Close()
    $passBox.Clear()
    $result = $proc.StandardOutput.ReadToEnd()
    $proc.WaitForExit()
    if ($proc.ExitCode -eq 0 -and $result.StartsWith('{')) {
      $report = $result | ConvertFrom-Json
      $outputBox.Text = $report | ConvertTo-Json -Depth 8
      $statusLabel.Text = "Result: $($report.result)"
    } else { $statusLabel.Text = 'Test failed to run. Return to Codex.' }
  } catch { $statusLabel.Text = 'Test failed to run. Return to Codex.' }
  $button.Enabled = $true
})
$form.Controls.AddRange(@($label,$userBox,$passBox,$button,$statusLabel,$outputBox))
$form.AcceptButton = $button
[void]$form.ShowDialog()

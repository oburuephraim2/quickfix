
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
# ===== ADMIN CHECK =====
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.Forms.MessageBox]::Show("Please run this tool as Administrator!", "Permission Required", "OK", "Warning")
    exit
}

# ===== DISCLAIMER =====
[System.Windows.Forms.MessageBox]::Show(
    "Disclaimer:`n`nSystemCare is provided as-is. Use at your own risk.`n" +
    "- Backup important data before running any cleanup or repair.`n" +
    "- Some operations may require administrator privileges and a system restart.`n" +
    "- The developer (Ephraim Oburu) is not responsible for any data loss or system issues.",
    "Disclaimer",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Warning
)

# ===== FORM SETUP =====
$form = New-Object System.Windows.Forms.Form
$form.Text = "QuickFix PC Toolkit - Easy PC Fixer"
$form.Size = New-Object System.Drawing.Size(500, 720)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(245,245,245)
# Title & Subtitle
$title = New-Object System.Windows.Forms.Label
$title.Text = "QuickFix PC Toolkit"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(110, 20)
$form.Controls.Add($title)
$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "One-click fixes, cleanup & optimization for Windows"
$subtitle.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$subtitle.AutoSize = $true
$subtitle.Location = New-Object System.Drawing.Point(100, 55)
$form.Controls.Add($subtitle)
# Status Label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Ready"
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$statusLabel.Location = New-Object System.Drawing.Point(30, 600)
$statusLabel.Size = New-Object System.Drawing.Size(440, 30)
$statusLabel.ForeColor = "DarkBlue"
$form.Controls.Add($statusLabel)
# Progress Bar (hidden by default)
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(30, 635)
$progressBar.Size = New-Object System.Drawing.Size(440, 25)
$progressBar.Style = "Continuous"
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$progressBar.Value = 0
$progressBar.Visible = $false
$form.Controls.Add($progressBar)
# Output Box
$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Multiline = $true
$outputBox.ScrollBars = "Vertical"
$outputBox.ReadOnly = $true
$outputBox.BackColor = "WhiteSmoke"
$outputBox.Font = New-Object System.Drawing.Font("Consolas", 9.5)
$outputBox.Size = New-Object System.Drawing.Size(440, 140)
$outputBox.Location = New-Object System.Drawing.Point(30, 440)
$form.Controls.Add($outputBox)
# ===== FUNCTION DEFINITIONS =====
function Log($msg) {
    $outputBox.AppendText("$(Get-Date -Format 'HH:mm:ss') $msg`r`n")
    $outputBox.ScrollToCaret()
}
function SetStatus($text, $color = "DarkBlue") {
    $statusLabel.Text = $text
    $statusLabel.ForeColor = $color
    $form.Refresh()
}
function ShowProgress([bool]$show) {
    $progressBar.Visible = $show
    if (-not $show) {
        $progressBar.Value = 0
        $progressBar.Style = "Continuous"
    }
    $form.Refresh()
}
# ===== Load ThreadJob (after functions are defined) =====
if (-not (Get-Command Start-ThreadJob -ErrorAction SilentlyContinue)) {
    try {
        Install-Module ThreadJob -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        Log "ThreadJob module installed successfully."
    } catch {
        Log "Warning: Could not install ThreadJob module. Using standard Start-Job."
    }
}
Import-Module ThreadJob -ErrorAction SilentlyContinue
# Timer to poll background jobs + animate progress
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1500
$timer.Add_Tick({
    if (-not $script:currentJob) { return }
    if ($script:currentJob.State -eq "Completed") {
        $output = Receive-Job $script:currentJob -ErrorAction SilentlyContinue
        Remove-Job $script:currentJob -Force -ErrorAction SilentlyContinue
        if ($output) { $output[-15..-1] | ForEach-Object { Log $_ } }
        Log "Background task finished."
        SetStatus "Task Complete - check log" "DarkGreen"
        ShowProgress $false
        $form.Cursor = "Default"
        $timer.Stop()
        $script:currentJob = $null
    }
    elseif ($script:currentJob.State -eq "Failed") {
        Log "Job failed: $($script:currentJob.Error)"
        SetStatus "Task Failed" "Red"
        ShowProgress $false
        $form.Cursor = "Default"
        $timer.Stop()
        Remove-Job $script:currentJob -Force -ErrorAction SilentlyContinue
        $script:currentJob = $null
    }
    else {
        if ($progressBar.Style -eq "Marquee") {
            $progressBar.Value = ($progressBar.Value + 5) % 105
        }
    }
})
# ===== QUICK FIX EVERYTHING =====
$btnQuickFix = New-Object System.Windows.Forms.Button
$btnQuickFix.Text = "QUICK FIX EVERYTHING (Recommended)"
$btnQuickFix.Size = New-Object System.Drawing.Size(440, 65)
$btnQuickFix.Location = New-Object System.Drawing.Point(30, 100)
$btnQuickFix.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$btnQuickFix.BackColor = [System.Drawing.Color]::LightGreen
$btnQuickFix.FlatStyle = "Flat"
$btnQuickFix.Add_Click({
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Run quick maintenance?`n`n- Clean temp files & recycle bin`n- Show heavy apps",
        "Confirm",
        "YesNo",
        "Information"
    )
    if ($confirm -ne "Yes") { return }
    $form.Cursor = "WaitCursor"
    SetStatus "Running Quick Fix..." "DarkGreen"
    ShowProgress $true
    $progressBar.Style = "Continuous"
    Log "=== Quick Fix Started ==="
    $beforeGB = (Get-PSDrive C).Free / 1GB
    Log "Cleaning temp folders..."
    $progressBar.Value = 20
    @("$env:TEMP", "$env:LOCALAPPDATA\Temp") | ForEach-Object {
        Remove-Item "$_\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    $progressBar.Value = 60
    $freedGB = [math]::Round(((Get-PSDrive C).Free / 1GB) - $beforeGB, 1)
    Log "Cleanup done - freed ~$freedGB GB"
    Log "`nTop CPU-consuming processes:"
    $progressBar.Value = 80
    Get-Process | Sort-Object CPU -Descending | Select-Object -First 4 | ForEach-Object {
        Log " $($_.ProcessName) ($([math]::Round($_.CPU,1)) sec)"
    }
    $progressBar.Value = 100
    Log "Quick Fix finished."
    SetStatus "Quick Fix Done" "DarkGreen"
    Start-Sleep -Milliseconds 800
    ShowProgress $false
    $form.Cursor = "Default"
})
$form.Controls.Add($btnQuickFix)
# ===== DEEP SYSTEM REPAIR =====
$btnRepair = New-Object System.Windows.Forms.Button
$btnRepair.Text = "Deep System Repair (DISM + SFC)"
$btnRepair.Size = New-Object System.Drawing.Size(220, 50)
$btnRepair.Location = New-Object System.Drawing.Point(30, 180)
$btnRepair.BackColor = [System.Drawing.Color]::LightGoldenrodYellow
$btnRepair.Add_Click({
    if ($script:currentJob) {
        [System.Windows.Forms.MessageBox]::Show("A repair is already running.", "Please wait", "OK", "Information")
        return
    }
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Run DISM + SFC repair in background?`n`n- Can take 10-40 min`n- Internet helpful for DISM",
        "Confirm Repair",
        "YesNo",
        "Question"
    )
    if ($confirm -ne "Yes") { return }
    $form.Cursor = "WaitCursor"
    SetStatus "Repair running in background..." "DarkOrange"
    ShowProgress $true
    $progressBar.Style = "Marquee"
    $progressBar.Value = 10
    Log "=== Deep Repair Started (background) ==="
    # Try ThreadJob first, fall back to Start-Job if module not available
    if (Get-Command Start-ThreadJob -ErrorAction SilentlyContinue) {
        $script:currentJob = Start-ThreadJob -ThrottleLimit 4 -ScriptBlock {
            $lines = @()
            $lines += "Starting DISM /RestoreHealth..."
            & DISM /Online /Cleanup-Image /RestoreHealth 2>&1 | Select-Object -Last 12 | ForEach-Object { $lines += $_ }
            $lines += "`nStarting SFC /scannow..."
            & sfc /scannow 2>&1 | Select-Object -Last 10 | ForEach-Object { $lines += $_ }
            $lines += "`nRepair sequence finished."
            $lines
        }
    } else {
        $script:currentJob = Start-Job -ScriptBlock {
            $lines = @()
            $lines += "Starting DISM /RestoreHealth..."
            & DISM /Online /Cleanup-Image /RestoreHealth 2>&1 | Select-Object -Last 12 | ForEach-Object { $lines += $_ }
            $lines += "`nStarting SFC /scannow..."
            & sfc /scannow 2>&1 | Select-Object -Last 10 | ForEach-Object { $lines += $_ }
            $lines += "`nRepair sequence finished."
            $lines
        }
    }
    $timer.Start()
})
$form.Controls.Add($btnRepair)
# ===== FREE UP SPACE =====
$btnClean = New-Object System.Windows.Forms.Button
$btnClean.Text = "Free Up Space"
$btnClean.Size = New-Object System.Drawing.Size(220, 50)
$btnClean.Location = New-Object System.Drawing.Point(260, 180)
$btnClean.BackColor = [System.Drawing.Color]::LightBlue
$btnClean.Add_Click({
    $form.Cursor = "WaitCursor"
    SetStatus "Cleaning..." "DarkBlue"
    ShowProgress $true
    $progressBar.Style = "Continuous"
    Log "Cleaning temporary files..."
    $before = (Get-PSDrive C).Free / 1GB
    $progressBar.Value = 40
    Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    $progressBar.Value = 90
    $freed = [math]::Round(((Get-PSDrive C).Free / 1GB) - $before, 1)
    Log "Cleanup complete - freed ~$freed GB"
    $progressBar.Value = 100
    Start-Sleep -Milliseconds 600
    ShowProgress $false
    SetStatus "Cleanup Done" "DarkGreen"
    $form.Cursor = "Default"
})
$form.Controls.Add($btnClean)
# ===== CHECK DISK SPACE =====
$btnDisk = New-Object System.Windows.Forms.Button
$btnDisk.Text = "Check Disk Space"
$btnDisk.Size = New-Object System.Drawing.Size(220, 45)
$btnDisk.Location = New-Object System.Drawing.Point(30, 245)
$btnDisk.Add_Click({
    Log "Disk overview:"
    Get-PSDrive -PSProvider FileSystem | ForEach-Object {
        $free = [math]::Round($_.Free/1GB,1)
        $total = [math]::Round(($_.Used + $_.Free)/1GB,1)
        Log " $($_.Name): $free GB free / $total GB total"
    }
})
$form.Controls.Add($btnDisk)
# ===== FIX INTERNET =====
$btnNet = New-Object System.Windows.Forms.Button
$btnNet.Text = "Fix Internet"
$btnNet.Size = New-Object System.Drawing.Size(220, 45)
$btnNet.Location = New-Object System.Drawing.Point(260, 245)
$btnNet.Add_Click({
    Log "Testing connection to 8.8.8.8..."
    if (Test-Connection "8.8.8.8" -Count 2 -Quiet) {
        Log "Internet connection looks good."
    } else {
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "No connection detected. Reset network stack? (requires restart)",
            "Network Fix",
            "YesNo",
            "Question"
        )
        if ($confirm -eq "Yes") {
            Log "Resetting network..."
            ipconfig /flushdns | Out-Null
            netsh winsock reset | Out-Null
            netsh int ip reset | Out-Null
            Log "Network reset complete - please restart PC."
        }
    }
})
$form.Controls.Add($btnNet)
# Clean up on form close
$form.Add_FormClosing({
    $timer.Stop()
    if ($script:currentJob) {
        Stop-Job $script:currentJob -PassThru -ErrorAction SilentlyContinue | Remove-Job -Force
    }
})
# ===== LAUNCH =====
Log "Welcome to QuickFix PC Toolkit - ready when you are!"
$form.ShowDialog() | Out-Null
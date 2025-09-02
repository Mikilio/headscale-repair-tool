# repair.ps1
# Headscale Repair Tool - PowerShell GUI version
# Requires PowerShell 7+ (used in GitHub Actions compilation)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# -------------------------------
# Configuration
# -------------------------------
$HeadscaleURL = "https://headscale.example.com"

# -------------------------------
# Auto-update via Squirrel
# -------------------------------
$updateExe = Join-Path $PSScriptRoot "Update.exe"
if (Test-Path $updateExe) {
    try {
        Start-Process -FilePath $updateExe -ArgumentList "--update" -NoNewWindow -Wait
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Update check failed: $_", "Headscale Repair")
    }
}

# -------------------------------
# Repair Function
# -------------------------------
function Repair-Tailscale {
    try {
        [System.Windows.Forms.MessageBox]::Show("Starting repair process. This may take a few minutes.", "Headscale Repair")

        # Stop Tailscale service
        Stop-Service -Name "Tailscale" -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        # Remove local data
        $tsData = "$env:LOCALAPPDATA\Tailscale"
        if (Test-Path $tsData) { Remove-Item -Recurse -Force $tsData }

        # Set registry keys for unattended mode
        $regpath = "HKLM:\Software\Tailscale IPN"
        New-Item -Path $regpath -Force | Out-Null
        Set-ItemProperty -Path $regpath -Name "UnattendedMode" -Value "always" -PropertyType String
        Set-ItemProperty -Path $regpath -Name "LoginURL" -Value $HeadscaleURL -PropertyType String

        # Download and install Tailscale if needed
        $installerUrl = "https://pkgs.tailscale.com/stable/tailscale-setup-latest-amd64.msi"
        $msi = "$env:TEMP\tailscale.msi"
        Invoke-WebRequest -Uri $installerUrl -OutFile $msi
        Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /quiet /norestart" -Wait

        # Start Tailscale to initiate login
        $tspath = "C:\Program Files (x86)\Tailscale IPN\tailscale.exe"
        if (Test-Path $tspath) {
            Start-Process -FilePath $tspath -ArgumentList "login --login-server=$HeadscaleURL"
        }

        [System.Windows.Forms.MessageBox]::Show("✅ Repair completed. Please complete login in your browser if prompted.", "Headscale Repair")
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("❌ Repair failed: $_", "Headscale Repair")
    }
}

# -------------------------------
# GUI
# -------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Headscale Repair Tool"
$form.Size = New-Object System.Drawing.Size(300,150)
$form.StartPosition = "CenterScreen"

$button = New-Object System.Windows.Forms.Button
$button.Location = New-Object System.Drawing.Point(90,40)
$button.Size = New-Object System.Drawing.Size(120,40)
$button.Text = "Repair Connection"
$button.Add_Click({ Repair-Tailscale })

$form.Controls.Add($button)
$form.Topmost = $true

[void]$form.ShowDialog()


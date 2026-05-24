Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$exe = Join-Path $PSScriptRoot 'target\release\asdbctl.exe'
if (-not (Test-Path $exe)) { $exe = 'asdbctl.exe' }

function Get-Brightness {
    $out = & $exe get 2>&1
    if ($out -match 'brightness\s+(\d+)') { return [int]$Matches[1] }
    return 50
}

function Set-Brightness([int]$v) {
    & $exe set $v 2>&1 | Out-Null
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Studio Display'
$form.Size = New-Object System.Drawing.Size(360, 130)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.TopMost = $true

$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(15, 12)
$label.Size = New-Object System.Drawing.Size(320, 22)
$label.Font = New-Object System.Drawing.Font('Segoe UI', 11)
$form.Controls.Add($label)

$bar = New-Object System.Windows.Forms.TrackBar
$bar.Location = New-Object System.Drawing.Point(10, 40)
$bar.Size = New-Object System.Drawing.Size(325, 45)
$bar.Minimum = 0
$bar.Maximum = 100
$bar.TickFrequency = 10
$bar.SmallChange = 5
$bar.LargeChange = 10
$form.Controls.Add($bar)

$current = Get-Brightness
$bar.Value = $current
$label.Text = "Brightness: $current%"

$bar.add_Scroll({ $label.Text = "Brightness: $($bar.Value)%" })
$bar.add_MouseUp({ Set-Brightness $bar.Value })
$bar.add_KeyUp({ Set-Brightness $bar.Value })

[void]$form.ShowDialog()

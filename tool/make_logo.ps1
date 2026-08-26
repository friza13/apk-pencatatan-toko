Add-Type -AssemblyName System.Drawing

$size = 1024
$bg = [System.Drawing.Brushes]::White
$black = [System.Drawing.Brushes]::Black

$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
$g.Clear([System.Drawing.Color]::White)

# --- Ring lingkaran luar (tebal) ---
$penWidth = 58
$pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black, $penWidth)
$ringRect = New-Object System.Drawing.Rectangle(60, 60, ($size-120), ($size-120))
$g.DrawEllipse($pen, $ringRect)

# --- Monogram AA (Arial Black, besar, center) ---
$aaFont = New-Object System.Drawing.Font('Arial Black', 330, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$aaSize = $g.MeasureString('AA', $aaFont)
$g.DrawString('AA', $aaFont, $black,
  (($size - $aaSize.Width) / 2) + 10, 200)

# --- Teks AUTO ABADI (serif, bawah) ---
$brandFont = New-Object System.Drawing.Font('Times New Roman', 78, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$brandSize = $g.MeasureString('AUTO ABADI', $brandFont)
$g.DrawString('AUTO ABADI', $brandFont, $black,
  ($size - $brandSize.Width) / 2, ($size - $brandSize.Height - 150))

$g.Dispose()
$dir = 'D:\file kampus\proyek ngangur\pencatatan-app-toko\assets\logo'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$bmp.Save("$dir\logo_raw.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "ICON_SAVED $dir\logo_raw.png"

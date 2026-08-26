Add-Type -AssemblyName System.Windows.Forms
$img = [System.Windows.Forms.Clipboard]::GetImage()
if ($img) {
  New-Item -ItemType Directory -Force -Path 'D:\file kampus\proyek ngangur\pencatatan-app-toko\assets\logo' | Out-Null
  $img.Save('D:\file kampus\proyek ngangur\pencatatan-app-toko\assets\logo\logo_raw.png')
  Write-Output ('SAVED ' + $img.Width + 'x' + $img.Height)
} else {
  Write-Output 'CLIPBOARD_EMPTY'
}

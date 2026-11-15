Add-Type -AssemblyName System.Drawing

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ico  = Join-Path $root "windows\runner\resources\app_icon.ico"
$out  = Join-Path $root "installer\assets"

function Add-Text($g, $text, $fontName, $style, [double]$pxSize, $color, [double]$top, [double]$width) {
  $font = New-Object System.Drawing.Font($fontName, [single]($pxSize * 0.75), $style, [System.Drawing.GraphicsUnit]::Point)
  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment = [System.Drawing.StringAlignment]::Center
  $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
  $brush = New-Object System.Drawing.SolidBrush($color)
  $rect = New-Object System.Drawing.RectangleF(0, [single]$top, [single]$width, [single]($pxSize * 1.6))
  $g.DrawString($text, $font, $brush, $rect, $fmt)
  $brush.Dispose(); $fmt.Dispose(); $font.Dispose()
}

function New-Gradient($g, $rect, $top, $bottom) {
  $b = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $top, $bottom, [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
  $g.FillRectangle($b, $rect)
  $b.Dispose()
}

function Draw-Main([double]$s) {
  $w = 164 * $s; $h = 314 * $s
  $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
  New-Gradient $g $rect ([System.Drawing.Color]::FromArgb(6, 18, 35)) ([System.Drawing.Color]::FromArgb(17, 57, 97))

  $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(13, 255, 255, 255), [single](1.1 * $s))
  $g.DrawEllipse($pen, [single](-42 * $s), [single](212 * $s), [single](172 * $s), [single](172 * $s))
  $g.DrawEllipse($pen, [single](72 * $s), [single](-64 * $s), [single](152 * $s), [single](152 * $s))
  $g.DrawEllipse($pen, [single](112 * $s), [single](142 * $s), [single](92 * $s), [single](92 * $s))
  $pen.Dispose()

  $is = [int](58 * $s)
  $ix = [int](($w - $is) / 2)
  $iy = [int](24 * $s)
  $glow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(42, 224, 164, 0))
  $g.FillEllipse($glow, [single]($ix - 13 * $s), [single]($iy - 13 * $s), [single]($is + 26 * $s), [single]($is + 26 * $s))
  $glow.Dispose()

  $icon = New-Object System.Drawing.Icon($ico, $is, $is)
  $ib = $icon.ToBitmap()
  $g.DrawImage($ib, $ix, $iy, $is, $is)
  $ib.Dispose(); $icon.Dispose()

  $gold = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(224, 164, 0))
  $lw = [int](38 * $s)
  $g.FillRectangle($gold, [int](($w - $lw) / 2), [int](96 * $s), $lw, [int](3 * $s))
  $gold.Dispose()

  Add-Text $g "KNP" "Segoe UI" ([System.Drawing.FontStyle]::Bold) (35 * $s) ([System.Drawing.Color]::White) (103 * $s) $w
  Add-Text $g "MANAGEMENT" "Segoe UI" ([System.Drawing.FontStyle]::Bold) (10.5 * $s) ([System.Drawing.Color]::FromArgb(158, 198, 235)) (151 * $s) $w
  Add-Text $g "SYSTEM" "Segoe UI" ([System.Drawing.FontStyle]::Bold) (10.5 * $s) ([System.Drawing.Color]::FromArgb(158, 198, 235)) (166 * $s) $w

  $dp = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(48, 255, 255, 255), [single](1 * $s))
  $g.DrawLine($dp, [single](30 * $s), [single](251 * $s), [single]($w - 30 * $s), [single](251 * $s))
  $dp.Dispose()

  Add-Text $g "Kabete National Polytechnic" "Segoe UI" ([System.Drawing.FontStyle]::Regular) (8.5 * $s) ([System.Drawing.Color]::FromArgb(212, 226, 241)) (255 * $s) $w
  Add-Text $g "Windows Desktop Edition" "Segoe UI" ([System.Drawing.FontStyle]::Regular) (7.5 * $s) ([System.Drawing.Color]::FromArgb(128, 168, 208)) (271 * $s) $w

  $g.Dispose()
  return $bmp
}

function Draw-Small([double]$s) {
  $w = [int][Math]::Round(55 * $s, [MidpointRounding]::AwayFromZero); $h = $w
  $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
  New-Gradient $g $rect ([System.Drawing.Color]::FromArgb(6, 18, 35)) ([System.Drawing.Color]::FromArgb(17, 57, 97))

  $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(170, 224, 164, 0), [single](1.4 * $s))
  $g.DrawRectangle($pen, [single](1.2 * $s), [single](1.2 * $s), [single]($w - 2.4 * $s), [single]($h - 2.4 * $s))
  $pen.Dispose()

  $is = [int](36 * $s)
  $ix = [int](($w - $is) / 2)
  $iy = [int](($h - $is) / 2)
  $icon = New-Object System.Drawing.Icon($ico, $is, $is)
  $ib = $icon.ToBitmap()
  $g.DrawImage($ib, $ix, $iy, $is, $is)
  $ib.Dispose(); $icon.Dispose()

  $g.Dispose()
  return $bmp
}

foreach ($s in @(1, 1.5, 2)) {
  $scale = [int]($s * 100)
  $b = Draw-Main $s
  $b.Save((Join-Path $out "wizard-$scale.bmp"), [System.Drawing.Imaging.ImageFormat]::Bmp)
  $b.Save((Join-Path $out "wizard-$scale.png"), [System.Drawing.Imaging.ImageFormat]::Png)
  $b.Dispose()

  $b = Draw-Small $s
  $b.Save((Join-Path $out "small-$scale.bmp"), [System.Drawing.Imaging.ImageFormat]::Bmp)
  $b.Save((Join-Path $out "small-$scale.png"), [System.Drawing.Imaging.ImageFormat]::Png)
  $b.Dispose()
}

Get-ChildItem $out | Select-Object Name, Length

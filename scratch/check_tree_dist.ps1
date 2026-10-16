$lines = Get-Content 'scenes/world.tscn'
$trees = @()
for ($i=0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'name="([^"]+)" parent="Forest"') {
        $name = $matches[1]
        $posLine = $lines[$i+1]
        if ($posLine -match 'position = Vector2\(([^,]+),\s*([^)]+)\)') {
            $trees += [PSCustomObject]@{ Name = $name; X = [float]$matches[1]; Y = [float]$matches[2] }
        }
    }
}

# Group trees by region (North border, South border, West border, East border, or internal)
Write-Host "North border trees (Y < 200):" ($trees | Where-Object { $_.Y -lt 200 }).Count
Write-Host "South border trees (Y > 1300):" ($trees | Where-Object { $_.Y -gt 1300 }).Count
Write-Host "West border trees (X < 200):" ($trees | Where-Object { $_.X -lt 200 }).Count
Write-Host "East border trees (X > 1800):" ($trees | Where-Object { $_.X -gt 1800 }).Count
Write-Host "Internal trees (200..1800, 200..1300):" ($trees | Where-Object { $_.X -ge 200 -and $_.X -le 1800 -and $_.Y -ge 200 -and $_.Y -le 1300 }).Count

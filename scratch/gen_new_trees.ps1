$existingTrees = @()
$lines = Get-Content 'scenes/world.tscn'
for ($i=0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'name="([^"]+)" parent="Forest"') {
        $posLine = $lines[$i+1]
        if ($posLine -match 'position = Vector2\(([^,]+),\s*([^)]+)\)') {
            $existingTrees += [PSCustomObject]@{ X = [float]$matches[1]; Y = [float]$matches[2] }
        }
    }
}
Write-Host "Existing trees: $($existingTrees.Count)"

$blockedZones = @(
    # Buildings (x1, x2, y1, y2)
    @{ Name="Castle"; Box=@(860, 1140, 220, 440) },
    @{ Name="Monastery"; Box=@(340, 560, 390, 590) },
    @{ Name="House1"; Box=@(630, 810, 450, 610) },
    @{ Name="House2"; Box=@(1190, 1370, 450, 610) },
    @{ Name="House3"; Box=@(1470, 1650, 490, 650) },
    @{ Name="Monk"; Box=@(390, 510, 600, 720) },
    @{ Name="Archer"; Box=@(1260, 1380, 600, 720) },
    @{ Name="Player"; Box=@(920, 1080, 770, 930) },
    # Corridors for enemy queues
    @{ Name="NorthCorridor"; Box=@(900, 1100, 0, 300) },
    @{ Name="SouthCorridor"; Box=@(900, 1100, 1200, 1500) },
    @{ Name="WestCorridor"; Box=@(0, 300, 650, 850) },
    @{ Name="EastCorridor"; Box=@(1700, 2000, 650, 850) },
    # Central Plaza pathway
    @{ Name="PlazaRoad"; Box=@(850, 1150, 500, 1000) }
)

function CanPlaceTree($x, $y, $treesList) {
    foreach ($bz in $blockedZones) {
        $b = $bz.Box
        if ($x -ge $b[0] -and $x -le $b[1] -and $y -ge $b[2] -and $y -le $b[3]) {
            return $false
        }
    }
    # Check distance to other trees (minimum 45 pixels to prevent direct overlapping)
    foreach ($t in $treesList) {
        $dx = $x - $t.X
        $dy = $y - $t.Y
        if (($dx*$dx + $dy*$dy) -lt (45*45)) {
            return $false
        }
    }
    return $true
}

$newTrees = @()

# 1. Northwest Grove: X in [160..400], Y in [160..380]
for ($y=180; $y -le 360; $y+=55) {
    for ($x=180; $x -le 420; $x+=55) {
        $jx = $x + (Get-Random -Minimum -10 -Maximum 10)
        $jy = $y + (Get-Random -Minimum -10 -Maximum 10)
        if (CanPlaceTree $jx $jy ($existingTrees + $newTrees)) {
            $newTrees += [PSCustomObject]@{ X = [float]$jx; Y = [float]$jy }
        }
    }
}

# 2. Northeast Grove: X in [1600..1840], Y in [160..500]
for ($y=180; $y -le 480; $y+=55) {
    for ($x=1600; $x -le 1840; $x+=55) {
        $jx = $x + (Get-Random -Minimum -10 -Maximum 10)
        $jy = $y + (Get-Random -Minimum -10 -Maximum 10)
        if (CanPlaceTree $jx $jy ($existingTrees + $newTrees)) {
            $newTrees += [PSCustomObject]@{ X = [float]$jx; Y = [float]$jy }
        }
    }
}

# 3. Southwest Woods (large): X in [180..680], Y in [860..1300]
for ($y=880; $y -le 1300; $y+=55) {
    for ($x=180; $x -le 680; $x+=55) {
        $jx = $x + (Get-Random -Minimum -10 -Maximum 10)
        $jy = $y + (Get-Random -Minimum -10 -Maximum 10)
        if (CanPlaceTree $jx $jy ($existingTrees + $newTrees)) {
            $newTrees += [PSCustomObject]@{ X = [float]$jx; Y = [float]$jy }
        }
    }
}

# 4. Southeast Woods (large): X in [1320..1840], Y in [860..1300]
for ($y=880; $y -le 1300; $y+=55) {
    for ($x=1320; $x -le 1840; $x+=55) {
        $jx = $x + (Get-Random -Minimum -10 -Maximum 10)
        $jy = $y + (Get-Random -Minimum -10 -Maximum 10)
        if (CanPlaceTree $jx $jy ($existingTrees + $newTrees)) {
            $newTrees += [PSCustomObject]@{ X = [float]$jx; Y = [float]$jy }
        }
    }
}

# 5. North-Center Left woods (between Monastery and Castle): X in [560..800], Y in [200..380]
for ($y=200; $y -le 380; $y+=55) {
    for ($x=560; $x -le 800; $x+=55) {
        $jx = $x + (Get-Random -Minimum -10 -Maximum 10)
        $jy = $y + (Get-Random -Minimum -10 -Maximum 10)
        if (CanPlaceTree $jx $jy ($existingTrees + $newTrees)) {
            $newTrees += [PSCustomObject]@{ X = [float]$jx; Y = [float]$jy }
        }
    }
}

# 6. North-Center Right woods (between Castle and House2): X in [1200..1440], Y in [200..380]
for ($y=200; $y -le 380; $y+=55) {
    for ($x=1200; $x -le 1440; $x+=55) {
        $jx = $x + (Get-Random -Minimum -10 -Maximum 10)
        $jy = $y + (Get-Random -Minimum -10 -Maximum 10)
        if (CanPlaceTree $jx $jy ($existingTrees + $newTrees)) {
            $newTrees += [PSCustomObject]@{ X = [float]$jx; Y = [float]$jy }
        }
    }
}

# 7. Dense outer perimeter additions (deepening the forest):
for ($x=60; $x -le 860; $x+=60) {
    $jx = $x
    $jy = 10
    if (CanPlaceTree $jx $jy ($existingTrees + $newTrees)) {
        $newTrees += [PSCustomObject]@{ X = [float]$jx; Y = [float]$jy }
    }
}
for ($x=1140; $x -le 1940; $x+=60) {
    $jx = $x
    $jy = 10
    if (CanPlaceTree $jx $jy ($existingTrees + $newTrees)) {
        $newTrees += [PSCustomObject]@{ X = [float]$jx; Y = [float]$jy }
    }
}

Write-Host "New trees generated: $($newTrees.Count)"

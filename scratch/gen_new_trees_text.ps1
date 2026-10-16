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

$blockedZones = @(
    # Buildings & NPCs & Player
    @{ Name="Castle"; Box=@(860, 1140, 220, 440) },
    @{ Name="Monastery"; Box=@(340, 560, 390, 590) },
    @{ Name="House1"; Box=@(630, 810, 450, 610) },
    @{ Name="House2"; Box=@(1190, 1370, 450, 610) },
    @{ Name="House3"; Box=@(1470, 1650, 490, 650) },
    @{ Name="Monk"; Box=@(390, 510, 600, 720) },
    @{ Name="Archer"; Box=@(1260, 1380, 600, 720) },
    @{ Name="Player"; Box=@(900, 1100, 750, 950) },
    # Corridors for enemy straight-line queues
    @{ Name="NorthCorridor"; Box=@(890, 1110, 0, 300) },
    @{ Name="SouthCorridor"; Box=@(890, 1110, 1200, 1500) },
    @{ Name="WestCorridor"; Box=@(0, 300, 650, 850) },
    @{ Name="EastCorridor"; Box=@(1700, 2000, 650, 850) },
    # Central Plaza Roadway
    @{ Name="PlazaRoad"; Box=@(850, 1150, 500, 1000) }
)

function CanPlaceTree($x, $y, $treesList) {
    foreach ($bz in $blockedZones) {
        $b = $bz.Box
        if ($x -ge $b[0] -and $x -le $b[1] -and $y -ge $b[2] -and $y -le $b[3]) {
            return $false
        }
    }
    foreach ($t in $treesList) {
        $dx = $x - $t.X
        $dy = $y - $t.Y
        if (($dx*$dx + $dy*$dy) -lt (48*48)) {
            return $false
        }
    }
    return $true
}

$newTrees = @()

# 1. Northwest Grove
for ($y=180; $y -le 360; $y+=55) {
    for ($x=180; $x -le 420; $x+=55) {
        $jx = $x + (Get-Random -Minimum -10 -Maximum 10)
        $jy = $y + (Get-Random -Minimum -10 -Maximum 10)
        if (CanPlaceTree $jx $jy ($existingTrees + $newTrees)) {
            $newTrees += [PSCustomObject]@{ X = [float]$jx; Y = [float]$jy }
        }
    }
}

# 2. Northeast Grove
for ($y=180; $y -le 480; $y+=55) {
    for ($x=1600; $x -le 1840; $x+=55) {
        $jx = $x + (Get-Random -Minimum -10 -Maximum 10)
        $jy = $y + (Get-Random -Minimum -10 -Maximum 10)
        if (CanPlaceTree $jx $jy ($existingTrees + $newTrees)) {
            $newTrees += [PSCustomObject]@{ X = [float]$jx; Y = [float]$jy }
        }
    }
}

# 3. Southwest Woods
for ($y=880; $y -le 1300; $y+=55) {
    for ($x=180; $x -le 680; $x+=55) {
        $jx = $x + (Get-Random -Minimum -10 -Maximum 10)
        $jy = $y + (Get-Random -Minimum -10 -Maximum 10)
        if (CanPlaceTree $jx $jy ($existingTrees + $newTrees)) {
            $newTrees += [PSCustomObject]@{ X = [float]$jx; Y = [float]$jy }
        }
    }
}

# 4. Southeast Woods
for ($y=880; $y -le 1300; $y+=55) {
    for ($x=1320; $x -le 1840; $x+=55) {
        $jx = $x + (Get-Random -Minimum -10 -Maximum 10)
        $jy = $y + (Get-Random -Minimum -10 -Maximum 10)
        if (CanPlaceTree $jx $jy ($existingTrees + $newTrees)) {
            $newTrees += [PSCustomObject]@{ X = [float]$jx; Y = [float]$jy }
        }
    }
}

# 5. Deep outer border enhancements
for ($x=60; $x -le 860; $x+=55) {
    $jx = $x
    $jy = 10
    if (CanPlaceTree $jx $jy ($existingTrees + $newTrees)) {
        $newTrees += [PSCustomObject]@{ X = [float]$jx; Y = [float]$jy }
    }
}
for ($x=1140; $x -le 1940; $x+=55) {
    $jx = $x
    $jy = 10
    if (CanPlaceTree $jx $jy ($existingTrees + $newTrees)) {
        $newTrees += [PSCustomObject]@{ X = [float]$jx; Y = [float]$jy }
    }
}
for ($x=60; $x -le 860; $x+=55) {
    $jx = $x
    $jy = 1485
    if (CanPlaceTree $jx $jy ($existingTrees + $newTrees)) {
        $newTrees += [PSCustomObject]@{ X = [float]$jx; Y = [float]$jy }
    }
}
for ($x=1140; $x -le 1940; $x+=55) {
    $jx = $x
    $jy = 1485
    if (CanPlaceTree $jx $jy ($existingTrees + $newTrees)) {
        $newTrees += [PSCustomObject]@{ X = [float]$jx; Y = [float]$jy }
    }
}

Write-Host "Total new trees to add: $($newTrees.Count)"

# Output nodes text
$out = @()
$idx = 117
foreach ($t in $newTrees) {
    $out += "[node name=`"Tree$idx`" parent=`"Forest`" instance=ExtResource(`"7_tree_scene`")]"
    $out += "position = Vector2($($t.X), $($t.Y))`n"
    $idx++
}

$targetPath = Join-Path $PWD "scratch/new_trees.txt"
$outText = $out -join "`n"
[IO.File]::WriteAllText($targetPath, $outText)
Write-Host "Wrote scratch/new_trees.txt with $($newTrees.Count) trees."



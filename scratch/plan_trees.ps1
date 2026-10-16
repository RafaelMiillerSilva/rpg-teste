# Script to plan new tree clusters in empty areas
$buildings = @(
    @{ Name = "Castle"; Box = @(820, 1180, 240, 440) },
    @{ Name = "Monastery"; Box = @(350, 550, 420, 600) },
    @{ Name = "House1"; Box = @(650, 790, 480, 600) },
    @{ Name = "House2"; Box = @(1210, 1350, 480, 600) },
    @{ Name = "House3"; Box = @(1490, 1630, 520, 640) },
    @{ Name = "Monk"; Box = @(400, 500, 620, 700) },
    @{ Name = "Archer"; Box = @(1270, 1370, 620, 700) },
    @{ Name = "Player"; Box = @(940, 1060, 800, 900) },
    # Corridors
    @{ Name = "GateNorthCorridor"; Box = @(880, 1120, 0, 450) },
    @{ Name = "GateSouthCorridor"; Box = @(880, 1120, 1100, 1500) },
    @{ Name = "GateWestCorridor"; Box = @(0, 360, 650, 850) },
    @{ Name = "GateEastCorridor"; Box = @(1640, 2000, 650, 850) },
    @{ Name = "CentralPlaza"; Box = @(750, 1250, 650, 1050) }
)

function IsBlocked($x, $y) {
    foreach ($b in $buildings) {
        $box = $b.Box
        if ($x -ge $box[0] -and $x -le $box[1] -and $y -ge $box[2] -and $y -le $box[3]) {
            return $true
        }
    }
    return $false
}

# Test empty regions:
# Region 1: Northwest grove (X: 180..380, Y: 180..380)
# Region 2: Northeast grove (X: 1620..1820, Y: 180..450)
# Region 3: Southwest woods (X: 180..650, Y: 880..1300)
# Region 4: Southeast woods (X: 1350..1820, Y: 880..1300)
# Region 5: Thicker North border (Y: 60..150, X: 160..860 and 1140..1840)
# Region 6: Thicker South border (Y: 1350..1440, X: 160..860 and 1140..1840)

Write-Host "Northwest Grove test (250, 250): blocked=" (IsBlocked 250 250)
Write-Host "Southwest Woods test (350, 1050): blocked=" (IsBlocked 350 1050)
Write-Host "Southeast Woods test (1550, 1050): blocked=" (IsBlocked 1550 1050)
Write-Host "Central Plaza test (1000, 850): blocked=" (IsBlocked 1000 850)

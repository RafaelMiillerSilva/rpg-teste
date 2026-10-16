$worldText = [IO.File]::ReadAllText("$PWD/scenes/world.tscn")
$newTreesText = [IO.File]::ReadAllText("$PWD/scratch/new_trees.txt")

$target = @"
[node name="Tree116" parent="Forest" instance=ExtResource("7_tree_scene")]
position = Vector2(1960, 1305)
"@

if ($worldText.Contains($target)) {
    $replacement = @"
$target

$newTreesText
"@
    $updatedWorld = $worldText.Replace($target, $replacement)
    [IO.File]::WriteAllText("$PWD/scenes/world.tscn", $updatedWorld)
    Write-Host "Successfully inserted new trees into scenes/world.tscn!"
} else {
    Write-Host "Error: target Tree116 not found in scenes/world.tscn!"
}

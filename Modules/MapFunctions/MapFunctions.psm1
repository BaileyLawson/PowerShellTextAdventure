function New-Map {
    <#
    .NOTES
        Each map point follows the syntax @(@(Item(s)), Path, Discovered)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Int]
        $MapWidth = 10,
        [Parameter(Mandatory = $false)]
        [Int]
        $MapHeight = 10,
        [Parameter(Mandatory = $false)]
        [Int]
        $Randomness = 3
    )

    process {
        # Define empty map
        $global:Map = New-Object -TypeName "Array[,]" -ArgumentList $MapWidth, $MapHeight
        Write-Verbose -Message "Created map with dimensions $MapWidth x $MapHeight"

        # Create Map Key and Quantities
        $MapKey = @{
            Chest    = @("C", (Get-Random -Minimum 1 -Maximum (($MapWidth * $MapHeight) / (($MapWidth + $MapHeight) / 2))))
            Exit     = @("X", 1)
            Entrance = @("N", 1)
            Player   = @("P", 0) # Set to 0 as player is populated later
            Enemy    = @("E", 0) # Set to 0 as enemies are random events
            Wall     = @("W", 0) # Set to 0 as walls are created later
        }

        # Populate the map
        Write-Verbose -Message "Placing items on map"
        foreach ($Item in $MapKey.Keys) {
            for ($Count = 0; $Count -lt $MapKey[$Item][1]; $Count++) {
                $Placed = $false
                while ($Placed -ne $true) {
                    # Get coordinates
                    $XCoord = Get-Random -Minimum 0 -Maximum ($MapWidth - 1)
                    $YCoord = Get-Random -Minimum 0 -Maximum ($MapHeight - 1)

                    # Attempt to place item
                    if (-not $global:Map[$XCoord, $YCoord]) {
                        $global:Map[$XCoord, $YCoord] = @(@($MapKey[$Item][0]), 1, 0)
                        if ($Item -eq "Entrance") {
                            $EntranceLocation = @($XCoord, $YCoord)
                        }
                        $Placed = $true
                        Write-Debug -Message "Placed $Item at co-ordinate $XCoord, $YCoord"
                    }
                }
            }
        }

        # Place path between entrance and exit
        Write-Verbose -Message "Generating Paths"
        New-MapPaths -Randomness $Randomness

        # Fill in non-path blocks with walls
        Write-Verbose -Message "Generating Walls"
        New-MapWalls

        # Place player at entrance
        $global:Map[$EntranceLocation] = @((@("P") + $global:Map[$EntranceLocation][0]), $global:Map[$EntranceLocation][1], $global:Map[$EntranceLocation][2])

        # Clear fog of war around player
        Clear-FogOfWar -FogClearRadius 1
    }
}


function Write-Map {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Switch]
        $IgnoreFog
    )

    process {
        # Retrieve map height and width from map array
        $MapSize = @($global:Map.GetLength(0), $global:Map.GetLength(1))

        # Define common lines
        $Border = "+" + ("-------+" * $MapSize[0])

        for ($YCoord = 0; $YCoord -lt $MapSize[1]; $YCoord++) {
            if ($YCoord -eq 0) {
                Write-Output -InputObject $Border
            }

            $Line1 = "|"; $Line2 = "|"; $Line3 = "|"
            for ($XCoord = 0; $XCoord -lt $MapSize[0]; $XCoord++) {
                if ((($global:Map[$XCoord, $YCoord])[2] -eq 1) -or $IgnoreFog) {
                    if (($global:Map[$XCoord, $YCoord])[0][0] -eq "W") {
                        $Line1 += "WWWWWWW|"; $Line2 += "WWWWWWW|"; $Line3 += "WWWWWWW|"
                    }
                    else {
                        $Line1 += "       |"
                        $Line2 += "   " + ($global:Map[$XCoord, $YCoord])[0][0] + "   |"
                        $Line3 += "       |"
                    }
                }
                else {
                    $Line1 += "F F F F|"; $Line2 += "F F F F|"; $Line3 += "F F F F|"
                }
            }

            Write-Output -InputObject $Line1
            Write-Output -InputObject $Line2
            Write-Output -InputObject $Line3
            Write-Output -InputObject $Border
        }
    }
}


function Write-Minimap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateScript( { if (($_ % 2) -eq 0) {$true} else {$false} })]
        [Int]
        $MiniMapWidth = 3,
        [Parameter(Mandatory = $false)]
        [ValidateScript( { if (($_ % 2) -eq 0) {$true} else {$false} })]
        [Int]
        $MiniMapHeight = 3,
        [Parameter(Mandatory = $false)]
        [Switch]
        $IgnoreFog
    )

    process {
        # Retrieve map height and width from map array
        $MapSize = @($global:Map.GetLength(0), $global:Map.GetLength(1))

        # Get player location
        $PlayerLocation = Find-Player

        # Define minimap boundaries
        $MinimapLeftBoundary = $PlayerLocation[0] - (($MiniMapWidth - 1) / 2)
        $MiniMapRightBoundary = $PlayerLocation[0] + (($MiniMapWidth - 1) / 2)
        $MiniMapTopBoundary = $PlayerLocation[1] - (($MiniMapHeight - 1) / 2)
        $MiniMapBottomBoundary = $PlayerLocation[1] + (($MiniMapHeight - 1) / 2)

        # Validate if the player is at the edge of the map
        ## X-Axis validation
        if ($MinimapLeftBoundary -lt 0) {
            while ($MinimapLeftBoundary -lt 0) {
                $MinimapLeftBoundary++
                $MiniMapRightBoundary++
            }
        }
        elseif ($MiniMapRightBoundary -gt $MapSize[0]) {
            while ($MiniMapRightBoundary -gt $MapSize[0]) {
                $MiniMapLeftBoundary--
                $MiniMapRightBoundary--
            }
        }

        ## Y-Axis Validation
        if ($MinimapTopBoundary -lt 0) {
            while ($MinimapTopBoundary -lt 0) {
                $MinimapTopBoundary++
                $MiniMapBottomBoundary++
            }
        }
        elseif ($MiniMapBottomBoundary -gt $MapSize[1]) {
            while ($MiniMapBottomBoundary -gt $MapSize[1]) {
                $MiniMapTopBoundary--
                $MiniMapBottomBoundary--
            }
        }

        # Define border line
        $Border = "+" + ("-------+" * $MiniMapWidth)

        # Print minimap
        for ($YCoord = $MiniMapTopBoundary; $YCoord -le $MiniMapBottomBoundary; $YCoord++) {
            if ($YCoord -eq $MiniMapTopBoundary) {
                Write-Output -InputObject $Border
            }

            $Line1 = "|"; $Line2 = "|"; $Line3 = "|"
            for ($XCoord = $MinimapLeftBoundary; $XCoord -le $MiniMapRightBoundary; $XCoord++) {
                if (($global:Map[$XCoord, $YCoord])[0][0] -eq "W") {
                    $Line1 += "WWWWWWW|"; $Line2 += "WWWWWWW|"; $Line3 += "WWWWWWW|"
                }
                else {
                    $Line1 += "       |"
                    $Line2 += "   " + ($global:Map[$XCoord, $YCoord])[0][0] + "   |"
                    $Line3 += "       |"
                }
            }
            Write-Output -InputObject $Line1
            Write-Output -InputObject $Line2
            Write-Output -InputObject $Line3
            Write-Output -InputObject $Border
        }
    }
}

function New-MapPaths {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Int]
        $Randomness
    )

    process {
        # Retrieve map height and width from map array
        $MapSize = @($global:Map.GetLength(0), $global:Map.GetLength(1))

        # Locate entrance and exit
        for ($YCoord = 0; $YCoord -lt $MapSize[1]; $YCoord++) {
            for ($XCoord = 0; $XCoord -lt $MapSize[0]; $XCoord++) {
                if ($global:Map[$XCoord, $YCoord]) {
                    # Locate Entrance/PathStart
                    if ($global:Map[$XCoord, $YCoord][0][0] -eq "N") {
                        $PathCoord = @($XCoord, $YCoord)
                    }
                    # Locate Exit/PathEnd
                    elseif ($global:Map[$XCoord, $YCoord][0][0] -eq "X") {
                        $ExitLocation = @($XCoord, $YCoord)
                    }
                }
            }
            if ($PathCoord -and $ExitLocation) {
                break
            }
        }

        # A poor attempt at an imperfect path-finding algorithm
        while ($PathCoord[0] -ne $ExitLocation[0] -or $PathCoord[1] -ne $ExitLocation[1]) {
            # Find perfect path
            $Diff = @(($PathCoord[0] - $ExitLocation[0]), ($PathCoord[1] - $ExitLocation[1]))
            Write-Debug -Message "Current diff is: $Diff"

            # Randomise axis to move in
            $AxisToMove = Get-Random -Minimum 0 -Maximum 2

            # Randomise amount to move
            if ($Diff[$AxisToMove] -gt 0) {
                $DistanceToMove = Get-Random -Minimum (0 - ($Randomness * 2)) -Maximum (0 + $Randomness)
            }
            elseif ($Diff[$AxisToMove] -lt 0) {
                $DistanceToMove = Get-Random -Minimum (0 - $Randomness / 2) -Maximum (0 + ($Randomness * 2))
            }
            else {
                $DistanceToMove = Get-Random -Minimum (0 - $Randomness) -Maximum (0 + $Randomness)
            }

            if (-not (($PathCoord[$AxisToMove] + $DistanceToMove) -ge $MapSize[$AxisToMove] -or ($PathCoord[$AxisToMove] + $DistanceToMove) -lt 0)) {
                Write-Debug -Message "Moving $DistanceToMove on axis $AxisToMove from $PathCoord"
                # Place "Path" entries along route
                if ($DistanceToMove -gt 0) {
                    Write-Debug -Message "Moving positively along axis"
                    $PathCoord[$AxisToMove] = $PathCoord[$AxisToMove] + 1
                    for ($Count = 0; $Count -lt $DistanceToMove; $Count++) {
                        if (-not $global:Map[$PathCoord]) {
                            $global:Map[$PathCoord] = @(@(" "), 1, 0)
                            Write-Debug -Message "Placed path at co-ordinate $($PathCoord[0]), $($PathCoord[1])"
                        }
                        elseif ($global:Map[$PathCoord][0][0] -eq "N") {
                            break
                        }
                    }
                }
                elseif ($DistanceToMove -lt 0) {
                    Write-Debug -Message "Moving negatively along axis"
                    $PathCoord[$AxisToMove] = $PathCoord[$AxisToMove] - 1
                    for ($Count = 0; $Count -gt $DistanceToMove; $Count--) {
                        if (-not $global:Map[$PathCoord]) {
                            $global:Map[$PathCoord] = @(@(" "), 1, 0)
                            Write-Debug -Message "Placed path at co-ordinate $($PathCoord[0]), $($PathCoord[1])"
                        }
                        elseif ($global:Map[$PathCoord][0][0] -eq "N") {
                            break
                        }
                    }
                }
            }
        }
        Write-Debug -Message "Path ends: $PathCoord. Exit at: $ExitLocation"
    }
}

function New-MapWalls {
    [CmdletBinding()]
    param()

    process {
        # Retrieve map height and width from map array
        $MapSize = @($global:Map.GetLength(0), $global:Map.GetLength(1))

        for ($YCoord = 0; $YCoord -lt $MapSize[1]; $YCoord++) {
            for ($XCoord = 0; $XCoord -lt $MapSize[0]; $XCoord++) {
                if (-not $global:Map[$XCoord, $YCoord]) {
                    $global:Map[$XCoord, $YCoord] = @(@("W"), 0, 0)
                }
            }
        }
    }
}


function Clear-FogOfWar {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [Int]
        $FogClearRadius = 1,
        [Parameter(Mandatory = $false)]
        [Object[]]
        $PassedLocation
    )

    process {
        # Retrieve map height and width from map array
        $MapSize = @($global:Map.GetLength(0), $global:Map.GetLength(1))

        if ($PassedLocation) {
            $PlayerLocation = $PassedLocation
        }
        else {
            # Get player location
            $PlayerLocation = Find-Player
        }

        # Define fog clearing boundary
        $FogLeftBoundary = $PlayerLocation[0] - $FogClearRadius
        $FogRightBoundary = $PlayerLocation[0] + $FogClearRadius
        $FogTopBoundary = $PlayerLocation[1] - $FogClearRadius
        $FogBottomBoundary = $PlayerLocation[1] + $FogClearRadius

        # Clear fog around player
        for ($YCoord = $FogTopBoundary; $YCoord -le $FogBottomBoundary; $YCoord++) {
            for ($XCoord = $FogLeftBoundary; $XCoord -le $FogRightBoundary; $XCoord++) {
                if (-not (($XCoord -lt 0 -or $XCoord -ge $MapSize[0]) -or ($YCoord -lt 0 -or $YCoord -ge $MapSize[1]))) {
                    if (($global:Map[$XCoord, $YCoord])[2] -eq "0") {
                        $global:Map[$XCoord, $YCoord] = @($global:Map[$XCoord, $YCoord][0], $global:Map[$XCoord, $YCoord][1], 1)
                        Write-Debug -Message "Fog cleared at Coordinates $XCoord, $YCoord"
                    }
                }
            }
        }
    }
}


function Find-Player {
    [CmdletBinding()]
    param ()

    process {
        # Retrieve map height and width from map array
        $MapSize = @($global:Map.GetLength(0), $global:Map.GetLength(1))

        # Locate player on map
        for ($YCoord = 0; $YCoord -lt $MapSize[1]; $YCoord++) {
            for ($XCoord = 0; $XCoord -lt $MapSize[0]; $XCoord++) {
                if ($global:Map[$XCoord, $YCoord][0][0] -eq "P") {
                    $PlayerLocation = @($XCoord, $YCoord)
                    break
                }
            }
            if ($PlayerLocation) {
                break
            }
        }
        return $PlayerLocation
    }
}


function Move-Player {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Up", "Down", "Left", "Right")]
        [String]
        $Direction
    )

    process {
        # Retrieve map height and width from map array
        $MapSize = @($global:Map.GetLength(0), $global:Map.GetLength(1))

        # Get player location
        $PlayerLocation = Find-Player

        # Validate if the player can move to that space
        switch ($Direction) {
            "Left" { $AxisToMove = 0; $Distance = -1 }
            "Right" { $AxisToMove = 0; $Distance = 1 }
            "Up" { $AxisToMove = 1; $Distance = -1 }
            "Down" { $AxisToMove = 1; $Distance = 1 }
        }
        Write-Debug -Message "Moving $Distance on axis $AxisToMove"

        # Calculate the new location for the player
        $NewPlayerLocation = @($PlayerLocation[0], $PlayerLocation[1])
        $NewPlayerLocation[$AxisToMove] += $Distance

        if (($NewPlayerLocation[$AxisToMove] -lt 0) -or ($NewPlayerLocation[$AxisToMove] -ge $MapSize[$AxisToMove])) {
            Write-Output -InputObject "Can't move outside of the map edge..."
        }
        elseif ($global:Map[$NewPlayerLocation][0][0] -eq "W") {
            Write-Output -InputObject "Can't move through walls.... You're not a ghost...."
        }
        else {
            # Set new player location
            $global:Map[$NewPlayerLocation] = @((@("P") + $global:Map[$NewPlayerLocation][0]), $global:Map[$NewPlayerLocation][1], $global:Map[$NewPlayerLocation][2])
            Write-Debug -Message "Moved player to co-ordinates $($NewPlayerLocation[0]), $($NewPlayerLocation[1])"

            # Remove player from previous location
            $global:Map[$PlayerLocation] = @($global:Map[$PlayerLocation][0][1..-1], $global:Map[$PlayerLocation][1], $global:Map[$PlayerLocation][2])
            Write-Debug -Message "Removed player from co-ordinates $($PlayerLocation[0]), $($PlayerLocation[1])"

            # Clear fog of war around new player location
            Clear-FogOfWar -FogClearRadius 1 -PassedLocation $NewPlayerLocation
        }
    }
}

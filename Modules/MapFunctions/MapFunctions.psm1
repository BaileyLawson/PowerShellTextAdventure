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
        $MapHeight = 10
    )

    process {
        # Define empty map
        $global:Map = New-Object -TypeName "Array[,]" -ArgumentList $MapWidth, $MapHeight
        Write-Verbose -Message "Created map with dimensions $MapWidth x $MapHeight"

        # Create Map Key and Quantities
        $MapKey = @{
            Chest    = @("C", (Get-Random -Minimum 1 -Maximum 3))
            Exit     = @("X", 1)
            Entrance = @("N", 1)
            Player   = @("P", 0) # Set to 0 as player is populated later
            Enemy    = @("E", (Get-Random -Minimum 4 -Maximum 10))
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

        Write-Verbose -Message "Generating Paths"
        New-MapPaths

        Write-Verbose -Message "Generating Walls"
        New-MapWalls

        # Place player at entrance
        $global:Map[$EntranceLocation[0], $EntranceLocation[1]] = @((@("P") + ($global:Map[$EntranceLocation[0], $EntranceLocation[1]])[0]), ($global:Map[$EntranceLocation[0], $EntranceLocation[1]])[1], ($global:Map[$EntranceLocation[0], $EntranceLocation[1]])[2])
    }
}


function Write-Map {
    [CmdletBinding()]
    param()

    process {
        # Retrieve map height and width from map array
        $MapWidth = $global:Map.GetLength(0)
        $MapHeight = $global:Map.GetLength(1)

        # Define common lines
        $Border = "+" + ("-------+" * $MapWidth)
        $EmptyLine = "|" + ("       |" * $MapWidth)

        for ($YCoord = 0; $YCoord -lt $MapHeight; $YCoord++) {
            if ($YCoord -eq 0) {
                Write-Output -InputObject $Border
                Write-Output -InputObject $EmptyLine
            }
            $Line = "|"
            for ($XCoord = 0; $XCoord -lt $MapWidth; $XCoord++) {
                $Line += "   " + ($global:Map[$XCoord, $YCoord])[0][0] + "   |"
            }
            Write-Output -InputObject $Line
            if ($YCoord -ne ($MapWidth - 1)) {
                Write-Output -InputObject $EmptyLine
                Write-Output -InputObject $Border
                Write-Output -InputObject $EmptyLine
            }
            else {
                Write-Output -InputObject $EmptyLine
                Write-Output -InputObject $Border
            }
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
        $MiniMapHeight = 3
    )

    process {
        # Retrieve map height and width from map array
        $MapWidth = $global:Map.GetLength(0)
        $MapHeight = $global:Map.GetLength(1)

        # Locate player on map
        for ($YCoord = 0; $YCoord -lt $MapHeight; $YCoord++) {
            for ($XCoord = 0; $XCoord -lt $MapWidth; $XCoord++) {
                if ($global:Map[$XCoord, $YCoord][0][0] -eq "P") {
                    $PlayerLocation = @($XCoord, $YCoord)
                    break
                }
            }
            if ($PlayerLocation) {
                break
            }
        }

        # Define minimap boundaries
        $MinimapLeftBoundary = $XCoord - (($MiniMapWidth - 1) / 2)
        $MiniMapRightBoundary = $XCoord + (($MiniMapWidth - 1) / 2)
        $MiniMapTopBoundary = $YCoord - (($MiniMapHeight - 1) / 2)
        $MiniMapBottomBoundary = $YCoord + (($MiniMapHeight - 1) / 2)

        # Validate if the player is at the edge of the map
        ## X-Axis validation
        if ($MinimapLeftBoundary -lt 0) {
            while ($MinimapLeftBoundary -lt 0) {
                $MinimapLeftBoundary++
                $MiniMapRightBoundary++
            }
        }
        elseif ($MiniMapRightBoundary -gt $MapWidth) {
            while ($MiniMapRightBoundary -gt $MapWidth) {
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
        elseif ($MiniMapBottomBoundary -gt $MapWidth) {
            while ($MiniMapBottomBoundary -gt $MapWidth) {
                $MiniMapTopBoundary--
                $MiniMapBottomBoundary--
            }
        }

        # Define common lines
        $Border = "+" + ("-------+" * $MiniMapWidth)
        $EmptyLine = "|" + ("       |" * $MiniMapWidth)

        # Print minimap
        for ($YCoord = $MiniMapTopBoundary; $YCoord -le $MiniMapBottomBoundary; $YCoord++) {
            if ($YCoord -eq $MiniMapTopBoundary) {
                Write-Output -InputObject $Border
                Write-Output -InputObject $EmptyLine
            }
            $Line = "|"
            for ($XCoord = $MinimapLeftBoundary; $XCoord -le $MiniMapRightBoundary; $XCoord++) {
                $Line += "   " + ($global:Map[$XCoord, $YCoord])[0][0] + "   |"
            }
            Write-Output -InputObject $Line
            if ($YCoord -ne ($MiniMapBottomBoundary)) {
                Write-Output -InputObject $EmptyLine
                Write-Output -InputObject $Border
                Write-Output -InputObject $EmptyLine
            }
            else {
                Write-Output -InputObject $EmptyLine
                Write-Output -InputObject $Border
            }
        }
    }
}

function New-MapPaths {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Int]
        $Randomness = 3
    )

    process {
        # Retrieve map height and width from map array
        $MapSize = @($global:Map.GetLength(0), $global:Map.GetLength(1))

        # Locate player and exit
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
                $DistanceToMove = Get-Random -Minimum (0 - ($Randomness * 2)) -Maximum (0 + [Int]($Randomness / 2))
            }
            elseif ($Diff[$AxisToMove] -lt 0) {
                $DistanceToMove = Get-Random -Minimum (0 - [Int]($Randomness / 2)) -Maximum (0 + ($Randomness * 2))
            }
            else {
                $DistanceToMove = Get-Random -Minimum (0 - [Int]($Randomness / 3)) -Maximum (0 + [Int]($Randomness / 3))
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
        $MapWidth = $global:Map.GetLength(0)
        $MapHeight = $global:Map.GetLength(1)

        for ($YCoord = 0; $YCoord -lt $MapHeight; $YCoord++) {
            for ($XCoord = 0; $XCoord -lt $MapWidth; $XCoord++) {
                if (-not $global:Map[$XCoord, $YCoord]) {
                    $global:Map[$XCoord, $YCoord] = @(@("W"), 0, 0)
                }
            }
        }
    }
}

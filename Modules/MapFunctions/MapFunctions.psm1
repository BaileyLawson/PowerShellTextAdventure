function New-Map {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [Int]
        $MapWidth = 20,
        [Parameter(Mandatory = $false)]
        [Int]
        $MapHeight = 20
    )

    process {
        # Define empty map
        $global:Map = New-Object -TypeName "Char[,]" -ArgumentList $MapWidth, $MapHeight
        Write-Verbose -Message "Created map with dimensions $MapWidth x $MapHeight"

        # Create Map Key and Quantities
        $MapKey = @{
            Chest = @("C", (Get-Random -Minimum 1 -Maximum 3))
            Exit = @("X", 1)
            Entrance = @("N", 1)
            Player = @("P", 0) # Set to 0 as player is populated later
            Enemy = @("E", (Get-Random -Minimum 4 -Maximum 10))
        }

        # Populate the map
        foreach ($Item in $MapKey.Keys) {
            for ($Count = 0; $Count -lt $MapKey[$Item][1]; $Count++) {
                $Placed = $false
                while ($Placed -ne $true) {
                    # Get coordinates
                    $XCoord = Get-Random -Minimum 0 -Maximum ($MapWidth-1)
                    $YCoord = Get-Random -Minimum 0 -Maximum ($MapHeight-1)

                    # Attempt to place item
                    if (-not $global:Map[$XCoord, $YCoord]) {
                        $global:Map[$XCoord, $YCoord] = $MapKey[$Item][0]
                        $Placed = $true
                        Write-Verbose -Message "Placed $Item at co-ordinate $XCoord, $YCoord"
                    }
                }
            }
        }
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
                    if (-not $global:Map[$XCoord, $YCoord]) {
                        $Line += "       |"
                    }
                    else {
                        $Line += "   " + $global:Map[$XCoord, $YCoord] + "   |"
                    }
                }
                Write-Output -InputObject $Line
                if ($YCoord -ne ($MapWidth-1)) {
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


<#
+-------+
|       |
|   X   |
|       |
+-------+
7(9) across
3(5) Down



#>
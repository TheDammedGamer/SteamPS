function Update-SteamWorkshopMods {
    <#
    .SYNOPSIS
    Installs or Updates Steam Workshop Mods.

    .DESCRIPTION
    Installs or Updates Steam Workshop Mods.

    .PARAMETER ApplicationName
    Enter the name of the app to make a wildcard search for the application.

    .PARAMETER AppID
    Enter the application ID you wish to install mods for.

    .PARAMETER Credential
    If the app requires login to install or update, enter your Steam username and password.

    .PARAMETER Path
    Path to installation folder.

    .PARAMETER Force
    The Force parameter allows the user to skip the "Should Continue" box.

    .EXAMPLE
    $cred = Get-Credential
    Update-SteamWorkshopMod -AppID 2111820 -ModIds @(729480149,763259329,1102394541,1218671249,731220462) -Credential $cred -Path 'C:\Servers\Starbound'

    Downloads the Starbound Mods specified
    .EXAMPLE
    $cred = Get-Credential
    Update-SteamWorkshopMod -ApplicationName 'Arma 3' -Credential $cred -Path 'C:\Servers\Arma3' -ModIds @(843425103,843577117,843593391,843632231,1978754337)

    Because there are multiple hits when searching for Arma 3, the user will be promoted to select the right application. Then the specified mods will be downloaded to the server.

    .NOTES
    Author: TheDammedGamer and Frederik Hjorslev Poulsen

    SteamCMD CLI parameters: https://developer.valvesoftware.com/wiki/Command_Line_Options#Commands_2
    #>
    #TODO: Add Help Link

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidShouldContinueWithoutForce', '', Justification = 'Is correctly implemented, but using a switch instead of a bool.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '', Justification = 'Is implemented but not accepted by PSSA.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]
    [CmdletBinding(SupportsShouldProcess = $true,
        ConfirmImpact = 'Medium'
    )]
    param (
        [Parameter(Position = 0,
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'ApplicationName'
        )]
        [Alias('GameName')]
        [string]$ApplicationName,

        [Parameter(Position = 0,
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'AppID'
        )]
        [int]$AppID,

        [Parameter(Mandatory = $true)]
        [int[]]$ModIds,

        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter(Mandatory = $false)]
        [switch]$Force

    )

    begin {
        if ($null -eq (Get-SteamPath)) {
            throw 'SteamCMD could not be found in the env:Path. Have you executed Install-SteamCMD?'
        }

        # Make Secure.String to plain text string.
        if ($null -eq $Credential) {
            $SecureString = $Credential | Select-Object -ExpandProperty Password
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
            $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        }
    }

    process {
        function Use-SteamCMD ($SteamAppID, [int[]]$ModIDs) {
            # Prepare Workshop download Argument
            $WorkshopModCmdLine = [string]::Empty

            $ModIDs | ForEach-Object {
                $WorkshopModCmdLine = $WorkshopModCmdLine + [string]::Format(" +workshop_download_item {0} {1}", $SteamAppID, $_.ToString())
            }

            # If Steam username and Steam password are not empty we use them for logging in.
            if ($null -ne $Credential.UserName) {
                Write-Verbose -Message "Logging into Steam as $($Credential | Select-Object -ExpandProperty UserName)."
                Start-Process -FilePath (Get-SteamPath).Executable -NoNewWindow -ArgumentList "+login $($Credential | Select-Object -ExpandProperty UserName) $PlainPassword +force_install_dir `"$Path`" $WorkshopModCmdLine +quit" -Wait
            }
            # If Steam username and Steam password are empty we use anonymous login.
            elseif ($null -eq $Credential.UserName) {
                Write-Verbose -Message 'Using SteamCMD as anonymous.'
                Start-Process -FilePath (Get-SteamPath).Executable -NoNewWindow -ArgumentList "+login anonymous +force_install_dir `"$Path`" $WorkshopModCmdLine +quit" -Wait
            }
        }

        # If game is found by searching for game name
        if ($PSCmdlet.ParameterSetName -eq 'ApplicationName') {
            try {
                $Mods = [string]::Join(", ", $ModIds.ToString())
                $WorkshopMods = $ModIds
                # Install selected Mod
                $SteamApp = Find-SteamAppID -ApplicationName $ApplicationName
                # Install selected Steam application if a SteamAppID has been selected.
                if (-not ($null -eq $SteamApp)) {
                    if ($Force -or $PSCmdlet.ShouldContinue("Do you want to install or update the following Workshop Mods $Mods for $(($SteamApp).name)?", "Download mods for $$(($SteamApp).name)?")) {
                        Write-Verbose -Message "The workshop modIDs ($Mods) for $(($SteamApp).name) is being updated. Please wait for SteamCMD to finish."
                        Use-SteamCMD -SteamAppID ($SteamApp).appid -ModIDs $WorkshopMods
                    } # Should Continue
                }
            } catch {
                Throw "$Mods for $(($SteamApp).name)couldn't be updated."
            }
        } # ParameterSet ApplicationName

        # If game is found by using a unique AppID.
        if ($PSCmdlet.ParameterSetName -eq 'AppID') {
            try {
                $Mods = [string]::Join(", ", $ModIds.ToString())
                $SteamAppID = $AppID
                $WorkshopMods = $ModIds
                # Install selected Mod
                if ($Force -or $PSCmdlet.ShouldContinue("Do you want to install or update the following Workshop Mods $Mods for AppId $SteamAppID?", "Download mods for $SteamAppID?")) {
                    Write-Verbose -Message "The workshop modIDs ($Mods) for AppID $SteamAppID is being updated. Please wait for SteamCMD to finish."
                    Use-SteamCMD -SteamAppID $SteamAppID -ModIDs $WorkshopMods
                } # Should Continue
            } catch {
                Throw "$Mods for $SteamAppID couldn't be updated."
            }
        } # ParameterSet AppID

    } # Process
} # Cmdlet
<#
.Synopsis
   Get IDs from Morningstreams.com
.DESCRIPTION
   Get ID's from Morningstreams.com. Save the credentials into Windows Credential Manager and get the stream content ID's.
.EXAMPLE
   Get-ACEMorningStreams
   This example will prompt for credentials if they are not stored, save them to Windows Credential Manager, and retrieve stream content ID's.
.EXAMPLE
   $selectedContentId = Get-ACEMorningStreams
   This example will store the selected stream content ID in the $selectedContentId variable.
.EXAMPLE
   $selectedContentId = Get-ACEMorningStreams -ForcePrompt
   This example will store the selected stream content ID in the $selectedContentId variable.
   And will force the input of credentials for example if you changed your password on Morningstreams.com
.INPUTS
   None. Prompts for username and password if they are not stored.
.OUTPUTS
   Returns the content ID of the selected stream.
.NOTES
   Ensure you have internet connectivity to access the Morningstreams API.
.COMPONENT
   Morningstreams API interaction.
.ROLE
   Retrieves and displays ACE streams from Morningstreams.com.
.FUNCTIONALITY
   Allows users to log in to Morningstreams.com and retrieve stream content ID's, displaying them in a GridView for selection.
#>

function Get-ACEMorningStreams {
    param (
        [string]$credentialTarget = "MorningstreamsCredentials",
        [switch]$ForcePrompt
    )

    # Install the Credential Manager module if not installed
    if (-not (Get-Module -ListAvailable -Name CredentialManager)) {
        Write-Host "CredentialManager module not found. Installing..."
        Install-Module -Name CredentialManager -Force -Scope CurrentUser
    }

    Import-Module CredentialManager

    # Function to prompt for credentials and save them to Windows Credential Manager
    function Get-SaveCredentials {
        $cred = Get-Credential -Message $credentialTarget
 
        # Store the credentials in Windows Credential Manager
        New-StoredCredential -Target $credentialTarget -Credentials $cred -Persist LocalMachine
        return $cred
    }

    # Check if the credentials exist in Windows Credential Manager and load them, otherwise prompt and save
    if ($ForcePrompt -or -not (Get-StoredCredential -Target $credentialTarget)) {
        if ($ForcePrompt) {
            Write-Host "Forcing credentials prompt."
        } else {
            Write-Host "No stored credentials found. Prompting for credentials."
        }
        $credentials = Get-SaveCredentials
    } else {
        Write-Host "Using stored credentials."
        $credentials = Get-StoredCredential -Target $credentialTarget
    }

    if ($credentials.count -eq 2) {
        # Extract username and password
        $username = $credentials[1].UserName
        $password = $credentials[1].GetNetworkCredential().Password
    } else {
        # Extract username and password
        $username = $credentials.UserName
        $password = $credentials.GetNetworkCredential().Password   
    }

    # Login Morningstreams
    $uri = "https://api.morningstreams.com/api/auth/login"
    $loginCredentials = @{
        username = $username
        password = $password
    }
    $headers = @{
        "Content-Type" = "application/json"
    }
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body ($loginCredentials | ConvertTo-Json)
        $token = $response.token
    }
    catch {
        Write-Host "Login failed. Please check your username and password." -ForegroundColor Red
        if (-not $ForcePrompt) {
            Write-Host "Forcing credentials prompt to update stored credentials."
            Get-SaveCredentials
            exit
        }
        exit
    }

    $authHeaders = @{
        "Authorization" = "Bearer $token"
    }
    Write-Host "`nLogged in as $username ✓"

    # ACE Stream
    $uri = "https://api.morningstreams.com/api/acestreams"
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $authHeaders
        $streams = $response
    }
    catch {
        Write-Host "Failed to retrieve ACE streams." -ForegroundColor Red
        exit
    }

    Write-Host "`nFound $($streams.Count) streams:"

    # Display streams in a GridView
    $selectedStream = $streams | Select-Object title, likesCount, contentId | Out-GridView -Title "Select a Stream to watch"  -OutputMode Single

    if ($selectedStream) {
        Write-Host "`nYou selected:"
        Write-Host "  - $($selectedStream.title) 👍 $($selectedStream.likesCount)"
        return $selectedStream.contentId
    } else {
        Write-Host "`nNo stream selected." -ForegroundColor Red
        exit
    }
}

<#
.Synopsis
   Start an ACEStream using a specified content ID and play it in VLC.
.DESCRIPTION
   This function checks if ACEStream and VLC are installed, starts the ACEStream engine if it is not running, retrieves the stream URL for the given content ID, and plays it in VLC.
.EXAMPLE
   Start-ACEStream -ContentId "1234567890abcdef"
   This example starts the ACEStream for the given content ID and plays it in VLC.
.INPUTS
   [string]$ContentId - The content ID of the ACEStream to start.
.OUTPUTS
   Output messages indicating the status of the ACEStream and VLC processes, the stream URL, and any errors encountered.
.NOTES
   Ensure that ACEStream and VLC are installed on your system. Adjust the VLC installation path if it is different from the default.
.COMPONENT
   ACEStream, VLC
.ROLE
   Start and play ACEStreams in VLC.
.FUNCTIONALITY
   Check if ACEStream and VLC are installed, start the ACEStream engine if necessary, and play the specified ACEStream in VLC.
#>
function Start-ACEStream {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,
                   Position=0)]
        [string]$ContentId
    )

    begin {
        # Define the registry path and property name
        $registryPath = "HKCU:\Software\ACEStream"
        $propertyName = "InstallDir"
        
        # Define the process names
        $aceProcessName = "ace_engine"
        $vlcProcessName = "vlc"
        
        # Define the default VLC installation path (you may need to adjust this if VLC is installed in a different location)
        $vlcDefaultPath = "C:\Program Files\VideoLAN\VLC\vlc.exe"

        # Function to check if a process is running
        function Test-Process {
            param ([string]$processName)
            return Get-Process -Name $processName -ErrorAction SilentlyContinue
        }
    }

    process {
        # Check if ACEStream is installed
        try {
            $installDir = Get-ItemProperty -Path $registryPath -Name $propertyName | Select-Object -ExpandProperty $propertyName
        } catch {
            Write-Output "ACEStream is not installed."
            return
        }

        # Check if ace_engine is running
        $aceProcess = Test-Process -processName $aceProcessName

        if ($aceProcess) {
            Write-Output "$aceProcessName is already running."
        } else {
            Write-Output "$aceProcessName is not running. Starting the process..."
            # Start the process
            $aceEnginePath = Join-Path -Path $installDir -ChildPath "engine\ace_engine.exe"
            Start-Process -FilePath $aceEnginePath
            Write-Output "$aceProcessName has been started. Waiting 5 seconds"

            # Wait for a few seconds to ensure the process starts
            Start-Sleep -Seconds 5
        }

        # Define the API endpoint
        $apiEndpoint = "http://127.0.0.1:6878/webui/api/service?method=get_version"

        # Test the REST API to check if the engine is running
        try {
            $response = Invoke-RestMethod -Uri $apiEndpoint -Method Get
            if ($response.result -and $response.result.code -gt 3000000) {
                Write-Output "The engine is running. Version: $($response.result.version), Platform: $($response.result.platform)"
            } else {
                Write-Output "Unexpected response from the engine: $($response | ConvertTo-Json)"
                return
            }
        } catch {
            Write-Output "Failed to connect to the engine. Error: $_"
            return
        }

        # Check if VLC is installed
        if (Test-Path -Path $vlcDefaultPath) {
            Write-Output "VLC is installed."
        } else {
            Write-Output "VLC is not installed. Please install VLC to play the stream."
            return
        }


        $getPLayersEndpoint = "http://127.0.0.1:6878/server/api?api_version=3&method=get_available_players&content_id=$ContentId"

        try {
            $playerResponse = Invoke-RestMethod -Uri $getPLayersEndpoint -Method Get
            $playerVLC = $playerResponse.result.players | where {$_.name -eq "VLC"}
            Write-Output ("Found VLC player with id: {0}" -f $playerVLC.id)
        } catch {
            Write-Output "Failed to get the VLC player. Error: $_"
            return
        }


        # Get the stream URL
        $streamEndpoint = ("http://127.0.0.1:6878/server/api?api_version=3&method=open_in_player&content_id={0}&player_id={1}" -f $ContentId, $playerVLC.id)

        try {
            $streamResponse = Invoke-RestMethod -Uri $streamEndpoint -Method Get
            $streamUrl = $streamResponse.response
            Write-Output "Stream URL: $streamUrl"
        } catch {
            Write-Output "Failed to get the stream URL. Error: $_"
            return
        }
    }

    end {

    }
}

# Call the functions
$ContentId = Get-ACEMorningStreams
# $ContentId = Get-ACEMorningStreams -ForcePrompt # used if you want to force update the credentials
Start-ACEStream -ContentId $ContentId



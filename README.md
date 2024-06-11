# StartMorningstreamsVLC
Get stream ID from Morningstreams and start VLC player

The Start-MorningstreamsVLC.ps1 script is a powershell script.
To core of the script is to start a ACE stream that is grapped from Morningstreams and than the ace_engine is started and the stream is played in VLC player


Recruirements for this script are:

1. Having an account at Morningstreams.com
2. The Ace_engine is installed. https://acestream.org/#
3. VLC player is installed. https://www.videolan.org/vlc/index.nl.html
4. In powershell you should be allowed to execute script, Set-ExecutionPolicy -ExecutionPolicy Unrestricted
    https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.4


Workflow Description
1. Get-ACEMorningStreams

This function retrieves stream content IDs from Morningstreams.com and displays them in a GridView for selection. The function securely stores and retrieves user credentials using the Windows Credential Manager.
Steps:

    Check for Credential Manager Module:
        The function checks if the CredentialManager module is installed.
        If not installed, it automatically installs the module.

    Retrieve or Prompt for Credentials:
        The function attempts to retrieve stored credentials from the Windows Credential Manager.
        If no stored credentials are found, the function prompts the user for their username and password, then stores these credentials in the Credential Manager.

    Login to Morningstreams:
        The function uses the retrieved or provided credentials to log in to the Morningstreams API.
        If the login fails, the function outputs an error message and exits.

    Retrieve ACE Streams:
        After successful login, the function retrieves available ACE streams from the Morningstreams API.
        The retrieved streams are displayed in a GridView for the user to select one.

    Return Selected Stream Content ID:
        If the user selects a stream, the function returns the content ID of the selected stream.
        If no stream is selected, the function outputs an error message and exits.


2. Start-ACEStream

This function starts an ACEStream using a specified content ID and plays it in VLC. It ensures that ACEStream and VLC are installed and running, and it retrieves the stream URL for the given content ID.
Steps:

    Check ACEStream Installation:
        The function checks if ACEStream is installed by querying the registry.
        If ACEStream is not installed, the function outputs an error message and exits.

    Start ACEStream Engine:
        The function checks if the ACEStream engine (ace_engine) is running.
        If not running, it starts the ACEStream engine and waits a few seconds to ensure it starts properly.

    Verify ACEStream Engine Status:
        The function verifies the status of the ACEStream engine by querying its API.
        If the engine is not running or the response is unexpected, the function outputs an error message and exits.

    Check VLC Installation:
        The function checks if VLC is installed.
        If VLC is not installed, the function outputs an error message and exits.

    Retrieve VLC Player ID:
        The function retrieves the available VLC player ID from the ACEStream API.

    Get and Play Stream URL:
        The function retrieves the stream URL for the given content ID and VLC player ID.
        If successful, it outputs the stream URL.


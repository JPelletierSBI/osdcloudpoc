#to Run, boot OSDCloudUSB, at the PS Prompt: iex (irm win11.garytown.com)
$ScriptName = 'win11.fr-ca.sbintl.net'
$ScriptVersion = '1.00.00.01'
Write-Host -ForegroundColor Green "$ScriptName $ScriptVersion"
#iex (irm functions.garytown.com) #Add custom functions used in Script Hosting in GitHub
#iex (irm functions.osdcloud.com) #Add custom fucntions from OSDCloud

<# Offline Driver Details
If you extract Driver Packs to your Flash Drive, you can DISM them in while in WinPE and it will make the process much faster, plus ensure driver support for first Boot
Extract to: OSDCLoudUSB:\OSDCloud\DriverPacks\DISM\$ComputerManufacturer\$ComputerProduct
Use OSD Module to determine Vars
$ComputerProduct = (Get-MyComputerProduct)
$ComputerManufacturer = (Get-MyComputerManufacturer -Brief)
#>



#Variables to define the Windows OS / Edition etc to be applied during OSDCloud
$Product = (Get-MyComputerProduct)
$OSVersion = 'Windows 11' #Used to Determine Driver Pack
$OSReleaseID = '24H2' #Used to Determine Driver Pack
$OSName = 'Windows 11 24H2 x64'
$OSEdition = 'Pro'
$OSActivation = 'Retail'
$OSLanguage = 'fr-ca'


#Set OSDCloud Vars
$Global:MyOSDCloud = [ordered]@{
    Restart = [bool]$False
    RecoveryPartition = [bool]$true
    OEMActivation = [bool]$True
    WindowsUpdate = [bool]$true
    WindowsUpdateDrivers = [bool]$true
    WindowsDefenderUpdate = [bool]$true
    SetTimeZone = [bool]$true
    ClearDiskConfirm = [bool]$False
    ShutdownSetupComplete = [bool]$true
    SyncMSUpCatDriverUSB = [bool]$true
    OSImageIndex = '6'
}

#Testing MS Update Catalog Driver Sync
$Global:MyOSDCloud.DriverPackName = 'Microsoft Update Catalog'

#Used to Determine Driver Pack
$DriverPack = Get-OSDCloudDriverPack -Product $Product -OSVersion $OSVersion -OSReleaseID $OSReleaseID

if ($DriverPack){
    $Global:MyOSDCloud.DriverPackName = $DriverPack.Name
}

<#If Drivers are expanded on the USB Drive, disable installing a Driver Pack
if (Test-DISMFromOSDCloudUSB -eq $true){
    Write-Host "Found Driver Pack Extracted on Cloud USB Flash Drive, disabling Driver Download via OSDCloud" -ForegroundColor Green
    if ($Global:MyOSDCloud.SyncMSUpCatDriverUSB -eq $true){
        write-host "Setting DriverPackName to 'Microsoft Update Catalog'"
        $Global:MyOSDCloud.DriverPackName = 'Microsoft Update Catalog'
    }
    else {
        write-host "Setting DriverPackName to 'None'"
        $Global:MyOSDCloud.DriverPackName = "None"
    }
}
#>
#Enable HPIA | Update HP BIOS | Update HP TPM
if (Test-HPIASupport){
    #$Global:MyOSDCloud.DevMode = [bool]$True
    $Global:MyOSDCloud.HPTPMUpdate = [bool]$True
    if ($Product -ne '83B2'){$Global:MyOSDCloud.HPIAALL = [bool]$true} #I've had issues with this device and HPIA
    $Global:MyOSDCloud.HPBIOSUpdate = [bool]$true

    #Set HP BIOS Settings to what I want:
    iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/Manage-HPBiosSettings.ps1)
    Manage-HPBiosSettings -SetSettings
}




#write variables to console
Write-Output $Global:MyOSDCloud

#Update Files in Module that have been updated since last PowerShell Gallery Build (Testing Only)
#$ModulePath = (Get-ChildItem -Path "$($Env:ProgramFiles)\WindowsPowerShell\Modules\osd" | Where-Object {$_.Attributes -match "Directory"} | select -Last 1).fullname
#import-module "$ModulePath\OSD.psd1" -Force

#Launch OSDCloud
Write-Host "Starting OSDCloud" -ForegroundColor Green
write-host "Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage"

Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage

write-host "OSDCloud Process Complete, Running Custom Actions From Script Before Reboot" -ForegroundColor Green

<#
if (Test-DISMFromOSDCloudUSB){
    Start-DISMFromOSDCloudUSB
}
#>

$UnattendXml = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
      <UserAccounts>
        <AdministratorPassword>
          <Value></Value>
          <PlainText>true</PlainText>
        </AdministratorPassword>
      </UserAccounts>
      <AutoLogon>
        <Enabled>true</Enabled>
        <Username>Administrator</Username>
        <Domain>.</Domain>
        <Password>
          <Value></Value>
          <PlainText>true</PlainText>
        </Password>
        <LogonCount>999</LogonCount>
      </AutoLogon>
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <NetworkLocation>Work</NetworkLocation>
        <ProtectYourPC>1</ProtectYourPC>
        <HideLocalAccountScreen>true</HideLocalAccountScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
      </OOBE>
	<FirstLogonCommands>
        <SynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Description>Enable password change at next logon</Description>
          <CommandLine>cmd /c net user username /logonpasswordchg:yes</CommandLine>
        </SynchronousCommand>
	</FirstLogonCommands>
    </component>
    <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
      <InputLocale>0c0c:00001009</InputLocale>
            <SystemLocale>fr-CA</SystemLocale>
            <UILanguage>fr-CA</UILanguage>
            <UserLocale>fr-CA</UserLocale>
    </component>
  </settings>
</unattend>
'@ 

if (-NOT (Test-Path 'C:\Windows\Panther')) {
    New-Item -Path 'C:\Windows\Panther'-ItemType Directory -Force -ErrorAction Stop | Out-Null
}

$Panther = 'C:\Windows\Panther'
$UnattendPath = "$Panther\Unattend.xml"
$UnattendXml | Out-File -FilePath $UnattendPath -Encoding utf8 -Width 2000 -Force

$GoodApps =	"store|calculator|sticky|windows.photos|soundrecorder|mspaint|screensketch|notepad"

#Start Menu XML. If you run the script without -ClearStart, the XML below will be used for a custom start layout. By default it just leaves File Explorer, classic Control Panel, and Snipping Tool tiles.
#Place your XML like so:
#	$StartLayourStr = @"
#	<**YOUR START LAYOUT XML**>
#	"@
Function RemoveApps {
	#SafeApps contains apps that shouldn't be removed, or just can't and cause errors
	$SafeApps = "AAD.brokerplugin|accountscontrol|apprep.chxapp|assignedaccess|asynctext|bioenrollment|capturepicker|cloudexperience|contentdelivery|desktopappinstaller|ecapp|getstarted|immersivecontrolpanel|lockapp|MicrosoftEdge.Stable|net.native|oobenet|parentalcontrols|PPIProjection|sechealth|secureas|shellexperience|vclibs|xaml|XGpuEject"
	If ($Xbox) {
		$SafeApps = "$SafeApps|Xbox" 
}
	
	If ($Allapps) {
		$RemoveApps = Get-AppxPackage -allusers | where-object {$_.name -notmatch $SafeApps}
		$RemovePrApps = Get-AppxProvisionedPackage -online | where-object {$_.displayname -notmatch $SafeApps}
			ForEach ($RemovedApp in $RemoveApps) {
				Write-Host Removing app package: $RemovedApp.name
				Remove-AppxPackage -package $RemovedApp -erroraction silentlycontinue
				
}			ForEach ($RemovedPrApp in $RemovePrApps) {
				Write-Host Removing provisioned app $RemovedPrApp.displayname
				Remove-AppxProvisionedPackage -online -packagename $RemovedPrApp.packagename -erroraction silentlycontinue
				
}
}	Else {
		$SafeApps = "$SafeApps|$GoodApps"
		$RemoveApps = Get-AppxPackage -allusers | where-object {$_.name -notmatch $SafeApps}
		$RemovePrApps = Get-AppxProvisionedPackage -online | where-object {$_.displayname -notmatch $SafeApps}
			ForEach ($RemovedApp in $RemoveApps) {
				Write-Host Removing app package: $RemovedApp.name
				Remove-AppxPackage -package $RemovedApp -erroraction silentlycontinue
				
}			ForEach ($RemovedPrApp in $RemovePrApps) {
				Write-Host Removing provisioned app $RemovedPrApp.displayname
				Remove-AppxProvisionedPackage -online -packagename $RemovedPrApp.packagename -erroraction silentlycontinue
				
}
}
} #End Function RemoveApps
		
	
Function DisableTasks {
    If ($LeaveTasks) {
        Write-Host "***Leavetasks switch set - leaving scheduled tasks alone...***" 
}    Else {
        Write-Host "***Disabling some unecessary scheduled tasks...***"
        Get-Scheduledtask "Microsoft Compatibility Appraiser","ProgramDataUpdater","Consolidator","KernelCeipTask","UsbCeip","Microsoft-Windows-DiskDiagnosticDataCollector", "GatherNetworkInfo","QueueReporting" -erroraction silentlycontinue | Disable-scheduledtask 
}
}


#Disable services
Function DisableServices {
    If ($LeaveServices) {
        Write-Host "***Leaveservices switch set - leaving services alone...***"
}    Else {
        Write-Host "***Stopping and disabling some services...***"
        #Diagnostics tracking WMP Network Sharing
		Get-Service Diagtrack,WMPNetworkSvc -erroraction silentlycontinue | stop-service -passthru | set-service -startuptype disabled
		#WAP Push Message Routing  NOTE Sysprep w/ Generalize WILL FAIL if you disable the DmwApPushService. Commented out by default.
		#Get-Service DmwApPushService -erroraction silentlycontinue | stop-service -passthru | set-service -startuptype disabled
		#Disable OneSync service - Used to sync various apps and settings if you enable that (contacts, etc). Commented out by default to not break functionality.
		#Get-Service OneSyncSvc | stop-service -passthru | set-service -startuptype disabled
		
		#xBox services
		If ($Xbox){
}		 Else {
			#Disable xBox services - "xBox Game Monitoring Service" - XBGM - Can't be disabled (access denied)
			Get-Service XblAuthManager,XblGameSave,XboxNetApiSvc -erroraction silentlycontinue | stop-service -passthru | set-service -startuptype disabled
}		
}
}

        
#Registry change functions
#Load default user hive
Function loaddefaulthive {
	$matjazp72 = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' Default).Default
    reg load "$reglocation" $matjazp72\ntuser.dat
}


#Unload default user hive
Function unloaddefaulthive {
    [gc]::collect()
    reg unload "$reglocation"
}


#Cycle registry locations - 1st pass HKCU, 2nd pass default NTUSER.dat
Function RegChange {
    Write-Host "***Applying registry items to HKCU...***"
    $reglocation = "HKCU"
    regsetuser
    $reglocation = "HKLM\AllProfile"
	Write-Host "***Applying registry items to default NTUSER.DAT...***"
    loaddefaulthive; regsetuser; unloaddefaulthive
    $reglocation = $null
	Write-Host "***Applying registry items to HKLM...***"
    regsetmachine
    Write-Host "***Registry set current user and default user, and policies set for local machine!***"
}


#Set current and default user registry settings
Function RegSetUser {
    #Start menu suggestions
    Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "SystemPaneSuggestionsEnabled" /D 0 /F
	#Show suggested content in settings
	Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "SubscribedContent-338393Enabled" /D 0 /F
	Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "SubscribedContent-353694Enabled" /D 0 /F
	#Show suggestions occasionally
	Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "SubscribedContent-338388Enabled" /D 0 /F
	#Multitasking - Show suggestions in timeline
	Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "SubscribedContent-353698Enabled" /D 0 /F
    #Lockscreen suggestions, rotating pictures
    Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "SoftLandingEnabled" /D 0 /F
    Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "RotatingLockScreenEnabled" /D 0 /F
	Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "RotatingLockScreenOverlayEnabled" /D 0 /F
    #Preinstalled apps, Minecraft Twitter etc all that - still need a clean default start menu to fully eliminate
    Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "PreInstalledAppsEnabled" /D 0 /F
    Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "PreInstalledAppsEverEnabled" /D 0 /F
    Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "OEMPreInstalledAppsEnabled" /D 0 /F
    #MS shoehorning apps quietly into your profile
    Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "SilentInstalledAppsEnabled" /D 0 /F
    Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "ContentDeliveryAllowed" /D 0 /F
    Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "SubscribedContentEnabled" /D 0 /F
    #Ads in File Explorer
    Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /T REG_DWORD /V "ShowSyncProviderNotifications" /D 0 /F
	#Show me the Windows welcome experience after updates and occasionally
	Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "SubscribedContent-310093Enabled" /D 0 /F
	#Get tips, tricks, suggestions as you use Windows 
	Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "SubscribedContent-338389Enabled" /D 0 /F
	#Désactiver les updates du store et autres
	REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\WindowsStore" /f /v AutoDownload /t REG_DWORD /d 2
	REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /f /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1
	REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /f /v DisableSoftLanding /t REG_DWORD /d 1
	REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /f /v DisableThirdPartySuggestions /t REG_DWORD /d 1
	
	#Privacy Settings
	#Let websites provide local content by accessing language list - appears to reset during OOBE.
	#Reg Add "$reglocation\Control Panel\International\User Profile" /T REG_DWORD /V "HttpAcceptLanguageOptOut" /D 1 /F
    #Ask for feedback
    Reg Add "$reglocation\SOFTWARE\Microsoft\Siuf\Rules" /T REG_DWORD /V "NumberOfSIUFInPeriod" /D 0 /F
    Reg Add "$reglocation\SOFTWARE\Microsoft\Siuf\Rules" /T REG_DWORD /V "PeriodInNanoSeconds" /D 0 /F
	#Let apps use advertising ID
	Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /T REG_DWORD /V "Enabled" /D 0 /F
	#Let Windows track app launches to improve start and search results - includes run history
	#Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /T REG_DWORD /V "Start_TrackProgs" /D 0 /F
	#Tailored experiences - Diagnostics & Feedback settings
	Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" /T REG_DWORD /V "TailoredExperiencesWithDiagnosticDataEnabled" /D 0 /F
	#Let apps on other devices open messages and apps on this device - Shared Experiences settings
	Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP" /T REG_DWORD /V "RomeSdkChannelUserAuthzPolicy" /D 0 /F
	Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP" /T REG_DWORD /V "CdpSessionUserAuthzPolicy" /D 0 /F
	
	#Speech Inking & Typing - comment out if you use the pen\stylus a lot
    Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Language" /T REG_DWORD /V "Enabled" /D 0 /F
    Reg Add "$reglocation\SOFTWARE\Microsoft\InputPersonalization" /T REG_DWORD /V "RestrictImplicitTextCollection" /D 1 /F
    Reg Add "$reglocation\SOFTWARE\Microsoft\InputPersonalization" /T REG_DWORD /V "RestrictImplicitInkCollection" /D 1 /F
    Reg Add "$reglocation\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" /T REG_DWORD /V "HarvestContacts" /D 0 /F
	Reg Add "$reglocation\SOFTWARE\Microsoft\Personalization\Settings" /T REG_DWORD /V "AcceptedPrivacyPolicy" /D 0 /F
	#Improve inking & typing recognition
	Reg Add "$reglocation\SOFTWARE\Microsoft\Input\TIPC" /T REG_DWORD /V "Enabled" /D 0 /F
	#Pen & Windows Ink - Show recommended app suggestions
	Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\PenWorkspace" /T REG_DWORD /V "PenWorkspaceAppSuggestionsEnabled" /D 0 /F
	
	#People
	#Show My People notifications
	Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People\ShoulderTap" /T REG_DWORD /V "ShoulderTap" /D 0 /F
	#Show My People app suggestions
	Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /T REG_DWORD /V "SubscribedContent-314563Enabled" /D 0 /F
	#People on Taskbar
	Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" /T REG_DWORD /V "PeopleBand" /D 0 /F
	
	#Other Settings
	#Use Autoplay for all media and devices
	Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" /T REG_DWORD /V "DisableAutoplay" /D 1 /F
	#Taskbar search, personal preference. 0 = no search, 1 = search icon, 2 = search bar
    Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /T REG_DWORD /V "SearchboxTaskbarMode" /D 0 /F
	#Allow search to use location if it's enabled
	Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /T REG_DWORD /V "AllowSearchToUseLocation" /D 0 /F
	#Do not track - Edge
	Reg Add "$reglocation\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppContainer\Storage\microsoft.microsoftedge_8wekyb3d8bbwe\MicrosoftEdge\Main" /T REG_DWORD /V "DoNotTrack" /D 1 /F
	#Do not track - IE
	Reg Add "$reglocation\SOFTWARE\Microsoft\Internet Explorer\Main" /T REG_DWORD /V "DoNotTrack" /D 1 /F
	
	#--Optional User Settings--
	
    #App permissions user settings, these are all available from the settings menu
    If ($AppAccess) {
}	 Else{ 	
		#App permissions
		#Location - see tablet settings
		#Camera
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam" /T REG_SZ /V "Value" /D Deny /F
		#Microphone
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" /T REG_SZ /V "Value" /D Deny /F
		#Notifications - doesn't appear to work in 1803, setting hasn't been moved as of 1803 like most of the others
		#Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{52079E78-A92B-413F-B213-E8FE35712E72}" /T REG_SZ /V "Value" /D Deny /F
		#Account Info
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userAccountInformation" /T REG_SZ /V "Value" /D Deny /F
		#Contacts
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\contacts" /T REG_SZ /V "Value" /D Deny /F	
		#Calendar
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appointments" /T REG_SZ /V "Value" /D Deny /F
		#Call history
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\phoneCallHistory" /T REG_SZ /V "Value" /D Deny /F
		#Email
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\email" /T REG_SZ /V "Value" /D Deny /F
		#Tasks
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userDataTasks" /T REG_SZ /V "Value" /D Deny /F
		#TXT/MMS
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\chat" /T REG_SZ /V "Value" /D Deny /F
		#Radios - doesn't appear to work in 1803, setting hasn't been moved as of 1803 like most of the others
		#Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{A8804298-2D5F-42E3-9531-9C8C39EB29CE}" /T REG_SZ /V "Value" /D Deny /F
		#Other Devices - reset during OOBE
		#Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\LooselyCoupled" /T REG_SZ /V "Value" /D Deny /F
		#Cellular Data
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\cellularData" /T REG_SZ /V "Value" /D Deny /F
		#Allow apps to run in background global setting - seems to reset during OOBE
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /T REG_DWORD /V "GlobalUserDisabled" /D 1 /F
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /T REG_DWORD /V "BackgroundAppGlobalToggle" /D 0 /F	
		#App Diagnostics - doesn't appear to work in 1803, setting hasn't been moved as of 1803 like most of the others
		#Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{2297E4E2-5DBE-466D-A12B-0F8286F0D9CA}" /T REG_SZ /V "Value" /D Deny /F
		#My Documents
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\documentsLibrary" /T REG_SZ /V "Value" /D Deny /F
		#My Pictures
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\picturesLibrary" /T REG_SZ /V "Value" /D Deny /F
		#My Videos
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\videosLibrary" /T REG_SZ /V "Value" /D Deny /F
		#File System
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\broadFileSystemAccess" /T REG_SZ /V "Value" /D Deny /F
}
	
	#Disable Cortana - use -Cortana to leave it on
	If ($Cortana){
}	 Else{
		#Disable Cortana and Bing search user settings
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /T REG_DWORD /V "CortanaEnabled" /D 0 /F
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /T REG_DWORD /V "CanCortanaBeEnabled" /D 0 /F
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /T REG_DWORD /V "DeviceHistoryEnabled" /D 0 /F
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /T REG_DWORD /V "CortanaConsent" /D 0 /F
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /T REG_DWORD /V "CortanaInAmbientMode" /D 0 /F
		#Disable Bing search from start menu/search bar
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /T REG_DWORD /V "BingSearchEnabled" /D 0 /F
		#Disable Cortana on lock screen
		Reg Add "$reglocation\SOFTWARE\Microsoft\Speech_OneCore\Preferences" /T REG_DWORD /V "VoiceActivationEnableAboveLockscreen" /D 0 /F
		#Disable Cortana search history
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /T REG_DWORD /V "HistoryViewEnabled" /D 0 /F
}

	#Tablet Settings - use -Tablet switch to leave these on
	If ($Tablet) {
}	 Else {
		#Deny access to location and sensors
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Permissions\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" /T REG_DWORD /V "SensorPermissionState" /D 0 /F
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" /T REG_SZ /V "Value" /D Deny /F
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{E6AD100E-5F4E-44CD-BE0F-2265D88D14F5}" /T REG_SZ /V "Value" /D Deny /F
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /T REG_SZ /V "Value" /D Deny /F
}
		
	#Game settings - use -Xbox to leave these on
	If ($Xbox) {
}	 Else {
		#Disable Game DVR
		Reg Add "$reglocation\System\GameConfigStore" /T REG_DWORD /V "GameDVR_Enabled" /D 0 /F
}
	
	#OneDrive settings - use -OneDrive switch to leave these on
	If ($OneDrive) {
}	 Else {
		#Disable OneDrive startup run user settings
		Reg Add "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /T REG_BINARY /V "OneDrive" /D 0300000021B9DEB396D7D001 /F
		#Disable automatic OneDrive desktop setup for new accounts
		If ($reglocation -ne "HKCU") {
			Reg Delete "$reglocation\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /V "OneDriveSetup" /F
}
}

#End user registry settings
}


#Set local machine settings and local group policies    
Function RegSetMachine {
    #--Local GP settings--   CONVERT THESE TO HKCU / DEFAULT / HKLM WHERE POSSIBLE
    #Can be adjusted in GPedit.msc in Pro+ editions.
    #Local Policy\Computer Config\Admin Templates\Windows Components			
    #/Application Compatibility
    #Turn off Application Telemetry			
    Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat" /T REG_DWORD /V "AITEnable" /D 0 /F			
    #Turn off inventory collector			
    Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat" /T REG_DWORD /V "DisableInventory" /D 1 /F

    #/Cloud Content			
    #Turn off Consumer Experiences	- Enterprise only (for Pro, HKCU settings and start menu cleanup achieve same result)		
    Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /T REG_DWORD /V "DisableWindowsConsumerFeatures" /D 1 /F
	#Turn off all spotlight features	
    #Reg Add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /T REG_DWORD /V "DisableWindowsSpotlightFeatures" /D 1 /F  

    #/Data Collection and Preview Builds			
    #Set Telemetry to off (switches to 1:basic for W10Pro and lower)			
    Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /T REG_DWORD /V "AllowTelemetry" /D 0 /F
    #Disable pre-release features and settings			
    #Reg Add "HKLM\SOFTWARE\Policies\Microsoft\Windows\PreviewBuilds" /T REG_DWORD /V "EnableConfigFlighting" /D 0 /F
    #Do not show feedback notifications			
    Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /T REG_DWORD /V "DoNotShowFeedbackNotifications" /D 1 /F

    #/Store
    #Disable all apps from store, commented out by default as it will break the store			
    #Reg Add "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" /T REG_DWORD /V "DisableStoreApps" /D 1 /F		
    #Turn off Store, left disabled by default			
    #Reg Add "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" /T REG_DWORD /V "RemoveWindowsStore" /D 1 /F

    #/Sync your settings - commented out by default to keep functionality of sync service		
    #Do not sync (anything)			
    #Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /T REG_DWORD /V "DisableSettingSync" /D 2 /F
    #Disallow users to override this
    #Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /T REG_DWORD /V "DisableSettingSyncUserOverride" /D 1 /F
	
	#Add "Run as different user" to context menu
	Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /T REG_DWORD /V "ShowRunasDifferentuserinStart" /D 1 /F
	
	#!!!None of these effective anymore in 1803!!! Now handled by HKCU settings
    #Disallow web search from desktop search			
    #Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /T REG_DWORD /V "DisableWebSearch" /D 1 /F
    #Don't search the web or display web results in search			
    #Reg Add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /T REG_DWORD /V "ConnectedSearchUseWeb" /D 0 /F
	#Don't allow search to use location
	#Reg Add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /T REG_DWORD /V "AllowSearchToUseLocation" /D 0 /F

    #/Windows Update			
    #Turn off featured SOFTWARE notifications through Windows Update
    Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /T REG_DWORD /V "EnableFeaturedSoftware" /D 0 /F

    #--Non Local GP Settings--		
    #Delivery Optimization settings - sets to 1 for LAN only, change to 0 for off
    Reg Add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /T REG_DWORD /V "DownloadMode" /D 1 /F
    Reg Add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /T REG_DWORD /V "DODownloadMode" /D 1 /F
	Reg Add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings" /T REG_DWORD /V "DownloadMode" /D 1 /F
	
    #Disabling advertising info and device metadata collection for this machine
    Reg Add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /T REG_DWORD /V "Enabled" /D 0 /F
    Reg Add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata" /V "PreventDeviceMetadataFromNetwork" /T REG_DWORD /D 1 /F

	#Disable CEIP. GP setting at: Computer Config\Admin Templates\System\Internet Communication Managemen\Internet Communication settings
    Reg Add "HKLM\SOFTWARE\Microsoft\SQMClient\Windows" /T REG_DWORD /V "CEIPEnable" /D 0 /F
	
	#Turn off automatic download/install of store app updates	
    #Reg Add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" /T REG_DWORD /V "AutoDownload" /D 2 /F	
	
	#Prevent using sign-in info to automatically finish setting up after an update
    Reg Add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /T REG_DWORD /V "ARSOUserConsent" /D 2 /F
	
    #Prevent apps on other devices from opening apps on this one - disables phone pairing
    #Reg Add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\SmartGlass" /T REG_DWORD /V "UserAuthPolicy" /D 0 /F
    
    #Enable diagnostic data viewer
    Reg Add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack\EventTranscriptKey" /T REG_DWORD /V "EnableEventTranscript" /D 1 /F
	
	#Disable Edge desktop shortcut
	Reg Add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /T REG_DWORD /V "DisableEdgeDesktopShortcutCreation" /D 1 /F
	
	#Filter web content through smartscreen. Left enabled by default.
    #Reg Add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost" /T REG_DWORD /V "EnableWebContentEvaluation" /D 0 /F

	#--Optional Machine Settings--
	
	#Disable Cortana - use -Cortana to leave it on
	If ($Cortana){
}	 Else{
    #Cortana local GP - Computer Config\Admin Templates\Windows Components\Search			
    #Disallow Cortana			
    Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /T REG_DWORD /V "AllowCortana" /D 0 /F
    #Disallow Cortana on lock screen - seems pointless with above setting, may be deprecated, covered by HKCU anyways		
    #Reg Add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /T REG_DWORD /V "AllowCortanaAboveLock" /D 0 /F
}

	#Tablet Settings - use -Tablet switch to leave these on
	If ($Tablet) {
}	 Else {
		#Turn off location - global
		Reg Add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /T REG_SZ /V "Value" /D Deny /F
}
	
	#Game settings - use -Xbox to leave these on
	If ($Xbox) {
}	 Else {
		#Disable Game Monitoring Service
		Reg Add "HKLM\SYSTEM\CurrentControlSet\Services\xbgm" /T REG_DWORD /V "Start" /D 4 /F
		#GameDVR local GP - Computer Config\Admin Templates\Windows Components\Windows Game Recording and Broadcasting
		Reg Add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /T REG_DWORD /V "AllowGameDVR" /D 0 /F
}

	#OneDrive settings - use -OneDrive switch to leave these on
	If ($OneDrive) {
}	 Else {
		#Prevent usage of OneDrive local GP - Computer Config\Admin Templates\Windows Components\OneDrive	
		Reg Add	"HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /T REG_DWORD /V "DisableFileSyncNGSC" /D 1 /F
		Reg Add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /T REG_DWORD /V "DisableFileSync" /D 1 /F
		#Remove OneDrive from File Explorer
		Reg Add "HKCR\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /T REG_DWORD /V "System.IsPinnedToNameSpaceTree" /D 0 /F
		Reg Add "HKCR\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /T REG_DWORD /V "System.IsPinnedToNameSpaceTree" /D 0 /F
}
	
#End machine registry settings
}           


#Clean up the default start menu    
Function ClearStartMenu {
    If (1 -eq 1) {
		Write-Host "***Setting empty start menu for new profiles...***"
#Don't edit this. Creates empty start menu if -ClearStart is used.
        $StartLayoutStr = @"
<LayoutModificationTemplate Version="1" xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification" xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout">
  <LayoutOptions StartTileGroupCellWidth="6" />
  <DefaultLayoutOverride>
    <StartLayoutCollection>
      <defaultlayout:StartLayout GroupCellWidth="6" xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout">
      </defaultlayout:StartLayout>
    </StartLayoutCollection>
  </DefaultLayoutOverride>
  </LayoutModificationTemplate>
"@
	    add-content $Env:TEMP\startlayout.xml $StartLayoutStr
        import-startlayout -layoutpath $Env:TEMP\startlayout.xml -mountpath $Env:SYSTEMDRIVE\
        remove-item $Env:TEMP\startlayout.xml
}    Else {        
		Write-Host "***Setting clean start menu for new profiles...***"
#Custom start layout XML near the top of the script.

        add-content $Env:TEMP\startlayout.xml $StartLayoutStr
        import-startlayout -layoutpath $Env:TEMP\startlayout.xml -mountpath $Env:SYSTEMDRIVE\
        remove-item $Env:TEMP\startlayout.xml
}
}


#---End of functions---

RemoveApps
ClearStartMenu

# Set variables to indicate value and key to set# Create the key if it does not exist
If (-NOT (Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge')) {
  New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Force | Out-Null
}  
# Now set the value
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -Name 'HideFirstRunExperience' -Value '00000001' -PropertyType DWORD -Force

powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
powercfg /x -hibernate-timeout-ac 0
powercfg /x -hibernate-timeout-dc 0
powercfg /x -disk-timeout-ac 0
powercfg /x -disk-timeout-dc 0
powercfg /x -monitor-timeout-ac 0
powercfg /x -monitor-timeout-dc 0
Powercfg /x -standby-timeout-ac 0
powercfg /x -standby-timeout-dc 0

#Restart
restart-computer

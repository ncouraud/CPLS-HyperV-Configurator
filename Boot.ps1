#Importing HyperV library and tools 
import-module C:\ClassResources\PS\HyperV\HyperV.psd1
#<summary>
#Starts a VM and shuts it down.
#</summary>
#<param name=image>the virtual machine object to be modified</param>
function boot($image)
{
	Write-Host "Starting Up" $image.VMElementName
    Start-VM $image -HeartBeatTimeOut 180 -wait #starts image for rearm command
	Write-Host "Checking Heartbeat"
	#Checks to see if Integration Services is Up and Running for VM shutdown
	$hb = $image.GetRelated("Msvm_HeartBeatComponent")
	$hbstatus = $hb.StatusDescriptions
	if($hbstatus.StatusDescriptions -eq "OK") {
		Write-Host "Heartbeat OK - Waiting for Boot to Finish"
		Start-Sleep -s 180 #Rome wasn't built in a day.... 
		Write-Host "Shutting Down" $image.VMElementName
		Invoke-VMShutdown $image -force -Wait
	}
	else {
		Write-Host "Heartbeat Failure - Blank Image?"
		Stop-VM $image -Force
	}
}
#Lets Roll...
$vms = Get-VM #pulls a list of all VMs Imported on system
foreach ($vm in $vms){
    boot($vm)
    }
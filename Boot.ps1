#Importing HyperV library and tools 
import-module C:\ClassResources\PS\HyperV\HyperV.psd1
#<summary>
#Starts a VM and shuts it down.
#</summary>
#<param name=image>the virtual machine object to be modified</param>
function boot($image)
{
	Write-Host "Starting Up" + $image.VMElementName
    Start-VM $image -HeartBeatTimeOut 120 -wait #starts image for rearm command
	Start-Sleep -s 240 #Rome wasn't built in a day.... 
    Write-Host "Shutting Down" + $image.VMElementName
    Invoke-VMShutdown $image -force
}
#Lets Roll...
$vms = Get-VM #pulls a list of all VMs Imported on system
foreach ($vm in $vms){
    boot($vm)
    }
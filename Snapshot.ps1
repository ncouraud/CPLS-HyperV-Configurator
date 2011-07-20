#Import Hyper-V Toolkit
import-module C:\ClassResources\PS\HyperV\HyperV.psd1
#<summary>
#Snapshots a VM and Renames it to Starting Image
#</summary>
#<param name=image>the virtual machine object to be modified</param>
function snapshot($image)
{
	New-VMSnapshot $image -wait -force
	$snap = Get-VMSnapshot $image -newest
    $snapname = $snap.elementname
    Rename-VMSnapshot -VM $image -SnapName $snapname -NewName "Starting Image" -force
}
#Create Switch Objects
$VirtualSwitchname = "Internal Network"
$server = "."
$Switch = Get-WmiObject -computerName $server -NameSpace  "Root\Virtualization"   -query "Select * From MsVM_VirtualSwitch Where elementname like '$VirtualSwitchname' "
#configure VMs
$vms = Get-VM
foreach ($vm in $vms){
    $machine = Get-VM $vm
	snapshot($vm)
}
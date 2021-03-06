#Import Hyper-V Toolkit
import-module C:\ClassResources\PS\HyperV\HyperV.psd1

#Create Networks if they don't exist
function switchprep(){
	$switch = Get-VMSwitch
	$int = 0
	foreach ($sw in $switch) {
		if ($sw.ElementName -eq "Internal Network"){
			write-host "Internal Network Exists"
			$int = 1
		}
	}
	if ($int -eq 0){
		New-VMInternalSwitch "Internal Network"
	}
}
switchprep
#Create Switch Objects
$VirtualSwitchname = "Internal Network"
$server = "."
$Switch = Get-WmiObject -computerName $server -NameSpace  "Root\Virtualization"   -query "Select * From MsVM_VirtualSwitch Where elementname like '$VirtualSwitchname' "
#configure VMs
$vms = Get-VM
foreach ($vm in $vms){
    $machine = Get-VM $vm
    $nics = Get-VMNIC $machine
	foreach ($nic in $nics){
		Set-vmNicSwitch -VM $machine -NIC $nic -VirtualSwitch $Switch
	}
}
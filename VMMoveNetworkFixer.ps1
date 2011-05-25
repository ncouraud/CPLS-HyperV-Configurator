#Import Hyper-V Toolkit
import-module C:\ClassResources\PS\HyperV\HyperV.psd1
#Create Networks if they don't exist
function switchprep(){
	$switch = Get-VMSwitch
	$prv = 0
	$int = 0
	$pr2 = 0
	foreach ($sw in $switch) {
		if ($sw.ElementName -eq "Private Network"){
			write-host "Private Network Exists"
			$prv = 1
		}
		elseif ($sw.ElementName -eq "Internal Network"){
			write-host "Internal Network Exists"
			$int = 1
		}
		elseif ($sw.ElementName -eq "Private Network 2"){
			write-host "Private Network 2 Exists"
			$pr2 = 1
		}
	}
	if ($int -eq 0){
		New-VMInternalSwitch "Internal Network"
	}
	if ($pr2 -eq 0){
		New-VMPrivateSwitch "Private Network 2"
	}
	if ($prv -eq 0){ 
		New-VMPrivateSwitch "Private Network"
	}
}
switchprep
#Create Switch Objects
$VirtualSwitchname2 = "Private Network"
$server = "."
$PrivateSwitch = Get-WmiObject -computerName $server -NameSpace  "Root\Virtualization"   -query "Select * From MsVM_VirtualSwitch Where elementname like '$VirtualSwitchname2' "
#Build Directory Array
$ClassNumber = (Read-Host "Enter class number")
cd "D:\Program Files\Microsoft Learning\" 
cd $ClassNumber
cd "Drives"
$dirs = dir | Where {$_.psIsContainer -eq $true}
#create Array 
$vms = @()
#populate Array
$int = $dirs.count
$int2 = $int - 1
if ($int2 -ge 0){
    $num = 0..$int2
    foreach ($i in $num) {
	   $name = $dirs[$i].name
	   $vms = $vms + $name
    }
}
else {
    $name = $dirs.name
    $vms = $vms + $name
}

#configure VMs
foreach ($vm in $vms){
    $machine = Get-VM $vm
    $nics = Get-VMNIC $machine
	foreach ($nic in $nics){
		Set-vmNicSwitch -VM $machine -NIC $nic -VirtualSwitch $PrivateSwitch
	}
}
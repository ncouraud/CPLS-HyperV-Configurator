import-module C:\ClassResources\PS\HyperV\HyperV.psd1

#Build Private Network if none exists
#Create Switch Objects
$VirtualSwitchname2 = "Private Network"
$server = "."
$PrivateSwitch = Get-WmiObject -computerName $server -NameSpace  "Root\Virtualization"   -query "Select * From MsVM_VirtualSwitch Where elementname like '$VirtualSwitchname2' "
if ($PrivateSwitch.ElementName = "Private Network"){
	write-host "Private Network Exists"
}
else {
	New-VMPrivateSwitch "Private Network"
	write-host "Private Network Created"
}
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
    $nic = Select-VMNIC $machine
    Set-vmNicSwitch -VM $machine -NIC $nic -VirtualSwitch $PrivateSwitch
}
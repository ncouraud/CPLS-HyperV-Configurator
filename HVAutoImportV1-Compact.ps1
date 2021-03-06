import-module C:\ClassResources\PS\HyperV\HyperV.psd1
function memchange($image)
{
    $physmem = (Get-WmiObject Win32_PhysicalMemory | measure-object Capacity -sum).sum/1gb
    $mult = ($physmem / 8)
    $mem = Get-VMMemory $image
	$mb = $mem.VirtualQuantity
	$newmem = ($mb * $mult)
	Set-VMMemory $image $newmem
}
function snapshot($image)
{
	New-VMSnapshot $image -wait -force
	$snap = Get-VMSnapshot $image -newest
    $snapname = $snap.elementname
    Rename-VMSnapshot -VM $image -SnapName $snapname -NewName "Starting Image" -force
}
function revert($image)
{
	$restimg = Get-VMSnapshot $image -newest 
    Restore-VMSnapshot $restimg -wait -force
}
function rearmer($image)
{ 
	Start-VM $image -HeartBeatTimeOut 120 -wait 
	rearm($image) 
    if ($LASTEXITCODE -eq 1) {
        Write-Host "Exiting..."
        Break
    }
    else {        
	   Write-Host "Shutting Down" + $image 
       Invoke-VMShutdown $image -force
       Write-Host "Rebooting" + $image + "..." 
       Start-VM $image -HeartBeatTimeout 120 -wait
	   Invoke-VMShutdown $image -force
    }
}
function nicswap($image, $switch)
{
	$vm = Get-VM $image 
    $nics = Get-VMNIC $vm
	foreach ($nic in $nics){
		Set-vmNicSwitch -VM $vm -NIC $nic -VirtualSwitch $Switch
	}
}
function VMImport($path)
{
   Import-VM -Paths $path -ReUseIDs
}
function rearm(){	
    $vm = Get-WmiObject -computerName "." -NameSpace  "Root\Virtualization"   -query "SELECT * FROM Msvm_KvpExchangeComponent" 
    $vmitems = $vm.GuestIntrinsicExchangeItems 
    $fqdnitem = $vmitems[0] 
    $xmlfqdn = [xml]$fqdnitem
    $FQDN = $xmlfqdn.INSTANCE.PROPERTY[1].VALUE 
    SetIP($vmitems) 
    $domains = $FQDN.Split(".")
	if ($domains[-1] -eq ".com"){ 
		$hostname = $domains[0] 
		$domain = $domain[-2]
		}
	else { 
		$hostname = $domains
		$domain = $domains
	}
    $user = $domain+"\administrator" 
    cscript.exe c:\windows\system32\slmgr.vbs $hostname $user "Pa$$w0rd" /rearm 
	if ($LASTEXITCODE -eq 0){
        write-host "Image " $hostname "Rearmed"
        $val = 0
        return $val
    }
    else {
        write-host "Rearm Failed"
        $val = 1
        return $val 
    }
}
function SetIP($Array){
    $ipitem = $Array[-2]
    $xmlip = [xml]$ipitem 
    $ipaddr = $xmlip.INSTANCE.PROPERTY[1].VALUE 
    $iparr = $ipaddr.SPlit(".") 
    $iprebuild = $iparr[0]+"."+$iparr[1]+"."+$iparr[2]+".254" 
	$networkAdapters = (Get-WMIObject -computerName "." -Query "SELECT * FROM win32_networkadapter WHERE Description LIKE 'Microsoft Virtual Network Switch Adapter'");
    foreach ($adapter in $networkadapters){
         if ($adapter.AdapterType -eq "Ethernet 802.3") { 
              $adapterindex = $adapter.Index} 
         }
        $internalnetadapter = (Get-WMIObject -computerName "." -Query "SELECT * FROM win32_networkadapter WHERE Index LIKE '$adapterindex'"); 
        $ni = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()
		foreach ($iface in $ni){
          if ($iface.Description -eq $internalnetadapter.Name) {
             $name = $iface.Name}
             }
        $netsh = netsh interface ip set address name=$name static addr=$iprebuild
        $netsh 
    }
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

$server = "." 
$InternalSwitchName = "Internal Network"
$InternalSwitch = Get-WmiObject -computerName $server -NameSpace  "Root\Virtualization"   -query "Select * From MsVM_VirtualSwitch Where elementname like '$InternalSwitchName' " 
$PrivateSwitchName = "Private Network"
$PrivateSwitch = Get-WmiObject -computerName $server -NameSpace  "Root\Virtualization"   -query "Select * From MsVM_VirtualSwitch Where elementname like '$PrivateSwitchName' "
$ClassNumber = (Read-Host "Enter class number")
cd "D:\Program Files\Microsoft Learning\" 
cd $ClassNumber
cd "Drives"
$dirs = dir | Where {$_.psIsContainer -eq $true}
$VirtualMachines = @()
$int = $dirs.count
$int2 = $int - 1
$num = 0..$int2
foreach ($i in $num) {
	$name = $dirs[$i].fullname
	$VirtualMachines = $VirtualMachines + $name
}
foreach ($path in $VirtualMachines){
    VMImport($path)
}
$vms = Get-VM 
foreach ($vm in $vms){
	memchange($vm)  
	nicswap($vm, $InternalSwitch)
    rearmer($vm)
	nicswap($vm, $PrivateSwitch)
	snapshot($vm)
}
foreach ($vm in $vms){
	revert($vm)
}
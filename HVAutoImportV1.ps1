#HVAutoImport.ps1  V0.1 Composed by John Gates and Nick Couraud 02-16-11
#The Purpose of this script is to Import HyperV machines for any Microsoft MOC
#Class with minimal effort and user interferance.. 
# Goals:
# * Run Pre-import script to creat symlinks for Base and Midteir drives
# * Create an privatenetwork in which the Imported machines will be connected to
# * Import Hyper-V machines for MOC class and assign Network interfaces to
#   Apropriate switches if neccisary 
# !# First Rendition will be an very linear approach for importing the machines #!
#  Future Versions of the script will be more modular for ease of customization
#  Between MOC courses. 

#Importing HyperV library and tools 
import-module C:\ClassResources\PS\HyperV\HyperV.psd1

#Running Preimport script to create symlinks in proper directory's for Base and 
#Mid-Tier drives
#cd "d:/Microsoft Learning/"
#.\PreImportScriptAll.bat

#
# Start Functions Region.
#

#Define Function to Re-Allocate memory
function memchange($image)
{
    #sets VM memory Multiplication Factor
    $physmem = (Get-WmiObject Win32_PhysicalMemory | measure-object Capacity -sum).sum/1gb
    $mult = ($physmem / 8)
    #Sets VM Memory Allocation
    $mem = Get-VMMemory $image
	$mb = $mem.VirtualQuantity
	$newmem = ($mb * $mult)
	Set-VMMemory $image $newmem
}

#Snapshots a VM and Renames it to Starting Image
#works like a charm! 
function snapshot($image)
{
	New-VMSnapshot $image -wait -force
	$snap = Get-VMSnapshot $image -newest
    $snapname = $snap.elementname
    Rename-VMSnapshot -VM $image -SnapName $snapname -NewName "Starting Image" -force
}

#Applies the Starting Image snapshot
#Works Great!
function revert($image)
{
	$restimg = Get-VMSnapshot $image -newest 
    Restore-VMSnapshot $restimg -wait -force
}

#Starts a VM, Passes it the rearm Command, then reboots the machine and shuts it down.
#works dependent upon the rearm function
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

#switches given nic for an image to the selected Virtual Switch
#works now! 
function nicswap($Image, $switch)
{
	$vm = Get-VM $Image 
    $nics = Get-VMNIC $vm
	foreach ($nic in $nics){
		Set-vmNicSwitch -VM $vm -NIC $nic -VirtualSwitch $Switch
	}
}

#Defining Function for VMImport - Works Great! 
function VMImport($string)
{
   Import-VM -Paths $string -ReUseIDs
}

#function that performs rearm on remote computer
#note - host name may not be VM name. could pose issues in classes like 10174
#also note that if Administrator account does not have default admin 
#permissions - or UAC is necessary, this code will not work. 
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
    #works until this point! 
    #Need some way to run script on VM remotely
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
#
#
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

# configures Hyper-V Virtual Switches before use.
#first checks to see what switches are configured, 
#then sets a key to enable the switch if necessary
#Works like a charm - 5/23/11
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
#
# End Function Region
#

#
# Start Program Region
#

#Configuring HyperV Network Switches before import of vm's 
switchprep

# Sets up the necessary variables for later use. 
$server = "."
$VirtualSwitchname = "Internal Network"
$InternalSwitch = Get-WmiObject -computerName $server -NameSpace  "Root\Virtualization"   -query "Select * From MsVM_VirtualSwitch Where elementname like '$VirtualSwitchname' " 
$VirtualSwitchname2 = "Private Network"
$PrivateSwitch = Get-WmiObject -computerName $server -NameSpace  "Root\Virtualization"   -query "Select * From MsVM_VirtualSwitch Where elementname like '$VirtualSwitchname2' "

#Auto-Generation of path/array - Code Works! 
$ClassNumber = (Read-Host "Enter class number")
cd "D:\Program Files\Microsoft Learning\" 
cd $ClassNumber
cd "Drives"
$dirs = dir | Where {$_.psIsContainer -eq $true}

#create Arrays # Code Works! 
$VirtualMachines = @()
#$vms = @()

#populate Arrays - Code Works! 
$int = $dirs.count
$int2 = $int - 1
$num = 0..$int2
#foreach ($i in $num) {
#	$name = $dirs[$i].name
#	$vms = $vms + $name
#}
foreach ($i in $num) {
	$name = $dirs[$i].fullname
	$VirtualMachines = $VirtualMachines + $name
}

#Import Virtual Machines -Code Works! 
foreach ($path in $VirtualMachines){
    VMImport($path)
}

#configure VMs
$vms = Get-VM
foreach ($vm in $vms){
	memchange($vm) #code works! 
	nicswap($vm, $InternalSwitch)
    rearmer($vm)
	nicswap($vm, $PrivateSwitch)
	snapshot($vm)
}

#clean up after ourselves
foreach ($vm in $vms){
	revert($vm)
}

#
# End Program Region
#
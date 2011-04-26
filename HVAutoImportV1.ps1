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
    $nic = Select-VMNIC $vm
    Set-vmNicSwitch -VM $vm -NIC $nic -VirtualSwitch $switch
    Write-Host $switch "Selected"
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
function rearm($remote){	
    $remotehost = [system.net.dns]::GetHostEntry($remote) | select hostname
    $hostname = $remotehost.HostName
    if ($hostname.ToLower() -like "contoso"){
        $domain = "contoso\"
    }
    if ($hostname.ToLower() -like "adatum"){
        $domain = "adatum\"
    }
    else {
        $domain = $remote+"\"
    }
    $user = $domain + "administrator"
    cscript.exe c:\windows\system32\slmgr.vbs /dli #$remote $user "Pa$$w0rd" /rearm
    if ($LASTEXITCODE -eq 0){
        write-host "Image " $remote "Rearmed"
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
# End Function Region
#

#
# Start Program Region
#

#Configuring HyperV Network Switches before import of vm's 
#need to add case if multiple Switches on machine
#broken if more than one switch.
$switch = Get-VMSwitch
if ($switch.ElementName = "Private Network"){
	write-host "Private Network Exists"
}
else {
	New-VMPrivateSwitch "Private Network"
	write-host "Private Network Created"
}
New-VMInternalSwitch "Internal Network"
# Sets up the necessary variables for later use. 
$server = "."
$VirtualSwitchname = "Internal Network"
$InternalSwitch = Get-WmiObject -computerName $server -NameSpace  "Root\Virtualization"   -query "Select * From MsVM_VirtualSwitch Where elementname like '$VirtualSwitchname' " 
write-host "Internal Network Created"
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
$vms = @()

#populate Arrays - Code Works! 
$int = $dirs.count
$int2 = $int - 1
$num = 0..$int2
foreach ($i in $num) {
	$name = $dirs[$i].name
	$vms = $vms + $name
}
foreach ($i in $num) {
	$name = $dirs[$i].fullname
	$VirtualMachines = $VirtualMachines + $name
}

#Import Virtual Machines -Code Works! 
foreach ($path in $VirtualMachines){
    VMImport($path)
}

#configure VMs
foreach ($vm in $vms){
	memchange($vm) #code works! 
	nicswap($vm, $InternalSwitch)
    rearmer($vm)
	nicswap($vm, $PrivateSwitch)
	snapshot($vm)
}

#clean up after ourselves
Remove-VMSwitch "Internal Network" -force
foreach ($vm in $vms){
	revert($vm)
}

#
# End Program Region
#


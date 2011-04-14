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
import-module c:\ClassResources\HyperVImport\HyperV_Install\HyperV.psd1

#Running Preimport script to create symlinks in proper directory's for Base and 
#Mid-Tier drives
#cd "d:/Microsoft Learning/"
#.\PreImportScriptAll.bat

#
# Start Program Region
#

#Configuring HyperV Network Switches before import of vm's
$switch = Get-VMSwitch
if ($switch.ElementName = "Private Network"){write-host "Private Network Exists"}
else {New-VMPrivateSwitch "Private Network"}
New-VMInternalSwitch "Internal Network"

#Auto-Generation of path
$ClassNumber = (Read-Host "Enter class number")
cd "D:\Program Files\Microsoft Learning\" 
cd $ClassNumber
cd "Drives"
$dirs = dir | Where {$_.psIsContainer -eq $true}

#create Arrays
$VirtualMachines = @()
$vms = @()

#populate Arrays
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

#Import Virtual Machines
foreach ($path in $VirtualMachines)
{
    VMImport($path)
}

#configure VMs
foreach ($vm in $vms)
{
	memchange($vm)
	nicswap($vm, "Internal Network")
	rearmer($vm)
	nicswap($vm, "Private Network")
	snapshot($vm)
}

#clean up after ourselves
Remove-VMSwitch "Internal Network"
foreach ($vm in $vms)
{
	revert($vm)
}

#
# End Program Region
#

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
#Broken. Both in functionality and syntax - need to spend more time with this. 
function snapshot($image)
{
	New-VMSnapshot $image -wait -force
	Get-VMSnapshot $image -newest | RenameVMSnapshot $_.elementName -n "Starting Image"
}

#Applies the Starting Image snapshot
function revert($image)
{
	Get-VMSnapshot $image -newest | Restore-VMSnapshot -wait
}

#Starts a VM, Passes it the rearm Command, then reboots the machine and shuts it down. 
function rearmer($image)
{
	Start-VM $image -HeartBeatTimeOut 120 -wait
	rearm($image)
	Invoke-VMShutdown $image -force
	Start-VM $image -HeartBeatTimeout 120 -wait
	Invoke-VMShutdown $image -force
}

#switches given nic for an image to the selected Virtual Switch
#problematic - does not work as of yet
function nicswap($Image, $switch)
{
	Set-vmNicSwitch $Image (Select-VMNic $Image) $switch
}

#Defining Function for VMImport
function VMImport($string)
{
   Import-VM -Paths $string -ReUseIDs
}
#function that performs rearm on remote computer
#note - host name may not be VM name. could pose issues in classes like 10174
function rearm($remote){	
    $host = [system.net.dns]::GetHostEntry($remote) | select hostname
    $hostname = $host.HostName
    if ($hostname.ToLower().Contains("contoso") = 1){
        $domain = "contoso\"
    }
    else if ($hostname.ToLower().Contains("adatum" = 1){
        $domain = "adatum\"
    }
    else {
        $domain = ""
    }
    cscript.exe c:\windows\system32\slmgr.vbs $remote $domain+"administrator" "Pa$$w0rd" /rearm
}
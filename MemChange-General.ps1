
#Importing HyperV library and tools 
import-module C:\ClassResources\PS\HyperV\HyperV.psd1
#<summary>
#Defines a function to Re-Allocate memory in hosted VMs based upon total available ram. Uses a multiplication factor based upon the available ram/8gb recommended. 
#</summary>
#<param name=image>the virtual machine object to be modified</param>
function memchange($image)
{
    #sets VM memory Multiplication Factor
    $physmem = (Get-WmiObject Win32_PhysicalMemory | measure-object Capacity -sum).sum/1gb #gets total system memory
    $mult = ($physmem / 8) #based on MS HW Level 7 - will undersetimate for L6 Classes
    #Sets VM Memory 
    $mem = Get-VMMemory $image
	$mb = $mem.VirtualQuantity
	$newmem = ($mb * $mult)
	Set-VMMemory $image $newmem
}
$vms = Get-VM
foreach($vm in $vms) {
    memchange($vm)
    } 
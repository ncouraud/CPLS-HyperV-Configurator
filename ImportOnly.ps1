#Importing HyperV library and tools 
import-module C:\ClassResources\PS\HyperV\HyperV.psd1

#<summary>
#Function that performs the import work. Mostly a cosmetic and compartmentalization thing. Doesn't seem to compress the script much
#</summary>
#<param name=path>the path to root folder of the virtual machine to be imported</param> 
function VMImport($path)
{
   Import-VM -Paths $path -ReUseIDs -wait
}

#Auto-Generation of path/array - Code Works! 
#$ClassNumber = (Read-Host "Enter class number")
cd "D:\Program Files\Microsoft Learning\" 
$classes = ls | where {$_.name -ne "Base"}
Foreach($class in $classes){
	cd $class
	cd "Drives"
	$dirs = dir | Where {$_.psIsContainer -eq $true}

	#create Arrays # Code Works! 
	$VirtualMachines = @()

	#populate Arrays - Code Works! 
	$int = $dirs.count
	$int2 = $int - 1
	$num = 0..$int2

	foreach ($i in $num) {
		$name = $dirs[$i].fullname
		$VirtualMachines = $VirtualMachines + $name
	}
}

#Import Virtual Machines -Code Works! 
foreach ($path in $VirtualMachines){
    VMImport($path)
}

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
import-module D:\HyperVImportScripts\windowspowershell\Modules\HyperV_Install\HyperV.psd1

#Running Preimport script to create symlinks in proper directory's for Base and 
#Mid-Tier drives
#cd "d:/Microsoft Learning/"
#.\PreImportScriptAll.bat

#Configuring HyperV Network Switches before import of vm's
#New-VMPrivateSwitch "Private Network"
#AutoPopulation of path
$ClassNumber = (Read-Host "Enter class number")
cd "D:\Program Files\Microsoft Learning\" 
cd $ClassNumber
cd "Drives"
$dirs = dir | Where {$_.psIsContainer -eq $true}
#create Arrays
$VirtualMachines = @()
#$vms = @()
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
#calling VMImport to define Pathnames
foreach ($path in $VirtualMachines)
{
    VMImport($path)
}
#Defining Function for VMImport
function VMImport($string){
   Import-VM -Paths $string -ReUseIDs
}
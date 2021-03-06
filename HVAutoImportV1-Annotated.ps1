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

#<summary>
#Snapshots a VM and Renames it to Starting Image
#</summary>
#<param name=image>the virtual machine object to be modified</param>
function snapshot($image)
{
	New-VMSnapshot $image -wait -force
	$snap = Get-VMSnapshot $image -newest
    $snapname = $snap.elementname
    Rename-VMSnapshot -VM $image -SnapName $snapname -NewName "Starting Image" -force
}

#<summary>
#Applies the Starting Image snapshot to teh selected virtual machine
#</summary>
#<param name=image>the virtual machine object to be modified</param>
function revert($image)
{
	$restimg = Get-VMSnapshot $image -newest 
    Restore-VMSnapshot $restimg -wait -force
}

#<summary>
#Starts a VM, Passes it the rearm Command, then reboots the machine and shuts it down.
#</summary>
#<param name=image>the virtual machine object to be modified</param>
function rearmer($image)
{
	#need to add in VM-level mutex here - rearm function will not work with multiple VMs started. 
	Start-VM $image -HeartBeatTimeOut 120 -wait #starts image for rearm command
	Start-Sleep -s 10 #Rome wasn't built in a day.... 
    rearm($image) #calls the rearm function
	#this code is to exit the script should the rearm command fail
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

#<summary>
#switches given NIC for an image to the selected Virtual Switch
#</summary>
#<param name=image>the virtual machine object to be modified</param>
#<param name=switch>the virtual network switch to be attached to the specified VM</param>
function nicswap($switch)
{
    $vms = Get-VM
    foreach ($vm in $vms){
        $machine = Get-VM $vm
        $nics = Get-VMNIC $machine
        foreach ($nic in $nics){
            Set-vmNicSwitch -VM $machine -NIC $nic -VirtualSwitch $switch
            }
    }
}

#<summary>
#Function that performs the import work. Mostly a cosmetic and compartmentalization thing. Doesn't seem to compress the script much
#</summary>
#<param name=path>the path to root folder of the virtual machine to be imported</param> 
function VMImport($path)
{
   Import-VM -Paths $path -ReUseIDs
}

#<summary>
#function that performs rearm on remote computer
#note -  if Administrator account does not have default admin 
#permissions - or UAC is necessary, this code will not work. Thsi is why we have the exception code after the rearm function is called. 
#Doesn't accept parameters - merely pulls info from the single running VM at this point. 
#</summary>
function rearm(){	
    $vm = Get-WmiObject -computerName "." -NameSpace  "Root\Virtualization"   -query "SELECT * FROM Msvm_KvpExchangeComponent" #pulls VM WMI object ExchangeComponents
    $vmitems = $vm.GuestIntrinsicExchangeItems 
    $fqdnitem = $vmitems[0] #hopefully this stays constant
    $xmlfqdn = [xml]$fqdnitem
    $FQDN = $xmlfqdn.INSTANCE.PROPERTY[1].VALUE #hopefully this is always in the same place as well. God Bless XML schemas
    SetIP($vmitems) #pull the same subnet as the VM
    Start-Sleep -s 10 #no rush here
	#could wrap the below in a function, but there's really no need for it elsewhere
    $domains = $FQDN.Split(".")
	if ($domains[-1] -eq "com"){ #code to compensate if machine is not attached to TLD
		$hostname = $domains[0] #should be hostname
		$domain = $domains[-2] #should be TLD 
	}
	else { #code to catch workgroup machines
		$hostname = $domains
		$domain = $domains
	}
    $user = $domain+"\administrator" #sets our user account to domain admin 
    #remotely run slmgr.vbs across internal network 
    cscript.exe c:\windows\system32\slmgr.vbs $hostname $user 'Pa$$w0rd' /rearm 
    #test for rearm success
	if ($LASTEXITCODE -eq 0){
        write-host "Image " $hostname "Rearmed"
        $val = 0
        return $val #necessary? 
    }
    else {
        write-host "Rearm Failed"
        $val = 1
        return $val #necessary?
    }
}

#<summary>
#This is code that I wish I could write more elegantly
#Based on the WMI ExchangeComponent it pulls the VM's IP along the internal network, and then parses it for the first 3 octets and creates an X.X.X.254 IP 
#that should allow communication with the VM along the same subnet. 
#this does mean that we're playing with the Internal Network a lot and I'm not sure how nicely it'll play if the NIC is set to DHCP in the Virtual Machine
#</summary>
#<param name=$Array>Array of VM IntrinsicExchangeComponent Items</Array>
function SetIP($Array){
    $ipitem = $Array[-4]#yay! another hack that relies on XML schemas! 
    $xmlip = [xml]$ipitem #convert string format to XML 
    $ipaddr = $xmlip.INSTANCE.PROPERTY[1].VALUE #playing with XML schemas again hopefully reliably
    $iparr = $ipaddr.SPlit(".") # create array of octets
    $iprebuild = $iparr[0]+"."+$iparr[1]+"."+$iparr[2]+".254" #1+2+3+254 = IP
    #here comes the magic
	$networkAdapters = (Get-WMIObject -computerName "." -Query "SELECT * FROM win32_networkadapter WHERE Description LIKE 'Microsoft Virtual Network Switch Adapter'");
    foreach ($adapter in $networkadapters){
         if ($adapter.AdapterType -eq "Ethernet 802.3") { #should test which is conencted to the host's internal network adapter
              $adapterindex = $adapter.Index} #index = Primary Key
         }
        $internalnetadapter = (Get-WMIObject -computerName "." -Query "SELECT * FROM win32_networkadapter WHERE Index LIKE '$adapterindex'"); #select the whole interface
        $ni = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() # why not use some .NET code, just for fun/I don't know how else to get the common name for netsh
        #make sure we have the right interface
		foreach ($iface in $ni){
          if ($iface.Description -eq $internalnetadapter.Name) {
             $name = $iface.Name}
             }
		#use netsh to set the IP 
        $netsh = netsh interface ip set address name=$name static addr=$iprebuild
        $netsh 
    }

#summary>
#configures Hyper-V Virtual Switches before use.
#first checks to see what switches are configured, 
#then sets a key to enable the switch if necessary
#</summary>
function switchprep(){
	$switch = Get-VMSwitch #get what's there already
	#take nothing for granted
	$prv = 0
	$int = 0
	$pr2 = 0
	#loop through switches, see what we're wiorking with
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
	#check what we don't have and create it
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

#Configuring HyperV Network Switches 
switchprep

# Sets up the necessary switch variables for later use. 
$server = "." #not really necessary, but lets do it anyway
$InternalSwitchName = "Internal Network"
$InternalSwitch = Get-WmiObject -computerName $server -NameSpace  "Root\Virtualization"   -query "Select * From MsVM_VirtualSwitch Where elementname like '$InternalSwitchName' " 
$PrivateSwitchName = "Private Network"
$PrivateSwitch = Get-WmiObject -computerName $server -NameSpace  "Root\Virtualization"   -query "Select * From MsVM_VirtualSwitch Where elementname like '$PrivateSwitchName' "

#Auto-Generation of path array - Takes input of what class number
#todo - automate by pulling directory objects from D:\PF\MSL\ 
$ClassNumber = "sp250-2010" #(Read-Host "Enter class number")
cd "D:\Program Files\Microsoft Learning\" 
cd $ClassNumber
cd "Drives"
$dirs = dir | Where {$_.psIsContainer -eq $true}

#create Arrays # Code Works! 
$VirtualMachines = @()

#populate Arrays - Code Works! 
$int = $dirs.count
$int2 = $int - 1
$num = 0..$int2

#create all our path objects to import
foreach ($i in $num) {
	$name = $dirs[$i].fullname
	$VirtualMachines = $VirtualMachines + $name
}
#Import Virtual Machines
#foreach ($path in $VirtualMachines){
#    VMImport($path)
#}

#configure VMs 
$vms = Get-VM #pull all imported VMS
#todo - add error checking code here to ensure proper import. 
nicswap($InternalSwitch)
foreach ($vm in $vms){
    $vmname = $vm.VMElementName
	memchange($vm) #code works! 
    rearmer($vm)
}
#hacky hacky
#foreach ($vm in $vms){
#    nicswap($PrivateSwitch)
#	snapshot($vm)
#}
#clean up after ourselves
#foreach ($vm in $vms){
#	revert($vm)
#}

#
# End Program Region
#
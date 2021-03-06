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
function rearmer($image){
	#need to add in VM-level mutex here - rearm function will not work with multiple VMs started. 
	Start-VM $image -HeartBeatTimeOut 120 -wait #starts image for rearm command
	rearm #calls the rearm function    
	#Write-Host "Shutting Down"
    Invoke-VMShutdown $image -force
    #Write-Host "Rebooting..."
    $imagename = $image.name
    $licInfo = Get-WMIObject -computername $imagename -class 'SoftwareLicensingService' 
    Start-VM $image -HeartBeatTimeout 120 -wait
    #check License Status
    if ($licInfo.LicenseStatus -eq 2){
        if ($licInfo.GracePeriodRemaining -gt 40000){
        	Invoke-VMShutdown $image -force
            }
        else{
            rearm
            Invoke-VMShutdown $image -force
            }
        }
    elseif ($licInfo.LicenseStatus -eq 3){
        if ($licInfo.GracePeriodRemaining -gt 40000){
            Invoke-VMShutdown $image -force
            }
        else{
            rearm
            Invoke-VMShutdown $image -force
            }
        }
    else{
        Write-host "Rearm Error - please Proceed Manually"
        exit        
        }     
}

#<summary>
#switches given NIC for an image to the selected Virtual Switch
#</summary>
#<param name=image>the virtual machine object to be modified</param>
#<param name=switch>the virtual network switch to be attached to the specified VM</param>
function nicswap($image, $switch)
{
	$vm = Get-VM $image 
    $nics = Get-VMNIC $vm
	foreach ($nic in $nics){
		Set-vmNicSwitch -VM $vm -NIC $nic -VirtualSwitch $Switch
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
	#could wrap the below in a function, but there's really no need for it elsewhere
    $domains = $FQDN.Split(".")
	if ($domains[-1] -eq ".com"){ #code to compensate if machine is not attached to TLD
		$hostname = $domains[0] #should be hostname
		$domain = $domain[-2] #should be TLD 
	}
	else { #code to catch workgroup machines
		$hostname = $domains
		$domain = $domains
	}
    $user = $domain+"\administrator" #sets our user account to domain admin
    #Need some way to run script on VM remotely - MORE WMI! 
    $pw = 'Pa$$w0rd'
    $password = ConvertTo-SecureString -asplaintext $pw -Force
    $cred = = new-object -typename System.Management.Automation.PSCredential -argumentlist $user,$password
    $vmlic = Get-WMIObject -computername $hostname -class 'SoftwareLicensingProduct'
    $vmlic.ReArmWindows -Impersonation 3 -Credential $cred
}

#<summary>
#This is code that I wish I could write more elegantly
#Based on the WMI ExchangeComponent it pulls the VM's IP along the internal network, and then parses it for the first 3 octets and creates an X.X.X.254 IP 
#that should allow communication with the VM along the same subnet. 
#this does mean that we're playing with the Internal Network a lot and I'm not sure how nicely it'll play if the NIC is set to DHCP in the Virtual Machine
#</summary>
#<param name=$Array>Array of VM IntrinsicExchangeComponent Items</Array>
function SetIP($Array){
    $ipitem = $Array[-2]#yay! another hack that relies on XML schemas! 
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
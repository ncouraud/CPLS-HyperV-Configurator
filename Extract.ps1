cd d:\
$dir = ls -r d:\ | where {$_.psIsContainer -eq true}
$class = $dir.name
cd $class
$bases = ls .\Base | where {$_.name -like "*.exe"}
$basenames = @()
foreach ($object in $bases){
    $basenames = $basenames + $object.fullname
    }
foreach ($base in $basenames){
    & "'c:\Program Files\WinRAR\Winrar.exe' x $base 'd:\Program Files\Microsoft Learning\Base\'"
    }
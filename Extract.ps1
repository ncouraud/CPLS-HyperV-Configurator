cd d:\Setup\Base
$bases = ls | where {$_.name -like "*.exe"}
$basenames = @()
foreach ($object in $bases){
    $basenames = $basenames + $object.fullname
    }
foreach ($base in $basenames){
    & "c:\Program Files\WinRAR\Winrar.exe" x "$base" "d:\Program Files\Microsoft Learning\Base\"
    }
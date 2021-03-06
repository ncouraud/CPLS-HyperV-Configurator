cd D:\
$batches = ls -r "D:\Program Files\Microsoft Learning\" | where {$_.name -like "*.bat"}
$configs = ls -r "D:\Program Files\Microsoft Learning\" | where {$_.name -like "*config.xml"}
foreach ($bat in $batches) {
    $filelines = Get-Content $bat.fullname.tostring()
    $max = $filelines.count
    $arrmax = $max-1
    $count = 0..$arrmax
    foreach ($i in $count) {
        $filelines[$i] = $filelines[$i].Replace("C:\", "D:\")
        }
    $filelines | Out-File $bat.fullname -Encoding "ASCII"
    }
foreach ($config in $configs) {
    $filelines = Get-Content $config.fullname.tostring()
    $max = $filelines.count
    $arrmax = $max-1
    $count = 0..$arrmax
    foreach ($i in $count) {
        $filelines[$i] = $filelines[$i].Replace("C:\", "D:\")
        }
    $filelines | Out-File $config.fullname -Encoding "ASCII"
    } 
cd D:\
$batches = ls -r "D:\Program Files\Microsoft Learning\" | where {$_.name -like "*.bat"}
foreach ($bat in $batches) {
    $file = $bat.fullname
    & $file
    }
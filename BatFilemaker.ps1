cd D:\
$batches = ls -r "D:\Program Files\Microsoft Learning\" | where {$_.name -like "*.bat"}
foreach ($bat in $batches) {
    $filelines = Get-Content $bat.fullname.tostring()
    $max = $filelines.count
    $arrmax = $max-1
    $count = 0..$arrmax
    foreach ($i in $count) {
        $filelines[$i] = $filelines[$i].Replace("C:\", "D:\")
        $filelines[$i] = $filelines[$i].Replace("c:\", "D:\")
        $filelines[$i] = $filelines[$i].Replace("pause", " ")
        $filelines[$i] = $filelines[$i].Replace("Pause", " ")
        }
    $filelines | Out-File $bat.fullname -Encoding "ASCII"
    }

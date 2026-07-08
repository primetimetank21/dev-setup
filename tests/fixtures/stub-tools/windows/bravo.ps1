# stub: bravo
param()
$n = 'bravo'
if ($env:RUN_LOG) { Add-Content -Path $env:RUN_LOG -Value $n }
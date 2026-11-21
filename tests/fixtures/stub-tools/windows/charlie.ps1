# stub: charlie
param()
$n = 'charlie'
if ($env:RUN_LOG) { Add-Content -Path $env:RUN_LOG -Value $n }
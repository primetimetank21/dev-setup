# stub: alpha
param()
$n = 'alpha'
if ($env:RUN_LOG) { Add-Content -Path $env:RUN_LOG -Value $n }
# stub: delta
param()
$n = 'delta'
if ($env:RUN_LOG) { Add-Content -Path $env:RUN_LOG -Value $n }
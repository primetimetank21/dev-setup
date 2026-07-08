# stub: prereqs
param()
$n = 'prereqs'
if ($env:RUN_LOG) { Add-Content -Path $env:RUN_LOG -Value $n }
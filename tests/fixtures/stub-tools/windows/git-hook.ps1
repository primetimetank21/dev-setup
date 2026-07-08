# stub: git-hook
param()
$n = 'git-hook'
if ($env:RUN_LOG) { Add-Content -Path $env:RUN_LOG -Value $n }
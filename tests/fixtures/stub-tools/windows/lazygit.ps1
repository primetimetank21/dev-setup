# stub: lazygit
param()
$n = 'lazygit'
if ($env:RUN_LOG) { Add-Content -Path $env:RUN_LOG -Value $n }

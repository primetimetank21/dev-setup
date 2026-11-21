# stub: dotfiles
param()
$n = 'dotfiles'
if ($env:RUN_LOG) { Add-Content -Path $env:RUN_LOG -Value $n }
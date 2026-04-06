### Linux Commands ###

function remove-custom { param([string]$path); Remove-Item -Path $path -Recurse -Force }
Remove-Item -Force Alias:\rm
Set-Alias -Name rm -Value remove-custom

function touch-custom {
    param([string]$Path)
    if (Test-Path $Path) {
        (Get-Item $Path).LastWriteTime = Get-Date
    } else {
        New-Item -ItemType File -Path $Path
    }
}
Set-Alias -Name touch -Value touch-custom


###  Git commands ###
function git-status { git status $args }
Set-Alias -Name gs -Value git-status

function git-commit { git commit $args }
Remove-Item -Force Alias:\gc
Set-Alias -Name gc -Value git-commit

function git-branch { git branch $args }
Set-Alias -Name gb -Value git-branch

function git-add { git add $args }
Set-Alias -Name ga -Value git-add

function git-log-pretty { git log --graph --abbrev-commit --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' $args }
Remove-Item -Force Alias:\gl
Set-Alias -Name gl -Value git-log-pretty

function git-log { git log $args }
Set-Alias -Name glog -Value git-log

function git-fetch { git fetch $args }
Set-Alias -Name gf -Value git-fetch

function git-fetch-prune { git fetch --prune $args }
Set-Alias -Name gfp -Value git-fetch-prune

function git-log { git log $args }
Set-Alias -Name glog -Value git-log

function git-stash { git stash $args }
Set-Alias -Name ggs -Value git-stash

function git-stash-list { git stash list $args }
Set-Alias -Name ggsls -Value git-stash-list
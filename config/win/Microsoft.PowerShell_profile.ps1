#  配置文件 
# Config DIR for Windows : C:\Users\Melin\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
#  键入如下命令来创建空白的 PowerShell 7 配置文件，它类似于 zsh 的 .zshrc 文件，会在 PowerShell 7 时自动加载并执行这个配置文件。

# Step 1 创建配置文件
#  New-Item -Path $PROFILE -Type File -Force

# Step 2 打开配置文件
# code %PROFILE


# Setp 3 激活 oh-my-posh
# oh-my-posh init pwsh | Invoke-Expression

# Setp 4 获取主题
# Get-PoshThemes


# # 首次使用请先设置允许允许远程代码执行策略
# Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Confirm
#
# # 安装 posh-git 模块
# PowerShellGet\Install-Module posh-git -Scope CurrentUser -Force


# oh-my-posh
# & ([ScriptBlock]::Create((oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\montys.omp.json" --print) -join "`n"))

& ([ScriptBlock]::Create((oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\ys.omp.json" --print) -join "`n"))


# ps-read-line
Import-Module PSReadLine

# posh-git
Import-Module posh-git

# 设置预测文本来源为历史记录
Set-PSReadLineOption -PredictionSource History

# 每次回溯输入历史，光标定位于输入内容末尾
Set-PSReadLineOption -HistorySearchCursorMovesToEnd

# 设置 Tab 为菜单补全和 Intellisense
Set-PSReadLineKeyHandler -Key "Tab" -Function MenuComplete

# 设置 Ctrl+d 为退出 PowerShell
Set-PSReadlineKeyHandler -Key "Ctrl+d" -Function ViExit

# 设置 Ctrl+z 为撤销
Set-PSReadLineKeyHandler -Key "Ctrl+z" -Function Undo

# 使用 ls 和 ll 查看目录
function ListDirectory {
    (Get-ChildItem).Name
    Write-Host("")
}
Set-Alias -Name ls -Value ListDirectory
Set-Alias -Name ll -Value Get-ChildItem

# 设置向上键为后向搜索历史记录
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward

# 设置向下键为前向搜索历史纪录
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# rm alias
Set-Alias rmrf "Remove-Item -Force -Recurse"

# touch alias
function touch {
    param (
        [string]$path
    )
    if (!(Test-Path $path)) {
        New-Item -ItemType File -Path $path
    }
    else {
        (Get-Item $path).LastWriteTime = Get-Date
    }
}


function mkdir ( $file_path) {
    New-Item $file_path -ea 0 -ItemType Directory
    }
    
    function rm ($dir_path){
    Remove-Item -Recurse -Force $dir_path
    }
    
    function mv($file_path, $des_name){
    Move-Item -Path $file_path -Destination $des_name
    }


#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module

Import-Module -Name Microsoft.WinGet.CommandNotFound
#f45873b3-b655-43a6-b217-97c00aa0db58

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}
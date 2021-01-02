# Check to see if we are currently running "as Administrator"
# See: https://github.com/mvijfschaft/dotfiles/blob/master/install.ps1


# https://github.com/lukesampson/scoop
Set-ExecutionPolicy RemoteSigned -scope CurrentUser
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')

scoop update

scoop install gcc --global
        


#validate requisite installs
#git
function confirm-application {
    param(
        [string]$name
    )
    if ($application = gcm $name -errorAction SilentlyContinue) {
        return $application.Version
    }
    else {
        return 1
    }

}




if (($version = confirm-application -name git) -ne 1) {
    write-host "Git $version is installed" 
}
else {
    write-host "Git is not installed please visit https://git-scm.com/download/win" 
}

if (($version = confirm-application -name gpg2) -ne 1) {
    write-host "GPG2 is installed" 
}
else {
    write-host "GPG is not installed please visit https://www.gpg4win.org/download.html" 
}




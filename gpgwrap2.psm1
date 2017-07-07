function Start-Command {
    Param(
        [Parameter(Mandatory = $true, Position = 1)][String]$Command,
        [Parameter(Mandatory = $false, Position = 2)][string]$Arguments,
        [Parameter(Mandatory = $false, Position = 3)][string]$OutputFile,
        [Parameter(Mandatory = $false, Position = 4)][switch]$ReturnStdOut,
        [Parameter(Mandatory = $false, Position = 5)][switch]$UseShellExecute,
        [Parameter(Mandatory = $false, Position = 6)][switch]$CreateNoWindow,
        [Parameter(Mandatory = $false, Position = 7)][switch]$RedirectStandardOutput,
        [Parameter(Mandatory = $false, Position = 8)][switch]$RedirectStandardError
    )

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $Command
    $pinfo.Arguments = $Arguments
    $pinfo.UseShellExecute = $UseShellExecute
    $pinfo.CreateNoWindow = $CreateNoWindow
    $pinfo.RedirectStandardOutput = $RedirectStandardOutput
    $pinfo.RedirectStandardError = $RedirectStandardError
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $pinfo
    $process.Start() | out-null
    $process.WaitForExit()
    if ($perror = $process.StandardError.ReadtoEnd()) {
        write-host "STDERR:"$perror
        return 1
    }
    if ($OutputFile) {
        $process.StandardOutput.ReadToEnd() | out-file $OutputFile
    }
    
    if ($ReturnStdOut) {
        return $process.StandardOutput.ReadToEnd()
    }
    else {
        return 0
    }

}

function Use-Path {
    Param(
        [Parameter(Mandatory = $true, Position = 1)][string]$Path
    )
    if (test-path $path -PathType container) {
        $validPath = resolve-path $path
        #you could use $validpath to check for other stuff like available space($validpath.drive)
        return ($validPath.path.TrimEnd("\") + "\")
    }
    elseif (test-path $path -PathType Leaf) {
        write-host "You have specified a file.  Please provide a path to a folder"
    }
    else {
        $decision = read-host "The path provided does not exist.  Create?(y/n)"
        if ($decision -eq "y") {
            $validPath = resolve-path (new-item $path -ItemType Directory)
            #you could use $validpath to check for other stuff like available space($validpath.drive)
            $output = ($validPath.path.TrimEnd("\") + "\").ToString()
            return $output
        }
        else {exit 1}
    }
}
function Initialize-GPG {
    Param(
        [Parameter(Mandatory = $false, Position = 1)][string]$GPGHomePath = "~/.gnupg")
    write-host "This command sets your GNUPGHOME environment variable toy $GPGHomePath and generates keyrings if they don't exist"
    $decision = read-host "Continue?(y/n)"
    if ($decision -eq "y") {
        $GPGHomePath = Use-Path $GPGHomePath
        [Environment]::SetEnvironmentVariable( "GNUPGHOME", $GPGHomePath, [System.EnvironmentVariableTarget]::User )
        $env:GNUPGHOME = $GPGHomePath
        gpg2 --list-keys
    }
    else {exit 1}
}

function Add-GPGKey {
    gpg2 --gen-key
}

function Get-PublicGPGKey {
    Param(
        [Parameter(Mandatory = $false, Position = 1)][string]$KeyName)
    if ($KeyName) {
        $arguments = ('--list-keys "' + $KeyName + '"')
    }
    else {
        $arguments = ('--list-keys')
    }
    $rawOutput = start-command -Command "gpg2" -Arguments $arguments -ReturnStdOut -RedirectStandardOutput -RedirectStandardError -CreateNoWindow
    if ($rawOutput -ne "1") {
        $rawOutput = $rawOutput.Split("`r`n")
        $returnValue = @()
        foreach ($item in $rawOutput) {
            if ($item.startswith("pub")) {
                $key = New-Object psobject
                $item = $item.replace("pub   ", "")
                $item = $item.Split("/"" ", 3)
                $key | Add-Member -type NoteProperty -name PrimaryKeyType -Value $item[0]
                $key | Add-Member -type NoteProperty -name PrimaryKeyName -Value $item[1]
                $key | Add-Member -type NoteProperty -name PrimaryKeyCreated -Value $item[2]
            }
            elseif ($item.startswith("uid")) {
                $key | Add-Member -type NoteProperty -name UserID -Value $item.replace("uid       ", "")
            }
            elseif ($item.startswith("sub")) {
                $item = $item.replace("sub   ", "")
                $item = $item.Split("/"" ", 3)
                $key | Add-Member -type NoteProperty -name SubKeyType -Value $item[0]
                $key | Add-Member -type NoteProperty -name SubKeyName -Value $item[1]
                $key | Add-Member -type NoteProperty -name SubKeyCreated -Value $item[2]
                $returnValue += $key
                remove-variable key
            }

        }
        return $returnValue
    }
    else {
        write-host "Key(s) not found"
        exit 1
    }
}

function Get-PrivateGPGKey {
    Param(
        [Parameter(Mandatory = $false, Position = 1)][string]$KeyName)
    if ($KeyName) {
        $arguments = ('--list-secret-keys "' + $KeyName + '"')
    }
    else {
        $arguments = ('--list-secret-keys')
    }
    $rawOutput = start-command -Command "gpg2" -Arguments $arguments -ReturnStdOut -RedirectStandardOutput -RedirectStandardError -CreateNoWindow
    if ($rawOutput -ne "1") {
        $rawOutput = $rawOutput.Split("`r`n")
        $returnValue = @()
        foreach ($item in $rawOutput) {
            if ($item.startswith("sec")) {
                $key = New-Object psobject
                $item = $item.replace("sec   ", "")
                $item = $item.Split("/"" ", 3)
                $key | Add-Member -type NoteProperty -name PrimaryKeyType -Value $item[0]
                $key | Add-Member -type NoteProperty -name PrimaryKeyName -Value $item[1]
                $key | Add-Member -type NoteProperty -name PrimaryKeyCreated -Value $item[2]
            }
            elseif ($item.startswith("uid")) {
                $item = $item.replace("uid", "")
                $item = $item.trim()
                $key | Add-Member -type NoteProperty -name UserID -Value $item
            }
            elseif ($item.startswith("ssb")) {
                $item = $item.replace("ssb   ", "")
                $item = $item.Split("/"" ", 3)
                $key | Add-Member -type NoteProperty -name SubKeyType -Value $item[0]
                $key | Add-Member -type NoteProperty -name SubKeyName -Value $item[1]
                $key | Add-Member -type NoteProperty -name SubKeyCreated -Value $item[2]
                $returnValue += $key
                remove-variable key
            }
            
        }
        return $returnValue
    }
    else {
        write-host "Key(s) not found"
        exit 1
    }
}

function Export-PublicGPGKey {

    Param(
        [Parameter(Mandatory = $true, Position = 1)][string]$PrimaryKeyName,
        [Parameter(Mandatory = $false, Position = 2)][string]$ExportPath = ".\")
    $gpgExportPath = use-path $exportPath
    $gpgExportFile = ($gpgExportPath + $PrimaryKeyName + ".public.key")

    try {
        write-host "Exporting Public Key to:"$gpgExportFile
        return (start-command -Command "gpg2" -Arguments ('--export -a "' + $PrimaryKeyName + '"') -OutputFile $gpgExportFile -RedirectStandardOutput -RedirectStandardError -CreateNoWindow) 
    }
    catch {
        write-host $_.Exception.Message
    }
}

function Export-PrivateGPGKey {

    Param(
        [Parameter(Mandatory = $true, Position = 1)][string]$PrimaryKeyName,
        [Parameter(Mandatory = $false, Position = 2)][string]$ExportPath = ".\")
    $decision = read-host "WARNING: This key is meant to be SECRET... Are you sure you want to export?(y/n)"
    if ($decision -eq "y") {
        write-host "You've been warned.  Be careful with this key.  Don't let the bad guys get it"
        $gpgExportPath = use-path $exportPath
        $gpgExportFile = ($gpgExportPath + $PrimaryKeyName + ".private.key")

        try {
            write-host "Exporting Private Key to:"$gpgExportFile
            return (start-command -Command "gpg2" -Arguments ('--export-secret-key -a "' + $PrimaryKeyName + '"') -OutputFile $gpgExportFile -RedirectStandardOutput -RedirectStandardError -CreateNoWindow) 
        }
        catch {
            write-host $_.Exception.Message
        }
    }
    else {exit 1}
}

function Import-PublicGPGKey {
    Param(
        [Parameter(Mandatory = $true, Position = 1)][string]$PublicKeyPath)
    if (test-path $PublicKeyPath -PathType Leaf) {
        try {
            write-host "Importing Public Key from:"$PublicKeyPath
            return (start-command -Command "gpg2" -Arguments ('--import "' + $PublicKeyPath + '"') -CreateNoWindow) 
        }
        catch {
            write-host $_.Exception.Message
        }
    }
    else {
        write-host "Key Path not Valid"
    }
}

function Remove-PublicGPGKey {
    Param(
        [Parameter(Mandatory = $true, Position = 1)][string]$PublicKeyName)
    if (Get-publicGPGKey -KeyName $PublicKeyName) {
        gpg --delete-keys $PublicKeyName
    }
}
function Remove-PrivateGPGKey {
    Param(
        [Parameter(Mandatory = $true, Position = 1)][string]$PrivateKeyName)
    if (Get-privateGPGKey -KeyName $PrivateKeyName) {
        gpg --quiet --yes --delete-secret-keys $PrivateKeyName
    }
}



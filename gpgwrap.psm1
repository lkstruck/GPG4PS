function new-gpgkey{
param()
gpg2 --gen-key
}

function get-gpgkey{
param()
$rawOutput = gpg2 --list-keys
$i = 0
$returnValue = @()
foreach ($item in $rawOutput)
{
Switch ($i)
{
 0 {$key = New-Object psobject}
 2 {$key | Add-Member -type NoteProperty -name PrimaryKey -Value $item.replace("pub   ","")}
 3 {$key | Add-Member -type NoteProperty -name UserID -Value $item.replace("uid       ","")}
 4 {$key | Add-Member -type NoteProperty -name SubKey -Value $item.replace("sub   ","")
    $returnValue += $key
    remove-variable key
    }
 5 {$key = New-Object psobject
    $i=1}
}
$i++

}
return $returnValue
}

#Leaving off with the parsing of the return values from get-gpgkey.  the PrimaryKey value is actually a compound value as is UserID and SubKey.  These 
#need to be separated out so that each piece of information can be access separately
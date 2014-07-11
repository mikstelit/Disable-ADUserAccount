<#
.SYNOPSIS
  Performs action on terminated users Active Directory account. 

.DESCRIPTION
  The script prompts the user for the username of the terminated user.  The script 
  then documents the terminated user's account attributes, removes the attributes, 
  removes the terminated user from groups, disables the terminated user's account, 
  and moves the terminated user's account to an OU.  
  
.OUTPUTS  
  Outputs a log file to the current working directory.  The log file is named after the 
  users Display Name.
  
.EXAMPLE  
  Disable-ADUserAccount
#>


function Get-Useraccount()
{
    $username = Read-Host "Enter the username of the account to disable "

    $user = Get-ADUser -Filter "SamAccountName -eq '$username'" -Properties *

    if($user)
    {
        return $user
    }
    else
    {
        Write-Host "Unable to find user account $username."
        exit
    }
}


function Add-CurrentAccountInfoToLog($user)
{
    Add-Content -Path $log -Value (Get-Date)
    Add-Content -Path $log -Value ("Distinguished Name: " + $user.DistinguishedName)
    Add-Content -Path $log -Value ("Attributes for " + $user.DisplayName + ":")
    foreach ($attribute in $attributes)
    {
        if($user.$attribute -ne $null)
        {
            Add-Content -Path $log -Value ("`t" + $attribute + ": " + $user.$attribute)
        }
    }
    Add-Content -Path $log -Value "******************************************"
}


function Remove-Attributes($user)
{
    try
    {
        Set-ADuser $user -OfficePhone $null -EmailAddress $null `
                            -StreetAddress $null -City $null `
                            -State $null -PostalCode $null `
                            -Country $null -ScriptPath $null `
                            -HomeDrive $null -HomeDirectory $null `
                            -MobilePhone $null -Department $null `
                            -Title $null -Company $null `
                            -Manager $null -Office $null `
                            -ErrorAction Stop
        Add-Content -Path $log -Value "SUCCESS: Removed attributes from user account."
    }
    catch
    {
        Set-LogEntry "ERROR: Unable to edit user account." $error[0].Exception
    }
}


function Remove-Groups($user)
{
    if($user.MemberOf.count -eq 0)
    {
        Add-Content -Path $log -Value ("WARNING: " + $user.DisplayName + " is not a member of any groups.")
    }
    else
    {
        foreach($group in $user.MemberOf)
        {
            $groupName = $group.split(",")[0].split("=")[1]

            try
            {
                Remove-ADGroupMember -Identity $group -Member $user.DistinguishedName -Confirm:$false -ErrorAction Stop
                Add-Content -Path $log -Value "SUCCESS: Removed user account from $groupName"
            }
            catch
            {
                Set-LogEntry "ERROR: Unable to remove user account from $groupName" $error[0].Exception
            }
        }
    }
}


function Disable-UserAccount($user)
{
    try
    {
        Disable-ADAccount -Identity $user.DistinguishedName -ErrorAction Stop
        Add-Content -Path $log -Value "SUCCESS: Disabled user account."
    }
    catch
    {
        Set-LogEntry "ERROR: Unable to disable user account." $error[0].Exception
    }
}


function Move-UserToTerminatedOU($user)
{
    $TerminatedOU = ""
    try
    {
        Move-ADObject -Identity $user.DistinguishedName -TargetPath $TerminatedOU
        Add-Content -Path $log -Value "SUCCESS: Moved user account to $TerminatedOU"
    }
    catch
    {
        Set-LogEntry "ERROR: Unable to move user account to $TerminatedOU" $error[0].Exception
    }
}


function Set-LogEntry($errorMessage, $errorException)
{
    Add-Content -Path $log -Value $errorMessage
    Add-Content -Path $log -Value $errorException
}


$attributes = ( "OfficePhone", "EmailAddress", "StreetAddress", "City", `
                "State", "PostalCode", "Country", "ScriptPath", "HomeDrive", `
                "HomeDirectory", "MobilePhone", "Department", "Title", `
                "Company", "Manager", "Office" )


$ADuser = Get-Useraccount
$log = ".\" + $ADuser.DisplayName + ".log"
Add-CurrentAccountInfoToLog $ADuser
Remove-Attributes $ADuser
Remove-Groups $ADuser
Disable-UserAccount $ADuser
Move-UserToTerminatedOU $ADuser
Write-Host "Action complete.  The log file can be found at $log."
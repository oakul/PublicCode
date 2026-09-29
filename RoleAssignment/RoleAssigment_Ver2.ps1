Connect-MgGraph -Scope "RoleEligibilitySchedule.ReadWrite.Directory", "RoleAssignmentSchedule.ReadWrite.Directory" -NoWelcome
 
$justification = "Automated activation via Microsoft Graph"
$MgContext = Get-MgContext
$User = Get-MgUser -UserId $MgContext.account
 
# Get all Eligible assignments
Write-Host "Retrieving all available Eligible role assignments..."
$eligibleAssignments = Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance -Filter "principalId eq '$($user.Id)'"
 
if (-not $eligibleAssignments) {
    Write-Host "No Eligible role assignments found for the user."
    return
}

# Retrieves already assigned roles
Write-Host "Retrieves already assigned roles..."
$existingRoles = @{}
$existingAssignments = Get-MgRoleManagementDirectoryRoleAssignmentSchedule -Filter "principalId eq '$($user.Id)'" | Where-Object AssignmentType -eq "Activated"
foreach ($assignment in $existingAssignments) {
    $existingRoles[$assignment.RoleDefinitionId] = [PSCustomObject]@{
        RoleDefinitionId = $assignment.RoleDefinitionId
        EndDateTime      = $assignment.ScheduleInfo.Expiration.EndDateTime
    }
}

 
# Retrieve role definitions based on RoleDefinitionId
Write-Host "Retrieve role definitions based on RoleDefinitionId..."
$roleDefinitions = @{}
$roleDefinitionId = @{}

foreach ($assignment in $eligibleAssignments) {
    if (-not $roleDefinitions.ContainsKey($assignment.RoleDefinitionId)) {
        $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $assignment.RoleDefinitionId
        $roleDefinitions[$assignment.Id] = $roleDefinition.DisplayName
        
    }
}

# Retrieve permanent assigments
Write-Host "Retrieve permanent roles..."
$permanentDefinitions = @{}
$permanentAssignments = Get-MgRoleManagementDirectoryRoleAssignmentSchedule -Filter "principalId eq '$($user.Id)'" | Where-Object AssignmentType -eq "Assigned"

foreach ($assiged in $permanentAssignments) {
    if (-not $roleDefinitions.ContainsKey($assiged.RoleDefinitionId)) {
        $permanentDefinition = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $assiged.RoleDefinitionId
        $permanentDefinitions[$assiged.Id] = $permanentDefinition.DisplayName
        Write-Host $permanentDefinitions[$assiged.Id] -ForegroundColor Red    }
}
 
# Show available roles and let the user choose
$ii = 0
Write-Host "Select the roles you want to activate (enter numbers separated by commas), or 0 to remove all:"
$eligibleAssignments | ForEach-Object -Begin { $i = 0 } -Process {
    $i++
    $finnes = $true
    $roleDisplayName = $roleDefinitions[$_.Id] ? $roleDefinitions[$_.Id] : "(Unknown role name)"
    foreach ($role in $existingRoles) {
    #Write-Host "ExistingRoles: " $role
    #Write-Host "eligibleAssignments: " $eligibleAssignments[$i-1].RoleDefinitionId
        if ($existingRoles.Values.RoleDefinitionId -eq $eligibleAssignments[$i-1].RoleDefinitionId) {
            $finnes = $true
        } else {
            $finnes = $false
      }
    }
    If ($finnes) {
        $EndingTime = $role.Values.EndDateTime[$ii].AddHours(2)
        Write-Host "[$i] $roleDisplayName (Ends: $EndingTime)" -ForegroundColor Green
        $ii++
        } else {
            Write-Host "[$i] $roleDisplayName" -ForegroundColor Blue
         }
}
 
# Read the user's choices and convert to a list of roles
$selectedIndexes = Read-Host "Enter numbers separated by commas"
$selectedIndexes = $selectedIndexes -split "," | ForEach-Object { $_.Trim() -as [int] }
 
# Retrieve the selected roles based on the user's selection
$roles = @()
for ($i = 0; $i -lt $selectedIndexes.Length; $i++) {
    $index = $selectedIndexes[$i] - 1
    if ($index -ge 0 -and $index -lt $eligibleAssignments.Count) {
        $roles += $roleDefinitions[$eligibleAssignments[$index].Id]
    }
}

if ($selectedIndexes -contains 0)
    {
    Write-Output "Dectivating ALL Entra roles for: "$MgContext.Account"" 
    
foreach ($assignment in $existingAssignments) {

    $activeMinutes = ((Get-Date) - $assignment.CreatedDateTime.AddHours(2)).TotalMinutes
    $RoleNameToRemove = (Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $assignment.RoleDefinitionId).Displayname
    Write-Host "$RoleNameToRemove active for : $([int]$activeMinutes) min"

    if ($activeMinutes -lt 5) {
        Write-Host "Skipping role - activated less than 5 min ago." -ForegroundColor Yellow
        continue
    }

    $params = @{
        Action           = "AdminRemove"
        PrincipalId      = $assignment.PrincipalId
        RoleDefinitionId = $assignment.RoleDefinitionId
        DirectoryScopeId = $assignment.DirectoryScopeId
        Justification    = "Bulk role cleanup"
        }
    New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $params
        }
    }
else {

    Write-Output "Activating Entra roles for: "$MgContext.Account""
 
    foreach ($role in $roles) {
        $myRoles = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -ExpandProperty RoleDefinition -All -Filter "principalId eq '$($user.Id)'"
        $myRoleName = $myroles | Select-Object -ExpandProperty RoleDefinition | Where-Object { $_.DisplayName -eq $role }
        $myRoleNameid = $myRoleName.Id
        $myRole = $myroles | Where-Object { $_.RoleDefinitionId -eq $myRoleNameid }
        $params = @{
            Action           = "selfActivate"
            PrincipalId      = $User.Id
            RoleDefinitionId = $myRole.RoleDefinitionId
            DirectoryScopeId = $myRole.DirectoryScopeId
            Justification    = $justification
            ScheduleInfo     = @{
                StartDateTime = Get-Date
                Expiration    = @{
                    Type     = "AfterDuration"
                    Duration = "PT4H"
                    }
            }
        }
    New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $params
    Write-Output "Activated Entra role: "$role""
    }
}

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
foreach ($existing in $existingRoles) {
        $existingRole= Get-MgRoleManagementDirectoryRoleAssignment -Filter "principalId eq '$($user.Id)'"
        $existingRoles = $existingRole.RoleDefinitionId
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
 
# Show available roles and let the user choose
Write-Host "Select the roles you want to activate (enter numbers separated by commas):"
$eligibleAssignments | ForEach-Object -Begin { $i = 0 } -Process {
    $i++
    $finnes = $true
    $roleDisplayName = $roleDefinitions[$_.Id] ? $roleDefinitions[$_.Id] : "(Unknown role name)"
    foreach ($role in $existingRoles) {
    #Write-Host "ExistingRoles: " $role
    #Write-Host "eligibleAssignments: " $eligibleAssignments[$i-1].RoleDefinitionId
        if ($existingRoles -eq $eligibleAssignments[$i-1].RoleDefinitionId) {
            $finnes = $true
        } else {
            $finnes = $false
      }
    }
    If ($finnes) {
        Write-Host "[$i] $roleDisplayName" -ForegroundColor Green
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
 
pause

function Copy-OctopusProjectRunbooks
{
    param(
        $sourceChannelList,
        $destinationChannelList,
        $destinationProject,        
        $sourceProject,
        $sourceData,
        $destinationData
    )

    if ($sourceData.HasRunbooks -eq $false -or $destinationData.HasRunbooks -eq $false)
    {
        Write-OctopusWarning "The source or destination do not have runbooks, skipping the runbook clone process"
        return
    }

    $sourceRunbooks = Get-OctopusProjectRunbookList -project $sourceProject -OctopusData $sourceData
    $destinationRunbooks = Get-OctopusProjectRunbookList -project $destinationProject -OctopusData $DestinationData

    $filteredList = Get-OctopusFilteredList -itemList $sourceRunbooks -itemType "Project Runbooks" -filters $cloneScriptOptions.RunbooksToClone

    if ($filteredList.length -eq 0)
    {
        return
    }

    foreach ($runbook in $filteredList)
    {
        $destinationRunbook = Get-OctopusItemByName -ItemList $destinationRunbooks -ItemName $runbook.Name
        
        if ($null -eq $destinationRunbook)
        {
            $runbookToClone = Copy-OctopusObject -ItemToCopy $runbook -SpaceId $destinationData.SpaceId -ClearIdValue $true
            
            $runbookToClone.ProjectId = $destinationProject.Id
            $runbookToClone.PublishedRunbookSnapshotId = $null
            $runbookToClone.RunbookProcessId = $null 
            
            Convert-OctopusRunbookEnvironmentIdList -runbookToClone $runbookToClone -sourceData $sourceData -destinationData $destinationData

            Write-OctopusVerbose "The runbook $($runbook.Name) for $($destinationProject.Name) doesn't exist, creating it now"            
            $destinationRunbook = Save-OctopusProjectRunbook -Runbook $runbookToClone -DestinationData $destinationData
        }
        
        $sourceRunbookProcess = Get-OctopusRunbookProcess -runbook $runbook -OctopusData $sourceData
        $destinationRunbookProcess = Get-OctopusRunbookProcess -runbook $destinationRunbook -OctopusData $DestinationData

        Write-OctopusPostCloneCleanUp "*****************Starting Sync for runbook process $($runbook.Name)***************"        
        $destinationRunbookProcess.Steps = @(Copy-OctopusDeploymentProcess -sourceChannelList $sourceChannelList -destinationChannelList $destinationChannelList -sourceData $sourceData -destinationData $destinationData -sourceDeploymentProcessSteps $sourceRunbookProcess.Steps -destinationDeploymentProcessSteps $destinationRunbookProcess.Steps)
        Write-OctopusPostCloneCleanUp "*****************End Sync for runbook process $($runbook.Name)********************"        
            
        Save-OctopusProjectRunbookProcess -RunbookProcess $destinationRunbookProcess -DestinationData $destinationData        
    }
}

function Convert-OctopusRunbookEnvironmentIdList
{
    param (
        $runbookToClone,
        $sourceData,
        $destinationData
    )

    if ((Test-OctopusObjectHasProperty -objectToTest $runbookToClone -propertyName "Environments"))
    {
        $runbookToClone.Environments = @(Convert-SourceIdListToDestinationIdList -SourceList $SourceData.EnvironmentList -DestinationList $DestinationData.EnvironmentList -IdList $runbookToClone.Environments)        
    }
}
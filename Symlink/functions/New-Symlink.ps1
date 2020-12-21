﻿<#
.SYNOPSIS
	Creates a new symlink.
	
.DESCRIPTION
	Creates a new symlink definition in the database, and then creates the
	symbolic-link item on the filesystem.
	
.PARAMETER Name
	The name/identifier of this symlink (must be unique).
	
.PARAMETER Path
	The location of the symbolic-link item on the filesystem. If any parent
	folders defined in this path don't exist, they will be created.
	
.PARAMETER Target
	The location which the symbolic-link will point to. This defines whether
	the link points to a folder or file.
	
.PARAMETER CreationCondition
	A scriptblock which decides whether the symbolic-link is actually 
	created or not. This does not affect the creation of the symlink
	definition within the database. For more details about this, see the
	help at: about_Symlink.
	
.PARAMETER DontCreateItem
	Skips the creation of the symbolic-link item on the filesystem.
	
.PARAMETER MoveExistingItem
	If there is already a folder or file at the path, this item will be moved
	to the target location (and potentially renamed), rather than being deleted.
	
.PARAMETER WhatIf
	Prints what actions would have been done in a proper run, but doesn't
	perform any of them.
	
.PARAMETER Confirm
	Prompts for user input for every "altering"/changing action.
	
.INPUTS
	None
	
.OUTPUTS
	Symlink
	
.NOTES
	For detailed help regarding the 'Creation Condition' scriptblock, see
	the help at: about_Symlink.
	This command is aliased to 'nsl'.
	
.EXAMPLE
	PS C:\> New-Symlink -Name "data" -Path ~\Documents\Data -Target D:\Files
	
	This command will create a new symlink definition, named "data", and a
	symbolic-link located in the user's document folder under a folder also
	named "data", pointing to a folder on the D:\ drive.
	
.EXAMPLE
	PS C:\> New-Symlink -Name "data" -Path ~\Documents\Data -Target D:\Files
				-CreationCondition $script -DontCreateItem
	
	This command will create a new symlink definition, named "data", but it
	will not create the symbolic-link on the filesystem. A creation condition
	is also defined, which will be evaluated when the 'Build-Symlink' command
	is run in the future.
	
.EXAMPLE
	PS C:\> New-Symlink -Name "program" -Path ~\Documents\Program
				-Target D:\Files\my_program -MoveExistingItem
				
	This command will first move the folder 'Program' from '~\Documents' to 
	'D:\Files', and then rename it to 'my_program'. Then the symbolic-link will
	be created.
	
#>
function New-Symlink
{
	[Alias("nsl")]
	# TODO: Add -Force switch to ignore the creation condition
	[CmdletBinding(SupportsShouldProcess = $true)]
	param
	(
		
		[Parameter(Position = 0, Mandatory = $true)]
		[string]
		$Name,
		
		[Parameter(Position = 1, Mandatory = $true)]
		[string]
		$Path,
		
		[Parameter(Position = 2, Mandatory = $true)]
		[string]
		$Target,
		
		[Parameter(Position = 3)]
		[scriptblock]
		$CreationCondition,
		
		[Parameter(Position = 4)]
		[switch]
		$MoveExistingItem,
		
		[Parameter(Position = 5)]
		[switch]
		$DontCreateItem
		
	)
	
	Write-Verbose "Validating name."
	# Validate that the name isn't empty.
	if ([System.String]::IsNullOrWhiteSpace($Name))
	{
		Write-Error "The name cannot be blank or empty!"
		return
	}
	
	# Validate that the target location exists.
	if (-not (Test-Path -Path ([System.Environment]::ExpandEnvironmentVariables($Target)) `
			-ErrorAction Ignore) -and -not $MoveExistingItem)
	{
		Write-Error "The target path: '$Target' points to an invalid/non-existent location!"
		return
	}
	
	# Read in the existing symlink collection.
	$linkList = Read-Symlinks
	
	# Validate that the name isn't already taken.
	$existingLink = $linkList | Where-Object { $_.Name -eq $Name }
	if ($null -ne $existingLink)
	{
		Write-Error "The name: '$Name' is already taken!"
		return
	}
	
	Write-Verbose "Creating new symlink object."
	# Create the new symlink object.
	if ($null -eq $CreationCondition)
	{
		$newLink = [Symlink]::new($Name, $Path, $Target)
	}
	else
	{
		$newLink = [Symlink]::new($Name, $Path, $Target, $CreationCondition)
	}
	# Add the new link to the list, and then re-export the list.
	$linkList.Add($newLink)
	if ($PSCmdlet.ShouldProcess("$script:DataPath", "Overwrite database with modified one"))
	{
		Export-Clixml -Path $script:DataPath -InputObject $linkList -WhatIf:$false -Confirm:$false | Out-Null
	}
	
	# Potentially move the existing item.
	if ((Test-Path -Path $Path) -and $MoveExistingItem)
	{
		if ($PSCmdlet.ShouldProcess("$Path", "Move existing item"))
		{
			# If the item needs renaming, split the filepaths to construct the
			# valid filepath.
			$finalPath = [System.Environment]::ExpandEnvironmentVariables($Target)
			$finalContainer = Split-Path -Path $finalPath -Parent
			$finalName = Split-Path -Path $finalPath -Leaf
			$existingPath = $Path
			$existingContainer = Split-Path -Path $existingPath -Parent
			$existingName = Split-Path -Path $existingPath -Leaf
			
			# Only rename the item if it needs to be called differently.
			if ($existingName -ne $finalName)
			{
				Rename-Item -Path $existingPath -NewName $finalName -WhatIf:$false -Confirm:$false
				$existingPath = Join-Path -Path $existingContainer -ChildPath $finalName
			}
			Move-Item -Path $existingPath -Destination $finalContainer -WhatIf:$false -Confirm:$false
		}
	}
	
	# Build the symlink item on the filesytem.
	if (-not $DontCreateItem -and $PSCmdlet.ShouldProcess($newLink.FullPath(), "Create Symbolic-Link"))
	{
		$newLink.CreateFile()
	}
	
	Write-Output $newLink
}
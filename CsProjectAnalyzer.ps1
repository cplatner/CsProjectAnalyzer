<#
.SYNOPSIS
  Analyze a .csproj files in a .sln to see if files on disk are extra or missing.

.PARAMETER name
  File to analyze

.EXAMPLE
    .\CsProjectAnalyzer.ps1 tests\test.sln

.NOTES
  Make sure PowerShell is installed on Windows.  It probably is, but if not,
  it is a standard Windows package.
#>

param ([string] $name)

if ($Host.Version.Major -lt 2) {
	Write-Host "Need at least PowerShell v2.0" -foregroundcolor red -backgroundcolor yellow
	Exit
}

if ($name -eq $null -or -not (Test-Path -PathType Leaf $name)) {
	Write-Host "Specify a valid project file" -foregroundcolor red -backgroundcolor yellow
	Exit
}

################################################################################
## Functions
################################################################################

Function AnalyzeCsProj([string] $name)
{
	##Write-Host "Analyzing $name"
	"Analyzing $name"
	$basedir = Split-Path -Parent $name
	$prj = Split-Path -Leaf $name

	$filesInProject = @{}
	# Add in the project, since it will be found, but will not exist in the project
	$filesInProject[$prj] = $name;

	$xml = [xml] (Get-Content $name)

	foreach ($node in $xml.SelectNodes("//*[@Include]"))
	{
		$inc = $node.Name
		if (!($inc -eq "Reference" -or $inc -eq "COMReference" -or $inc -eq "WebReferenceUrl" -or $inc -eq "BootstrapperPackage" -or $inc -eq "Service")) {
			$path = Join-Path -Path $basedir -Childpath $node.Include
			$filesInProject[$node.Include] = $path;

			if (! (Test-Path $path))
			{
				"Can't find $path"
			}
		}
	}

	$filesOnDisk = Get-ChildItem -Recurse $basedir -Name |
		Where { $_ -notmatch "bin" -and $_ -notmatch "obj" -and $_ -notmatch ".svn" }

	$filesOnDiskButNotInProject = @()

	foreach ($file in $filesOnDisk)
	{
		if (! $filesInProject.ContainsKey($file)) {
			$path = Join-Path -Path $basedir -Childpath $file

			if (! (Test-Path $path -PathType Container)) {
				$filesOnDiskButNotInProject += $file
			}
		}
	}

	if ($filesOnDiskButNotInProject)
	{
		#Write-Host "Files on disk, but not in project"
		"Files on disk, but not in project"
		foreach ($file in $filesOnDiskButNotInProject)
		{
			"`t$file"
		}
	}
}

Function ReadSolution([string] $file)
{
	Write-Host "Analyzing $file"
	$basedir = Split-Path -Parent $file
	$prj = Split-Path -Leaf $file

	$filesInSolution = @()

	$content = Get-Content $file

	foreach ($line in $content) {
		if ($line -match "^Project" -and $line -match "{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") {
			$file = ($line -Split ",")[1]
			$file = $file.Trim()
			$file = $file -Replace '^\"', ''
			$file = $file -Replace '"$', ''

			$file
		}
	}
}

################################################################################
## Main
################################################################################

$fullpath = Split-Path -Parent (Resolve-Path $name)

$files = ReadSolution $name
foreach ($file in $files) {
	$project = Resolve-Path (Join-Path $fullpath $file)
	AnalyzeCsProj $project
}

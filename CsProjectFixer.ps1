<#
.SYNOPSIS
  Fix .csproj files in a .sln
  Fixing means taking care of targets, unused attributes, remnants of upgrading, etc.

  This fixes almost everything automatically, although there are a couple of places that it doesn't
  work too well yet.  One of them is making sure that all of the old defined symbols get copied
  over to a new

.PARAMETER name
  One of three possibilities:
    Solution to fix all the project files for.
	Directory to recurse looking for *.csproj
	A single project

.EXAMPLE
    .\CsProjectFixer.ps1 tests\test.sln
#>

param ([string] $name)

if ($name -eq $null -or -not (Test-Path -PathType Any $name)) {
	Write-Host "Specify a valid project file" -foregroundcolor red -backgroundcolor yellow
	Exit
}

################################################################################
## Functions
################################################################################

Function RemoveNodes([string] $xpath)
{
    $changed = $false
    foreach ($node in $xml.SelectNodes($xpath, $ns)) {
	    [void] $node.ParentNode.RemoveChild($node)
	    $changed = $true
	}
    return $changed
}

# Uses the global XML object, $xml
# Uses a global namespace, $ns
Function CheckForTargetSection([string] $sectionXpath, [string] $nodeName, [string] $attributeName, [string] $attributeValue)
{
    $changed = $false

	$sectionNode = $xml.SelectSingleNode($sectionXpath, $ns)
	if (-not $sectionNode) {
		$node = $xml.CreateElement($nodeName, $xml.DocumentElement.NamespaceURI)
        # Visual Studio requires the target properties to be in a specific order (before
        # the <ItemGroup> tag), or it won't work.
		$dummy = $xml.Project.InsertBefore($node, $xml.Project.ItemGroup[0])
		#$node.InnerText = $value
		$node.SetAttribute($attributeName, $attributeValue)
		$changed = $true
    }

    return $changed
}

# Can't pass an XML element to a function
# Uses the global XML object, $xml
# Uses a global namespace, $ns
Function UpdateTargetSection([string] $sectionXpath, [string] $xpath, [string] $nodeName, [string] $value)
{
    $changed = $false

	$sectionNode = $xml.SelectSingleNode($sectionXpath, $ns)
	if ($sectionNode) {
    	$childNode = $sectionNode.SelectSingleNode($xpath, $ns)

	    if (-not $childNode) {
		    $node = $xml.CreateElement($nodeName, $xml.DocumentElement.NamespaceURI)
		    $dummy = $sectionNode.AppendChild($node)
		    $node.InnerText = $value
		    $changed = $true
	    }
	    else {
		    if ($childNode.InnerText -ne $value) {
		        $childNode.InnerText = $value
		        $changed = $true
            }
	    }
	}
	else {
		Write-Host "!!No $sectionXpath Section"
	}

    return $changed
}

Function FixCsProj([string] $name)
{
	Write-Host "$name : Analyzing..."
	$changedProject = $false
	$basedir = Split-Path -Parent $name
	$prj = Split-Path -Leaf $name

	[xml] $xml = [xml] (Get-Content $name)

    $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $ns.AddNamespace("ns", $xml.DocumentElement.NamespaceURI)


	############################################################################
	## Fixes for the main property group
	############################################################################
	$maingroup = $xml.Project.PropertyGroup[0]

	# Clean up old product versions
	$prodversion = $maingroup.ProductVersion
	if ($prodversion -like "8.0*" -or $prodversion -like "9.0.2*") {
		$maingroup.ProductVersion = "9.0.30729"
		$changedProject = $true
	}

	# Make sure all files have TargetFrameworkVersion = v4.0
	if (-not $maingroup.TargetFrameworkVersion) {
		$dummy = $maingroup.AppendChild(
			$xml.CreateElement('TargetFrameworkVersion', $xml.DocumentElement.NamespaceURI))
		$changedProject = $true
	}
	if ($maingroup.TargetFrameworkVersion -ne "v4.0") {
		$maingroup.TargetFrameworkVersion = "v4.0"
		$changedProject = $true
	}

	# Make sure all files have WarningLevel = 4
##    $section = "//*[contains(@Condition,'Debug|AnyCPU')]"
##    $changedProject = UpdateTargetSection $section "ns:DebugSymbols" "DebugSymbols" "true" ? $true : $changedProject

#	if (-not $maingroup.WarningLevel) {
#		$node = $maingroup.AppendChild(
#			$xml.CreateElement('WarningLevel', $xml.DocumentElement.NamespaceURI))
#		$changedProject = $true
#	}
#	if ($maingroup.WarningLevel -ne "4") {
#		$maingroup.WarningLevel = "4"
#		$changedProject = $true
#	}

	# To be done:
	#   FileAlignment - always set to 512

    if (RemoveNodes "//ns:PropertyGroup/ns:OldToolsVersion") { $changedProject = $true }
    if (RemoveNodes "//ns:PropertyGroup/ns:DocumentationFile") { $changedProject = $true }
    if (RemoveNodes "//ns:PropertyGroup/ns:UpgradeBackupLocation") { $changedProject = $true }
    if (RemoveNodes "//ns:Reference/ns:RequiredTargetFramework") { $changedProject = $true }
    if (RemoveNodes "//ns:PropertyGroup/ns:FileUpgradeFlags") { $changedProject = $true }
    if (RemoveNodes "//ns:ItemGroup/ns:BootstrapperPackage[contains(@Include,'3.5')]") { $changedProject = $true }
    if (RemoveNodes "//ns:ItemGroup/ns:BootstrapperPackage[contains(@Include,'3.1')]") { $changedProject = $true }
	############################################################################
	## Fixes for the specific build targets
	############################################################################
	# Fix up Debug AnyCPU section
    #############################
    $section = "//*[contains(@Condition,'Debug|AnyCPU')]"
    if (CheckForTargetSection $section "PropertyGroup" "Condition" " '`$(Configuration)|`$(Platform)' == 'Debug|AnyCPU' ") { $changedProject = $true }

    if (UpdateTargetSection $section "ns:DebugSymbols" "DebugSymbols" "true") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:DebugType" "DebugType" "full") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:Optimize" "Optimize" "false") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:OutputPath" "OutputPath" "..\bin\Debug\") { $changedProject = $true }
#    <DefineConstants>DEBUG;TRACE</DefineConstants>
    #if (UpdateTargetSection $section "ns:DefineConstants" "DefineConstants" "DEBUG;TRACE") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:ErrorReport" "ErrorReport" "prompt") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:WarningLevel" "WarningLevel" "4") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:PlatformTarget" "PlatformTarget" "AnyCPU") { $changedProject = $true }

	# Fix up the Release AnyCPU section
    ###################################
    $section = "//*[contains(@Condition,'Release|AnyCPU')]"
    if (CheckForTargetSection $section "PropertyGroup" "Condition" " '`$(Configuration)|`$(Platform)' == 'Release|AnyCPU' ") { $changedProject = $true }

    #if (UpdateTargetSection $section "ns:DebugSymbols" "DebugSymbols" "true") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:DebugType" "DebugType" "none") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:Optimize" "Optimize" "true") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:OutputPath" "OutputPath" "..\bin\Release\") { $changedProject = $true }
#    <DefineConstants>DEBUG;TRACE</DefineConstants>
    #if (UpdateTargetSection $section "ns:DefineConstants" "DefineConstants" "TRACE") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:ErrorReport" "ErrorReport" "prompt") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:WarningLevel" "WarningLevel" "4") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:PlatformTarget" "PlatformTarget" "AnyCPU") { $changedProject = $true }

	# Fix up the Training AnyCPU section
    ###################################
    $section = "//*[contains(@Condition,'Training|AnyCPU')]"
    if (CheckForTargetSection $section "PropertyGroup" "Condition" " '`$(Configuration)|`$(Platform)' == 'Training|AnyCPU' ") { $changedProject = $true }
    # for now, include debug symbols
    if (UpdateTargetSection $section "ns:DebugSymbols" "DebugSymbols" "true") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:DebugType" "DebugType" "pdbonly") { $changedProject = $true }
    #if (UpdateTargetSection $section "ns:DebugType" "DebugType" "none") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:Optimize" "Optimize" "true") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:OutputPath" "OutputPath" "..\bin\Training\") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:DefineConstants" "DefineConstants" "TRACE;TRAINING") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:ErrorReport" "ErrorReport" "prompt") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:WarningLevel" "WarningLevel" "4") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:PlatformTarget" "PlatformTarget" "AnyCPU") { $changedProject = $true }

	# Fix up Debug x86 section
    ##########################
    $section = "//*[contains(@Condition,'Debug|x86')]"
    if (CheckForTargetSection $section "PropertyGroup" "Condition" " '`$(Configuration)|`$(Platform)' == 'Debug|x86' ") { $changedProject = $true }

    if (UpdateTargetSection $section "ns:DebugSymbols" "DebugSymbols" "true") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:DebugType" "DebugType" "full") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:Optimize" "Optimize" "false") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:OutputPath" "OutputPath" "..\bin\x86\Debug\") { $changedProject = $true }
#    <DefineConstants>DEBUG;TRACE</DefineConstants>
    #if (UpdateTargetSection $section "ns:DefineConstants" "DefineConstants" "DEBUG;TRACE") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:ErrorReport" "ErrorReport" "prompt") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:WarningLevel" "WarningLevel" "4") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:PlatformTarget" "PlatformTarget" "x86") { $changedProject = $true }

	# Fix up the Release x86 section
    ################################
    $section = "//*[contains(@Condition,'Release|x86')]"
    if (CheckForTargetSection $section "PropertyGroup" "Condition" " '`$(Configuration)|`$(Platform)' == 'Release|x86' ") { $changedProject = $true }

    #if (UpdateTargetSection $section "ns:DebugSymbols" "DebugSymbols" "true") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:DebugType" "DebugType" "none") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:Optimize" "Optimize" "true") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:OutputPath" "OutputPath" "..\bin\x86\Release\") { $changedProject = $true }
#    <DefineConstants>DEBUG;TRACE</DefineConstants>
    #if (UpdateTargetSection $section "ns:DefineConstants" "DefineConstants" "TRACE") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:ErrorReport" "ErrorReport" "prompt") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:WarningLevel" "WarningLevel" "4") { $changedProject = $true }
    if (UpdateTargetSection $section "ns:PlatformTarget" "PlatformTarget" "x86") { $changedProject = $true }

    # Special case for any exes.  Build as x86
    # (see AnyCPU Exes are usually more trouble than they're worth
    #   http://blogs.msdn.com/b/rmbyers/archive/2009/06/8/anycpu-exes-are-usually-more-trouble-then-they-re-worth.aspx
    ##########################
    if ($maingroup.OutputType -eq "WinExe" -or $maingroup.OutputType -eq "Exe") {
        $section = "//*[contains(@Condition,'Debug|AnyCPU')]"
        if (UpdateTargetSection $section "ns:PlatformTarget" "PlatformTarget" "x86") { $changedProject = $true }

        $section = "//*[contains(@Condition,'Release|AnyCPU')]"
        if (UpdateTargetSection $section "ns:PlatformTarget" "PlatformTarget" "x86") { $changedProject = $true }

        $section = "//*[contains(@Condition,'Training|AnyCPU')]"
        if (UpdateTargetSection $section "ns:PlatformTarget" "PlatformTarget" "x86") { $changedProject = $true }
    }

	############################################################################
	## General fixes
	############################################################################
	# Build path for targets
	if ($xml.Project.Import.Project -like '*MSBuildBinPath*') {
		$xml.Project.Import.Project = '$(MSBuildToolsPath)\Microsoft.CSharp.targets'
		$changedProject = $true
	}

	# Save it
	if ($changedProject) {
		Write-Host " Fixing..."
		#Copy-Item $name ($name + ".save")
		$xml.Save($name)
	}
	Write-Host "Done"
}

# Read a solution, and find all of the *.csproj files that are referenced in it.
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
            $filesInSolution += $file
		}
	}

    return $filesInSolution
}

# Find all *.csproj files in a given directory recursively
Function FindCsprojFiles([string] $dir)
{
    $files = Get-ChildItem -Include *.csproj -Recurse $dir |  % { $_.FullName }

    return $files
}


################################################################################
## Main
################################################################################
$isSolution = $false
$isProject = $false
$files = @()
if ($name -match ".sln") {
    $isSolution = $true
}
elseif ($name -match ".csproj") {
    $isProject = $true
}

$fullpath = Split-Path -Parent (Resolve-Path $name)

if ($isSolution) {
    $files = ReadSolution $name
}
elseif (-not $isProject) {
    $files = FindCsProjFiles $name
}

if ($files) {
    foreach ($file in $files) {
        if ($isSolution) {
	        $project = Resolve-Path (Join-Path $fullpath $file)
        }
        elseif (-not $isProject) {
    	    $project = $file
        }
	    FixCsProj $project
    }
}
else {
    $project = Resolve-Path $name
    FixCsProj $project
}
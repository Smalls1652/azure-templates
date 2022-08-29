[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TemplateFilePath
)

$scriptRoot = $PSScriptRoot

# Resolve the file path and get data about the file.
$templateFilePathResolved = (Resolve-Path -Path $TemplateFilePath -ErrorAction "Stop").Path
$templateFileItem = Get-Item -Path $templateFilePathResolved

# If the file does not have the extension '.bicep', throw a terminating error.
if ($templateFileItem.Extension -ne ".bicep") {
    $PSCmdlet.ThrowTerminatingError(
        [System.Management.Automation.ErrorRecord]::new(
            [System.IO.FileLoadException]::new("Specified file item, '$($templateFileItem.Name)', is not a Bicep template."),
            "InvalidTemplateFile",
            [System.Management.Automation.ErrorCategory]::InvalidArgument,
            $templateFileItem
        )
    )
}

# Initialize a regex object for parsing the directory path of the supplied template file.
$filePathRegex = [regex]::new("^$($scriptRoot.Replace("\", "\\"))\\templates\\(?'dirPath'.+)\\.+?\..+?$")

# Get the directory path of the template file.
$filePathDirRegexMatch = $filePathRegex.Match($templateFileItem.FullName)
$filePathDir = $filePathDirRegexMatch.Groups["dirPath"].Value

# Define the local path to 'compiled-templates\' and, if needed, create the directory.
$compiledDirPath = Join-Path -Path $scriptRoot -ChildPath "compiled-templates\"
if (!(Test-Path -Path $compiledDirPath)) {
    Write-Warning "Root compiled templates directory (Located at '$($compiledDirPath)') doesn't exist. Creating..."
    $null = New-Item -Path $compiledDirPath -ItemType "Directory"
}

# Define the directory path to export the compiled template file and, if needed, create the directory/directories.
# Note: This path will be a direct replica of where the file is in the templates directory.
$compiledFileDirPath = Join-Path -Path $compiledDirPath -ChildPath $filePathDir
if (!(Test-Path -Path $compiledFileDirPath)) {
    Write-Warning "Compiled template path (Located at '$($compiledFileDirPath)') doesn't exist. Creating..."
    $null = New-Item -Path $compiledFileDirPath -ItemType "Directory"
}

# Define the path to the compiled template file.
$compiledFilePath = Join-Path -Path $compiledFileDirPath -ChildPath "$($templateFileItem.BaseName).json"

# Compile the template
Write-Verbose "Compiling '$($templateFileItem.Name)' to an Azure ARM template file."
bicep build "$($templateFileItem.FullName)" --outfile "$($compiledFilePath)"
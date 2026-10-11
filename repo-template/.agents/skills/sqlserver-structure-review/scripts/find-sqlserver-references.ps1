[CmdletBinding()]
param(
    [string]$Path = ".",
    [switch]$SummaryOnly,
    [ValidateRange(1, 100000)]
    [int]$MaxResults = 200
)

$ErrorActionPreference = "Stop"

$resolvedPath = (Resolve-Path -LiteralPath $Path).Path
if (-not (Test-Path -LiteralPath $resolvedPath -PathType Container)) {
    throw "Path must be a directory."
}

$patterns = [ordered]@{
    "EF FromSqlRaw" = "FromSqlRaw"
    "EF FromSqlInterpolated" = "FromSqlInterpolated"
    "EF ExecuteSqlRaw" = "ExecuteSqlRaw"
    "EF ExecuteSqlInterpolated" = "ExecuteSqlInterpolated"
    "SqlCommand" = "SqlCommand"
    "StoredProcedure CommandType" = "CommandType\.StoredProcedure"
    "Dapper ExecuteAsync" = "\.ExecuteAsync\s*\("
    "Dapper QueryAsync" = "\.QueryAsync\s*\("
    "Dapper QueryFirst" = "\.QueryFirst"
    "Dapper QuerySingle" = "\.QuerySingle"
    "SQL EXEC" = "\bEXEC(?:UTE)?\b"
    "Create Procedure" = "CREATE\s+(?:OR\s+ALTER\s+)?PROCEDURE"
    "Create View" = "CREATE\s+(?:OR\s+ALTER\s+)?VIEW"
    "Create Function" = "CREATE\s+(?:OR\s+ALTER\s+)?FUNCTION"
    "Create Trigger" = "CREATE\s+(?:OR\s+ALTER\s+)?TRIGGER"
}

$includeExtensions = @(
    ".cs", ".sql", ".csproj", ".sqlproj", ".json", ".config", ".xml",
    ".ps1", ".psm1", ".yml", ".yaml", ".md"
)


$files = Get-ChildItem -LiteralPath $resolvedPath -Recurse -File -Force |
    Where-Object {
        $includeExtensions -contains $_.Extension.ToLowerInvariant() -and
        $_.FullName -notmatch "\\(bin|obj|\.git|\.vs|node_modules|packages)\\"
    }

$results = foreach ($file in $files) {
    $isSensitiveConfig = $file.Name -match "appsettings.*\.json|.*\.config"
    foreach ($entry in $patterns.GetEnumerator()) {
        $matches = Select-String -LiteralPath $file.FullName -Pattern $entry.Value -AllMatches -ErrorAction Stop
        foreach ($match in $matches) {
            [pscustomobject]@{
                Pattern = $entry.Key
                Path = $file.FullName
                LineNumber = $match.LineNumber
            }
        }
    }
}

if ($SummaryOnly) {
    $results |
        Group-Object Pattern |
        Sort-Object Name |
        Select-Object Name, Count
} else {
    if (@($results).Count -gt $MaxResults) {
        Write-Warning "Results limited to $MaxResults of $(@($results).Count) matches; narrow Path or use SummaryOnly."
    }
    $results |
        Sort-Object Path, LineNumber, Pattern |
        Select-Object -First $MaxResults
}

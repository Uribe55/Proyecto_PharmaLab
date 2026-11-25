param([string]$OutputPath)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\')
$files = [System.Collections.Generic.List[object]]::new()
$directories = [System.Collections.Generic.List[string]]::new()
$pending = [System.Collections.Generic.Stack[string]]::new()
$pending.Push($projectRoot)
while ($pending.Count -gt 0) {
    foreach ($entry in Get-ChildItem -LiteralPath $pending.Pop() -Force) {
        $relative = $entry.FullName.Substring($projectRoot.Length + 1).Replace('\', '/')
        if ($entry.PSIsContainer) {
            $directories.Add($relative)
            if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
                $pending.Push($entry.FullName)
            }
        } else {
            $files.Add([pscustomobject]@{ Path = $relative; Bytes = $entry.Length })
        }
    }
}
$top = foreach ($group in ($files | Group-Object { ($_.Path -split '/')[0] })) {
    $prefix = $group.Name
    [pscustomobject]@{ Path = $prefix; Files = $group.Count
        Directories = @($directories | Where-Object { $_ -eq $prefix -or $_.StartsWith($prefix + '/') }).Count
        Bytes = ($group.Group | Measure-Object Bytes -Sum).Sum }
}
$result = [pscustomobject]@{ Root = $projectRoot; AtUtc = [DateTime]::UtcNow.ToString('o')
    Files = $files.Count; Directories = $directories.Count
    Bytes = ($files | Measure-Object Bytes -Sum).Sum
    Top = @($top | Sort-Object Bytes -Descending) }
if ($OutputPath) {
    $target = [IO.Path]::GetFullPath((Join-Path $projectRoot $OutputPath))
    if (!$target.StartsWith($projectRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Destino fuera del proyecto.' }
    $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $target -Encoding UTF8
}
$result | Select-Object Files, Directories, Bytes
$result.Top | Format-Table -AutoSize


Function ReadEnvFile {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    Get-Content $Path | foreach {
        if ($_ -match '^(.*?)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim().Replace("`"","")
            [System.Environment]::SetEnvironmentVariable($key, $value)
            echo "env $key=$value"
        }
    }
} 

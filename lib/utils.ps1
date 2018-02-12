function checkGitPath {
  if ($env:GITPATH -eq $null) {
    $env:GITPATH = "git";
  }
}

function readJSON {
  [CmdletBinding()]
  param(
    [parameter(mandatory = $true)]
    [string] $path
  )

  process {
    get-content $path | convertfrom-json;
  }
}
<##
 # pwr, a script manager for Powershell
 # 
 # Author: Faraz Syed <hello@farazsyed.com>
 # License: MIT
 # Copyright 2018
 #>

#  param(
#   [parameter(position=0)] $command="help"
# )

. "$PSScriptRoot\..\lib\utils.ps1"

$pwrVersion = (readJSON "$pwrRoot\manifest.json").version;
$pwrPackagesFolder = "packages";
$pwrPackagesPath = "$($pwrRoot)\$($pwrPackagesFolder)";

$pwrUsage = "
Usage:`
  pwr add <url>
  pwr list
  pwr remove <name>
  pwr update <name>

pwr@$($pwrVersion) $($pwrRoot)
";

function add {
  [CmdletBinding()]
  param(
    [parameter(mandatory = $true)]
    [string] $url,

    [switch] $silent = $false
  )

  process {
    $urlProtocol, $name = $url -split "://";
    $pkgPath = "$($pwrPackagesPath)\$($name)";
  
    # throw if already added
    if (test-path "$($pkgPath)\manifest.json") {
      $pkgVersion = (readJSON "$($pkgPath)\manifest.json").version;
      throw "$($name)@$($pkgVersion) already added @ $($pkgPath)";
      exit 1;
    }

    if (!($silent)) {
      echo "pwr adding $($name)`n  url: $($url)`n  path: $($pkgPath)";
    }
  
    # git clone to $pkgPath
    # allow user to specify gitpath with $env:GITPATH
    checkGitPath;
    & $env:GITPATH clone --depth=1 --quiet $url $pkgPath;
    pushd $pkgPath;
    rm ".git" -recurse -force;
    popd;

    if (!($?)) {
      # git clone failed
      throw "could not find repository @ $($url)";
    }
  
    # any error must clean up cloned files now
    try {
      # get package manifest data
      $pkgManifest = readJSON "$($pkgPath)\manifest.json";
      
      # create bin scripts if needed
      if (!($pkgManifest.bin -eq $null)) {
        foreach ($bin in $pkgManifest.bin.psObject.properties) {
          $binPath = "$($pwrRoot)\$($bin.name).ps1";
          # check for bin file name conflicts
          if (test-path $binPath) {
            write-error "Could not create bin file @ $($binPath), file already exists. Skipping this bin file";
          }
          else {
            "`$pwrRoot = `$PSScriptRoot;
& `"`$pwrRoot\$($pwrPackagesFolder)\$($name)\$($bin.value)`" @args;" > $binPath;
          }
        }
      }

      if (!($silent)) {
        echo "
pwr added $($name)@$($pkgManifest.version)

available commands:

  pwr remove $($name)
  pwr update $($name)
";
      }
    }
    catch {
      # clean up cloned repo
      rm $pkgPath -recurse -force;
      write-error $PSItem.ToString();
      exit 1;
    }
  }
}

function list {
  echo "pwr list`n";
  pushd $pwrPackagesPath;
  $dirs = ls manifest.json -recurse | resolve-path -relative | split-path;
  $dirs | foreach-object {
    $_ -match "\.\\(?<path>.*)" > $null;
    $name = $matches["path"] -replace "\\","/";
    $version = (readJSON("$_\manifest.json")).version;
    echo "$($name)@$($version)";
  }
  popd;
  echo "";
}

function remove {
  [CmdletBinding()]
  param(
    [parameter(mandatory = $true)]
    [string] $name,

    [switch] $silent = $false
  )

  process {
    $pkgPath = "$($pwrPackagesPath)\$($name)";

    # throw if not added
    if (!(test-path $pkgPath)) {
      throw "$($name) not already added @ $($pkgPath)";
      exit 1;
    }

    if (!($silent)) {
      echo "pwr removing $($name)`n  path: $($pkgPath)";
    }

    try {
      # get package manifest data
      $pkgManifest = readJSON "$($pkgPath)\manifest.json";
      
      # delete bin scripts
      if (!($pkgManifest.bin -eq $null)) {
        foreach ($bin in $pkgManifest.bin.psObject.properties) {
          rm "$($pwrRoot)\$($bin.name).ps1";
        }
      }

      # delete package
      rm $pkgPath -recurse -force;

      if (!($silent)) {
        echo "`npwr removed $($name)@$($pkgManifest.version)";
      }
    }
    catch {
      write-error $PSItem.ToString();
      exit 1;
    }

  }
}

function update {
  [CmdletBinding()]
  param(
    [parameter(mandatory = $true)]
    [string] $name
  )

  process {
    $pkgPath = "$($pwrPackagesPath)\$($name)";

    # throw if not added
    if (!(test-path $pkgPath)) {
      throw "$($name) not already added @ $($pkgPath)";
      exit 1;
    }
 
    echo "pwr updating $($name)`n  path: $($pkgPath)";

    try {
      # get package manifest data
      $pkgManifest = readJSON "$($pkgPath)\manifest.json";
      remove -name $name -silent;
      add -url $pkgManifest.git -silent;

      echo "`npwr updated $($name)@$($pkgManifest.version)";
    }
    catch {
      write-error $PSItem.ToString();
      exit 1;
    }
  }
}

$command = $args[0];

switch ($command) {
  "add" { add -url $args[1]; }
  default { echo $pwrUsage; }
  "list" { list; }
  "remove" { remove -name $args[1]; }
  "update" { update -name $args[1]; }
}
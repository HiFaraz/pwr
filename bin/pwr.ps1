<##
 # pwr, a script manager for Powershell
 # 
 # Author: Faraz Syed <hello@farazsyed.com>
 # License: MIT
 # Copyright 2018
 #>

. "$PSScriptRoot\..\lib\utils.ps1"

if (!($pwrName)) {
  $pwrName = "pwr";
}
$pwrVersion = (readJSON "$psScriptRoot\..\manifest.json").version;
$pwrPackagesFolder = "packages";
$pwrPackagesPath = "$($pwrRoot)\$($pwrPackagesFolder)";

$pwrHelp = @{};
$pwrHelp.default = "
Usage: $($pwrName) <command> [<args>]

Commands:

add`tAdd a package
help`tShow help for a command or pwr itself
list`tList added packages
remove`tRemove a package
update`tUpdate a package

Run '$($pwrName) help <command>' to get help for a specific command.
Visit http://pwrpkg.com to learn more about pwr.

$($pwrName) ($($pwrVersion)) $($pwrRoot)
";


<##
 # Add a package
 #>
$pwrHelp.add = "
Add a package

Usage: $($pwrName) add <repo url>
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
      echo "Adding '$($name)'.";
    }
  
    # git clone to $pkgPath
    # allow user to specify gitpath with $env:GITPATH
    checkGitPath;
    & $env:GITPATH clone --depth=1 --quiet $url $pkgPath;

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
          if (!($bin.name -eq "pwr" -and $name.toLower() -eq "github.com/hifaraz/pwr") -and (test-path $binPath)) {
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
'$($name)' ($($pkgManifest.version)) was added.

Available commands:

  $($pwrName) remove $($name)
  $($pwrName) update $($name)
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
<##
 # Print help information
 #>
function help {
  param([string] $command);

  if ($command -eq $null -or $command -eq "") {
    echo $pwrHelp.default;
  } else {
    $helpMsg = $pwrHelp[$command];
    if ($helpMsg) {
      echo $helpMsg;
    } else {
      echo "No help available for command $($command)."
    }
  }
}

<##
 # List added packages
 #>
$pwrHelp.list = "
List added packages
Usage: $($pwrName) list
";
function list {
  echo "Added packages:`n";
  pushd $pwrPackagesPath;
  $manifests = ls manifest.json -recurse | resolve-path -relative | split-path;
  
  if ($manifests.length -eq 0) {
    echo "No packages added";
  }

  $manifests | foreach-object {
    $_ -match "\.\\(?<path>.*)" > $null;
    $name = $matches["path"] -replace "\\","/";
    $version = (readJSON("$_\manifest.json")).version;
    echo "$($name)@$($version)";
  }
  popd;
  echo "";
}

<##
 # Remove a package
 #>
$pwrHelp.remove = "
Remove a package

Usage: $($pwrName) remove <name>
";
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
      echo "Removing '$($name)'";
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
        echo "`'$($name)' ($($pkgManifest.version)) was removed.";
      }
    }
    catch {
      write-error $PSItem.ToString();
      exit 1;
    }

  }
}

<##
 # Update a package
 #>
$pwrHelp.update = "
Update a package

Usage: $($pwrName) update <name>
";
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
 
    echo "Updating '$($name)'.";

    try {
      # get package manifest data
      $pkgManifest = readJSON "$($pkgPath)\manifest.json";
      remove -name $name -silent;
      add -url $pkgManifest.git -silent;
      $updatedPkgManifest = readJSON "$($pkgPath)\manifest.json";
      
      echo "'$($name)' ($($updatedPkgManifest.version)) was updated.";
    }
    catch {
      write-error $PSItem.ToString();
      exit 1;
    }
  }
}

$command = $args[0];

switch ($command) {
  default { help; }
  "add" { add -url $args[1]; }
  "help" { help -command $args[1]; }
  "list" { list; }
  "remove" { remove -name $args[1]; }
  "update" { update -name $args[1]; }
}
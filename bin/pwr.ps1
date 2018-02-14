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
$pwrRepoURL = "github.com/hifaraz/pwr";
$pwrManifestPath = join-path $psScriptRoot .. "manifest.json" -resolve;
$pwrVersion = (readJSON $pwrManifestPath).version;
$pwrPackagesFolder = "packages";
$pwrPackagesPath = join-path $pwrRoot $pwrPackagesFolder;


$pwrHelp = @{};
$pwrHelp.default = "
Usage: $($pwrName) <command> [<args>]

Commands:

add`tAdd a package
help`tShow help for a command or pwr itself
list`tList added packages
remove`tRemove a package
update`tUpdate a package, or pwr itself

Run '$($pwrName) help <command>' to get help for a specific command.
Visit http://pwrpkg.com to learn more about pwr.

$($pwrName) ($($pwrVersion)) $($pwrRoot)
";


<##
 # Add a package
 #>
$pwrHelp.add = "
Add a package

Usage: $($pwrName) add <package url>
";
function add {
  [CmdletBinding()]
  param(
    [parameter(mandatory = $true)]
    [string] $url,

    [switch] $silent = $false
  )

  process {
    $urlProtocol, $name = $url.toLower() -split "://";
    $pkgPath = join-path $pwrPackagesPath $name;
    $pkgManifestPath = join-path $pkgPath "manifest.json";
  
    # throw if already added
    if (test-path $pkgManifestPath) {
      $pkgVersion = (readJSON $pkgManifestPath).version;
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
      $pkgManifest = readJSON $pkgManifestPath;
      
      # create bin scripts if needed
      if (!($pkgManifest.bin -eq $null)) {
        foreach ($bin in $pkgManifest.bin.psObject.properties) {
          $binPath = join-path $pwrRoot $bin.name;
          # check for bin file name conflicts
          if (!($bin.name -eq "pwr.ps1" -and $name.toLower() -eq "github.com/hifaraz/pwr") -and (test-path $binPath)) {
            write-error "Could not create bin file @ $($binPath), file already exists. Skipping this bin file";
          }
          else {
            $binTargetPath = join-path "$pwrRoot" $pwrPackagesFolder $name $bin.value;
            "`$pwrRoot = `$PSScriptRoot;
& `"$($binTargetPath)`" @args;" > $binPath;
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
      remove-item $pkgPath -recurse -force;
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
  if (test-path $pwrPackagesPath) {
    echo "Added packages:`n";
    pushd $pwrPackagesPath;
    $manifests = get-childitem "manifest.json" -recurse | resolve-path -relative | split-path;
    popd;
  } else {
    $manifests = @();
  }
  
  if ($manifests.length -eq 0) {
    echo "No packages added";
  } else {
    $manifests | foreach-object {
      if ([IO.Path]::DirectorySeparatorChar -eq "/") {
        $_ -match "\./(?<path>.*)" > $null;
      } else {
        $_ -match "\.\\(?<path>.*)" > $null;
      }
      $name = $matches["path"] -replace "\\","/";
      $pkgManifestPath = join-path $pwrPackagesPath $_ "manifest.json";
      $version = (readJSON $pkgManifestPath).version;
      echo "$($name)@$($version)";
    };
  }
  echo "";
}

<##
 # Remove a package
 #>
$pwrHelp.remove = "
Remove a package

Usage: $($pwrName) remove <package>
";
function remove {
  [CmdletBinding()]
  param(
    [parameter(mandatory = $true)]
    [string] $name,

    [switch] $silent = $false
  )

  process {
    $pkgPath = join-path $pwrPackagesPath $name;

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
      $pkgManifestPath = join-path $pkgPath "manifest.json";
      $pkgManifest = readJSON $pkgManifestPath;
      
      # delete bin scripts
      if (!($pkgManifest.bin -eq $null)) {
        foreach ($bin in $pkgManifest.bin.psObject.properties) {
          $binPath = join-path $pwrRoot $bin.name;
          rm $binPath;
        }
      }

      # delete package
      remove-item $pkgPath -recurse -force;

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

Usage: $($pwrName) update <package>

'$($pwrName) update' updates $($pwrName) to the latest version.
'$($pwrName) update <package>`' adds a new version of that package, if there is one.
";
function update {
  [CmdletBinding()]
  param(
    [string] $name
  )

  process {
    if ($name -eq "") {
      $name = $pwrRepoURL;
    }

    $pkgPath = join-path $pwrPackagesPath $name;

    # throw if not added
    if (!(test-path $pkgPath)) {
      throw "$($name) not already added @ $($pkgPath)";
      exit 1;
    }
 
    echo "Updating '$($name)'.";

    try {
      # get package manifest data
      $pkgManifestPath = join-path $pkgPath "manifest.json";
      $pkgManifest = readJSON $pkgManifestPath;
      remove -name $name -silent;
      add -url $pkgManifest.git -silent;
      $updatedPkgManifest = readJSON $pkgManifestPath;
      
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
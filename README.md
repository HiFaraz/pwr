# pwr
A decentralized package manager

pwr (pronounced "power") is a cross-platform package manager (due to PowerShell Core). It does not have a central registry. You can instead add packages directly from any online git repository url (such as a repo on Github.com).

Any git repo is a valid pwr package as long as it has a `manifest.json`. This repository is itself a valid pwr package.

pwr can run binaries and PowerShell scripts directly. You can run bash or cmd scripts by calling the appropriate binary.

pwr is inspired by npm, Yarn, and Scoop.

## Dependencies

- git (either available on $PATH or provided with $GITPATH)
- PowerShell

## Installing

pwr is portable. Install it and move it anywhere.

```
git clone https://github.com/HiFaraz/pwr
```

Add the project directory to your `$PATH`.

Finally, bootstrap pwr with:

```
pwr
```

(this allows you to update pwr like any other package)

## Usage

```
Usage: pwr <command> [<args>]

Commands:

add     Add a package
help    Show help for a command or pwr itself
list    List added packages
remove  Remove a package
update  Update a package

Run 'pwr help <command>' to get help for a specific command.
```
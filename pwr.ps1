echo "
Hi! Thanks for installing pwr!.
I'm just going to do a quick self-install to get you started...
";

$pwrRoot = $PSScriptRoot;
& "$pwrRoot\bin\pwr.ps1" add "http://github.com/hifaraz/pwr";

echo "Self-install complete. You're all set to be a pwr user!
";
# mac*OSS*etup

# Usage
Current version does in orded:
- Configures sudo access with Touch ID
- Installs: 
  - Command Line Tools for Xcode
  - Oh My ZSH
  - Homebrew


```shell
bash <(curl -fsSL https://raw.githubusercontent.com/Bobronium/macOSSetup/HEAD/setup.sh) -v
```

# Wanted features set
## Install/update
- Anything from Homebrew
- Apps from App Store
- Apps from iOS/iPadOS App Store
- Apps from any source (web, ?) (.zip, .dmg) (drag-n-drop, installers)

## A lot more TBD

# Cheatsheat
### Install and app form .dmg
```bash
# usage: installdmg https://example.com/path/to/pkg.dmg
function installdmg {
    set -x
    tempd=$(mktemp -d)
    curl $1 > $tempd/pkg.dmg
    listing=$(sudo hdiutil attach $tempd/pkg.dmg | grep Volumes)
    volume=$(echo "$listing" | cut -f 3)
    if [ -e "$volume"/*.app ]; then
      sudo cp -rf "$volume"/*.app /Applications
    elif [ -e "$volume"/*.pkg ]; then
      package=$(ls -1 "$volume" | grep .pkg | head -1)
      sudo installer -pkg "$volume"/"$package" -target /
    fi
    sudo hdiutil detach "$(echo "$listing" | cut -f 1)"
    rm -rf $tempd
    set +x
}
```
*Caveats*:
- If .dmg contains an .app installer, it'll still only copy it to /Applications instead of installing it
- Some packages are distributed in .pkg without .dmg
- Some packages are distributed in .zip containing the .app/.pkg

Solution to all these caveats would be a config, where apps with their sources could be leasted and described, e.g.:
```yaml
apps:
  web:
    # will download .dmg, search for .pkg/.app, and upon finding single .app, will copy it to /Applications
    - url: https://download.jetbrains.com/python/pycharm-professional-2021.3.1-aarch64.dmg
    # will download SomeOtherApp.dmg, look for single file with .app extension, and will launch it
    - url: https://example.com/SomeOtherApp.dmg
      extension: .app
      type: installer
      action: launch
    # will download DifferentApp.dmg, mount it and install DifferentApp*.pkg, if matched
    - url: https://example.com/DifferentApp.dmg
      target: DifferentApp*.pkg
      action: install 
```
### Keep iTerm2 settings in git
- https://github.com/fnichol/macosx-iterm2-settings

### Install apps from App Store
This script uses apple script language instead of CLI tools to install apps, this might allow to install iOS/iPadOS apps as well
- https://gist.github.com/benbalter/3db34485f49006c60129

### Configuring shortcuts
- [DefaultKeyBinding.dict](http://web.archive.org/web/20160314030051/http://osxnotes.net/keybindings.html)
- [Setting Keyboard Shortcuts from Terminal in macOS](https://www.ryanmo.co/2017/01/05/setting-keyboard-shortcuts-from-terminal-in-macos/)
- [Where are keyboard shortcuts stored (for backup and sync purposes)?](https://apple.stackexchange.com/questions/87619/where-are-keyboard-shortcuts-stored-for-backup-and-sync-purposes)
- [Default Mac OS X System Key Bindings](https://www.hcs.harvard.edu/~jrus/site/system-bindings.html)
- [Creating keyboard shortcuts on the command line](http://hints.macworld.com/article.php?story=20131123074223584)
- [NSStandardKeyBindingResponding](https://developer.apple.com/documentation/appkit/nsstandardkeybindingresponding)
- [Cocoa Event Handling Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/TextDefaultsBindings/TextDefaultsBindings.html)

"""
Legend

<resource>
    One of resources:
        brew
        pipx
        pyenv
        mas
        npm
<item>
    item to install from resources


Commands

add <item> [--installed|<item>][--sync]
        
remove <item> [--sync]

<resource> add <item> [--sync]
    add item to config

<resource> add <item> [--sync]
    add item to config
    
setup [<resource>|configs|defaults]
    simply setup whatever is defined in config. 

sync [<resource>|configs|defaults][--override {config|system|ask}][--remove]
    more complex and more powerfull than setup, allow both way syncing (config > system, system state > config)

Entities — come up with a better name

defaults
    apply
        apply defaults from config
    track <cmd>
        add changes in defaults caused by shell command
    snapshot
        save current state of defaults
    restore <snapshot>
        restore defaults to saved state
    diff [snapshot]
        show diff between saved and current state
    show
        show defaults that are not default (works only with user-scope defaults)
        HACK this could work by creating a temp user with sysadminctl,
        getting snapshot of defaults of that user and comparing it to current
    capture
        same as `show`, but write it to config

    NOTE: examine existing tools:
        https://github.com/clintmod/macprefs
        https://github.com/Tatsh/macprefs


configs
    manage custom file configs for tools like poetry, etc.
    NOTE: should see https://github.com/lra/mackup/ for configs

default apps

web <url> <type>
    should accept url to .zip/.dmg/.pkg/.app to install from

MVP

"""


# from pathlib import Path
import click


@click.command()
@click.option("--config", type=click.Path())
def main(config):
    print("Hello world")


if __name__ == "__main__":
    main()

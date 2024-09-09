from __future__ import annotations
from os import PathLike

from pathlib import Path
from time import sleep
from typing import IO, overload, Literal, Any

from macprefs.mp_typing import PlistRoot

from macossetup.processes import Process


def prompt_for_permissions(file: str):
    path_to_app = Process.get_current().root.app
    repr_path = (
        path_to_app.name
        if len(path_to_app.parts) > 1 and path_to_app.parts[1:] == ("/", "Applications")
        else path_to_app
    )

    answer = input(
        f"Can't open {file}.\n"
        + f"Looks like {repr_path} doesn't have enough permissions.\n"
        + "Open System Preferences to Grant Full Disk Access to {path_to_app.stem}? Y/n"
    )

    if answer and answer.lower() != "y":
        return False

    sleep(0.1)
    print(
        f"Alright. DON'T Quit & Reopen. If {repr_path} is not in the list, add it with +.",
        flush=True,
    )
    sleep(0.5)
    import webbrowser

    webbrowser.open('x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles')
    input("Press enter when you finish...")
    return True


_PathType = str | bytes | int | Path


@overload
def safe_open(
    path: _PathType,
    mode: Literal["r", "w", "a", "x", "r+", "w+", "a+", "x+"] = "r",
    *args: Any,
    **kwargs: Any,
) -> IO[str]:
    ...


@overload
def safe_open(
    path: _PathType,
    mode: Literal["rb", "wb", "ab", "xb", "r+b", "w+b", "a+b", "x+b"] = "r",
    *args: Any,
    **kwargs: Any,
) -> IO[bytes]:
    ...


@overload
def safe_open(path: _PathType, mode: str = "r", *args: Any, **kwargs: Any) -> IO[str]:
    ...


def safe_open(file: _PathType, mode: str = "r", *args, **kwargs) -> IO[str]:
    try:
        return open(file, mode, *args, **kwargs)
    except PermissionError as e:
        if e.errno != 1:
            raise
        if prompt_for_permissions(file):
            return safe_open(file, mode, *args, **kwargs)
        raise

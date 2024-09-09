import os
import subprocess
from functools import cached_property, cache
from pathlib import Path
from typing import NamedTuple


class Process(NamedTuple):
    pid: int
    ppid: int
    exec: Path
    parent: "Process"

    @classmethod
    def list(cls) -> list["Process"]:
        return _get_running_processes()

    @classmethod
    def get_current(cls) -> "Process":
        return _get_current_process()

    @cached_property
    def app(self) -> Path:
        """
        App that contains process.exec.

        Either returns path to .app or path to exec itself.
        """
        path_to_app = Path()
        for part in self.exec.parts:
            path_to_app = path_to_app / part
            if part.endswith('.app'):
                return path_to_app
        return self.exec

    @cached_property
    def root(self):
        process = self
        parent_process = process.parent

        while parent_process.pid != 1:
            process = parent_process
            parent_process = parent_process.parent

        return process


def find_root_process() -> Process:
    """
    Finds the highest process that started the interpreter (one after launchd).

    Usually it's IDE or Terminal emulator.
    """
    process = _get_running_processes()[os.getpid()]
    parent_process = process.parent

    while parent_process.pid != 1:
        process = parent_process
        parent_process = parent_process.parent

    return process


def _get_running_processes() -> dict[int, Process]:
    ps_output = subprocess.check_output(['ps', 'axo', 'pid,ppid,comm'])
    processes = {}
    for process_info in ps_output.decode().strip().splitlines()[1:]:
        pid, ppid, executable = process_info.split(maxsplit=2)
        processes[int(pid)] = Process(
            int(pid), int(ppid), Path(executable), processes.get(int(ppid))
        )
    return processes


@cache
def _get_current_process() -> Process:
    return _get_running_processes()[os.getpid()]

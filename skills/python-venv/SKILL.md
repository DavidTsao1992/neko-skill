---
name: python-venv
description: Use before writing or running Python in a project (a .py file, a python or pip command, or a repo with requirements.txt, pyproject.toml, Pipfile, setup.py or .python-version) — reuses or creates a pyenv-backed .venv so packages never go into the system interpreter.
---

# Python Virtual Environment

1. Reuse an existing `.venv`, `venv`, or `env` in the project root, in that order; if one exists,
   skip to step 3.
2. Otherwise build one on pyenv, never the system interpreter:
   - Confirm `pyenv --version` works. If it doesn't, stop and tell the user — don't silently fall
     back to system Python.
   - With no `.python-version`, choose a version from `pyenv versions` (or `pyenv install` it) and
     pin it with `pyenv local <version>`.
   - `pyenv exec python -m venv .venv`.
3. Invoke the environment's own binaries for every install and run — `.venv/bin/python`,
   `.venv/bin/pip` (`Scripts\` on Windows). Don't rely on `source .venv/bin/activate`: each shell
   command may start a fresh shell.
4. The first time, install dependencies the way the project declares them
   (`pip install -r requirements.txt` or `pip install -e .`) with that `pip`.
5. Make sure the environment directory is git-ignored; add it to `.gitignore`, creating the file
   if needed.
6. Never install packages globally or with a system `pip3`/`python3` unless the user explicitly
   asks.

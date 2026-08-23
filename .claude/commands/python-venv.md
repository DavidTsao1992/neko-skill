Make sure any Python code in this project runs inside an isolated virtual environment, not the system interpreter.

## When this applies

Before writing or running any Python code in the current project — a new `.py` file, a `python`/`pip` command, or a project that has `requirements.txt`, `pyproject.toml`, `Pipfile`, `setup.py`, or `.python-version`.

## Steps

1. Check the project root for an existing virtual environment, in this order: `.venv`, `venv`, `env`. If one is found, use it — skip to step 3.

2. If none exists, create one on top of pyenv, not the system interpreter:
   - Confirm `pyenv` is available (`pyenv --version`). If it isn't, stop and tell the user — this toolkit assumes Python projects are managed with pyenv, so don't silently fall back to system Python.
   - If the project has no `.python-version`, pick a version with `pyenv versions` (or `pyenv install <version>` if the one you need isn't installed yet) and pin it with `pyenv local <version>`.
   - Build the venv from that pinned interpreter: `pyenv exec python -m venv .venv`.

3. Always invoke the venv's own binaries directly — `.venv/bin/python`, `.venv/bin/pip` (or the `Scripts/` equivalents on Windows) — for every install and every run. Don't rely on `source .venv/bin/activate`: each Bash call starts a fresh shell, so an activation from one command doesn't carry over to the next.

4. Install project dependencies into that venv the first time it's created — `pip install -r requirements.txt` or `pip install -e .`, whichever the project uses — via the venv's `pip`, not a system one.

5. If `.gitignore` exists and doesn't already ignore the venv directory, add an entry for it. If a venv was just created and there's no `.gitignore` yet, create one with that entry.

6. Never install Python packages globally or with a system `pip3`/`python3` unless the user explicitly asks for that.

---
name: python-venv
description: Prepare or reuse an isolated pyenv-backed Python virtual environment and keep package installs out of the system interpreter.
---

# Python Virtual Environment

1. Reuse an existing `.venv`, `venv`, or `env`, in that order.
2. Otherwise require `pyenv`; do not silently use system Python. Pin an appropriate version when needed, then run `pyenv exec python -m venv .venv`.
3. Invoke the environment's binaries directly. Do not rely on activation persisting between commands.
4. Install dependencies through the environment using the project's declared mechanism.
5. Ensure the environment directory is ignored by git.
6. Never install packages globally unless the user explicitly asks.

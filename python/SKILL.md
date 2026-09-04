---
name: python
description: "Python conventions and rules: typing, ruff/mypy, minimal dependencies, boundary validation. Use when writing, editing, or reviewing Python code (.py), libraries, or scripts."
license: MIT
---

## Rules

- Functional where practical, typed where it matters.
- No unnecessary dependencies. Check if stdlib covers it first.
- Lint with `ruff`, format with `ruff format`, type-check with `mypy`.
- Validation only at system boundaries (user input, external APIs). Trust internal code.

## What I do

- Write Python code following PEP 8 and modern best practices
- Use type hints for better code clarity
- Structure projects with poetry for dependency management
- Ensure code passes ruff linting and mypy type checking
- Follow Python conventions for docstrings and naming

## When to use me

Use this skill when developing Python applications, libraries, or scripts.

## Tooling

- **ruff**: Fast linter and formatter (replaces flake8, isort, black)
- **mypy**: Static type checker
- **poetry**: Dependency management and packaging

## Code style

- Line length: 100 characters
- Use f-strings for string formatting
- Prefer pathlib over os.path
- Use type hints for function signatures
- Write docstrings for public functions/classes
- Use context managers for resource handling

## Project structure

```
project/
├── pyproject.toml
├── src/
│   └── package_name/
│       ├── __init__.py
│       └── module.py
└── tests/
    └── test_module.py
```

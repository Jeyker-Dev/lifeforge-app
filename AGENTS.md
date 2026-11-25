# AGENTS.md — LifeForge (Flutter app)

Product, architecture and decisions live in `docs/` (start with `docs/README.md`).
The API lives in the sibling repository `../lifeforge-api`.

## Task workflow

Tasks live in FunWork (project LifeForge, id 3), not in this repo.
Set the task to `Doing` before starting work and to `Done` with the
commit when finished. Phase specifications live in `odd/tasks/*.md`;
read the referenced task's spec up to `## Log` before changing code.

## Checks

Run before every commit:

    dart format --output=none --set-exit-if-changed lib test
    flutter analyze
    flutter test

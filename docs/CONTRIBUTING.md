Contributing Guidelines

Purpose

Help contributors read, edit, and extend the project safely and consistently.

Getting started

1. Install Python (backend) and Flutter (frontend) per repo README.
2. Create a virtualenv for backend: `python -m venv .venv` and activate it.
3. Install backend deps: `pip install -r backend/requirements.txt`.
4. Install Flutter SDK and run `flutter pub get` inside `frontend`.

Code style

- Follow Dart/Flutter style using `dart format`.
- Keep widgets small and presentational; state belongs in providers.

Feature layout

- Use `lib/features/<feature>` to group screens, providers, and widgets for that feature.
- Common widgets go in `lib/widgets`.
- Services (API, storage, location) belong in `lib/services`.

Pull request workflow

- Create a branch per feature/refactor.
- Keep PRs small and focused; prefer incremental changes.
- Run `flutter analyze` and include a screenshot or short video for visual changes.
- Write tests for logic-heavy changes and add integration steps to PR description.

Testing

- Backend: `pytest` (if included) and `python -m pytest`.
- Frontend: `flutter test` for unit/widget tests.

Safety rules for refactors

- Never delete or replace a legacy file until a tested replacement is wired alongside it.
- Add an entry to `docs/FRONTEND_REFACTOR_PLAN.md` before starting large cross-cutting changes.

Contact

- Add notes in PR description if the change affects runtime behavior (live location, map rendering, data parsing).


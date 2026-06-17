# Contributing to Talk2Text

Thanks for your interest! This repo is a monorepo with two apps:

- **Desktop** (Python, repo root) — see [`README.md`](README.md).
- **Mobile** (Flutter, [`mobile/`](mobile/)) — see [`mobile/README.md`](mobile/README.md).

## Getting set up

**Desktop**
```bash
pip install -r requirements.txt
python talk2text.py
```

**Mobile**
```bash
cd mobile
flutter pub get
flutter run        # with a device/emulator attached
```

## Before you open a PR

Run the same checks CI runs:

**Mobile**
```bash
cd mobile
flutter analyze
flutter test
```
Please keep `flutter analyze` clean and add/adjust tests for behavior changes.

**Desktop**
- Keep it runnable (`python talk2text.py`) and avoid adding heavy dependencies
  without discussion.

## Pull request flow

1. Fork and branch off the default branch (short, descriptive branch names).
2. Make focused commits with clear messages.
3. Open a PR using the template; link any issue it addresses (`Closes #123`).
4. CI (**Mobile** / **Build**) must pass and a maintainer review is required.

## Developer Certificate of Origin (DCO)

We use the lightweight [DCO](https://developercertificate.org/) — no CLA. Sign
off each commit to certify you wrote the code (or have the right to submit it):

```bash
git commit -s -m "your message"   # adds: Signed-off-by: Your Name <email>
```

## Issues & labels

We track work with status labels (`status: open` → `in progress` → `review` →
`done`) plus `type:` / `area:` / `priority:` labels (defined in
[`.github/labels.yml`](.github/labels.yml)). Use the issue forms under
**New issue**. Good first contributions are tagged `good first issue`.

## Security

Please report vulnerabilities privately — see [`SECURITY.md`](SECURITY.md).

By contributing, you agree your contributions are licensed under the project's
[MIT License](LICENSE).

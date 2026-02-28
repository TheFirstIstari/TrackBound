# TrackBound

TrackBound is a Flutter app for railway enthusiasts to log, visualise and share train journeys.

This repository contains planning notes and initial repo files. Use the commands below to initialise a Flutter project, create the git repository and push to GitHub.

Quick start

1. Create a Flutter app skeleton inside this folder (optional if you will create in a subfolder):

```bash
flutter create .
```

2. Initialize git, commit initial files, and push to GitHub (replace `REPO_NAME` and `your-remote-url` as needed):

```bash
git init
git add .
git commit -m "chore: initial TrackBound repo files"
# Using GitHub CLI (preferred):
gh repo create REPO_NAME --public --source=. --remote=origin --push
# Or create the remote manually and push:
# git remote add origin git@github.com:YOUR_USERNAME/REPO_NAME.git
# git push -u origin main
```

If you want me to create a default Flutter project structure and commit it here, tell me which package name and organization you prefer (e.g., `com.example.trackbound`).

Files added:

- [TrackBound/README.md](TrackBound/README.md)
- [TrackBound/.gitignore](TrackBound/.gitignore)
- [TrackBound/LICENSE](TrackBound/LICENSE)

Next steps I can take now:

- Draft the SQLite data model and schema (in progress).
- Create an initial Flutter module scaffold and basic Riverpod architecture.

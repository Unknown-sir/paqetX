# Publish to Unknown-sir/paqetX

## GitHub CLI

```bash
cd paqetX
git init
git branch -M main
git add .
git commit -m "Release Paqet X Enhanced Manager 5.2.0"
gh auth login
gh repo create Unknown-sir/paqetX \
  --public \
  --source=. \
  --remote=origin \
  --push \
  --description "Reference-based Paqet X manager with selected and all-port forwarding for Iran/Kharej servers."
```

## Existing repository

```bash
cd paqetX
git init
git branch -M main
git add .
git commit -m "Release Paqet X Enhanced Manager 5.2.0"
git remote add origin https://github.com/Unknown-sir/paqetX.git
git push -u origin main
```

## One-command installer after publishing

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/install.sh)
```

## Recommended repository settings

- Enable GitHub Actions.
- Protect the `main` branch after the first successful workflow run.
- Require the test workflow before merging.
- Publish the ZIP and `SHA256SUMS` as release assets.
- Review `NOTICE.md` before making the repository public, because the bundled core is an opaque third-party binary.

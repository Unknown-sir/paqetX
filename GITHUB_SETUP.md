# GitHub publishing guide / راهنمای انتشار در GitHub

Target repository / ریپوی مقصد:

```text
https://github.com/Unknown-sir/paqetX
```

Suggested description:

```text
One-command Paqet installer for Abroad and Iran servers with verified releases, systemd, and TCP/UDP port forwarding.
```

Suggested topics:

```text
paqet iran tunnel port-forwarding kcp bash installer systemd iptables proxy networking
```

## GitHub CLI

From the project directory:

```bash
git init
git branch -M main
git add .
git commit -m "Release Paqet X 3.0.0 dual-role installer"
gh auth login
gh repo create Unknown-sir/paqetX \
  --public \
  --source=. \
  --remote=origin \
  --push \
  --description "One-command Paqet installer for Abroad and Iran servers with verified releases, systemd, and TCP/UDP port forwarding."
```

## GitHub website and Git

1. Create an empty public repository named `paqetX` under `Unknown-sir`.
2. Do not initialize it with another README, license, or `.gitignore`.
3. Run:

```bash
git init
git branch -M main
git add .
git commit -m "Release Paqet X 3.0.0 dual-role installer"
git remote add origin https://github.com/Unknown-sir/paqetX.git
git push -u origin main
```

After the first push, run the installer on both servers with:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash
```

The wizard offers Abroad installation, Iran installation, complete uninstall, and exit.

---

## راهنمای فارسی

در پوشه پروژه، با GitHub CLI اجرا کنید:

```bash
git init
git branch -M main
git add .
git commit -m "Release Paqet X 3.0.0 dual-role installer"
gh auth login
gh repo create Unknown-sir/paqetX \
  --public \
  --source=. \
  --remote=origin \
  --push \
  --description "One-command Paqet installer for Abroad and Iran servers with verified releases, systemd, and TCP/UDP port forwarding."
```

یا ابتدا یک ریپوی خالی و Public با نام `paqetX` در حساب `Unknown-sir` بسازید و سپس اجرا کنید:

```bash
git init
git branch -M main
git add .
git commit -m "Release Paqet X 3.0.0 dual-role installer"
git remote add origin https://github.com/Unknown-sir/paqetX.git
git push -u origin main
```

پس از Push، دستور نصب روی هر دو سرور خارج و ایران یکسان است:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash
```

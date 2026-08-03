# GitHub publishing guide / راهنمای انتشار در GitHub

Target repository / ریپوی مقصد:

```text
https://github.com/Unknown-sir/paqetX
```

Suggested description:

```text
Dual-role Paqet installer with selected-port or all-port forwarding, automatic SSH protection, verified releases, systemd, and complete uninstall.
```

Suggested topics:

```text
paqet iran tunnel port-forwarding tproxy socks5 kcp bash installer systemd iptables proxy networking
```

## GitHub CLI

From the project directory:

```bash
git init
git branch -M main
git add .
git commit -m "Release Paqet X 4.1.0 all-port forwarding fix"
gh auth login
gh repo create Unknown-sir/paqetX \
  --public \
  --source=. \
  --remote=origin \
  --push \
  --description "Dual-role Paqet installer with selected-port or all-port forwarding, automatic SSH protection, verified releases, systemd, and complete uninstall."
```

## GitHub website and Git

1. Create an empty public repository named `paqetX` under `Unknown-sir`.
2. Do not initialize it with another README, license, or `.gitignore`.
3. Run:

```bash
git init
git branch -M main
git add .
git commit -m "Release Paqet X 4.1.0 all-port forwarding fix"
git remote add origin https://github.com/Unknown-sir/paqetX.git
git push -u origin main
```

After the first push, run the same installer command on both servers:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash
```

The Iran wizard offers selected-port forwarding or all-port forwarding with automatic tunnel/SSH exclusions and optional user exclusions.

---

## راهنمای فارسی

در پوشه پروژه، با GitHub CLI اجرا کنید:

```bash
git init
git branch -M main
git add .
git commit -m "Release Paqet X 4.1.0 all-port forwarding fix"
gh auth login
gh repo create Unknown-sir/paqetX \
  --public \
  --source=. \
  --remote=origin \
  --push \
  --description "Dual-role Paqet installer with selected-port or all-port forwarding, automatic SSH protection, verified releases, systemd, and complete uninstall."
```

یا ابتدا یک ریپوی خالی و Public با نام `paqetX` در حساب `Unknown-sir` بسازید و سپس:

```bash
git init
git branch -M main
git add .
git commit -m "Release Paqet X 4.1.0 all-port forwarding fix"
git remote add origin https://github.com/Unknown-sir/paqetX.git
git push -u origin main
```

پس از Push، دستور نصب روی هر دو سرور یکسان است:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash
```

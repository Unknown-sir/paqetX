# GitHub publishing guide / راهنمای انتشار در GitHub

Target repository:

```text
https://github.com/Unknown-sir/paqetX
```

Suggested repository description:

```text
One-command, idempotent Linux server installer for Paqet with verified releases, systemd, and iptables setup.
```

Suggested topics:

```text
paqet linux bash installer systemd iptables kcp proxy networking
```

## Method 1: GitHub CLI

Install and authenticate GitHub CLI, then run from the project directory:

```bash
git init
git branch -M main
git add .
git commit -m "Initial release: Paqet X server installer"
gh auth login
gh repo create Unknown-sir/paqetX \
  --public \
  --source=. \
  --remote=origin \
  --push \
  --description "One-command, idempotent Linux server installer for Paqet with verified releases, systemd, and iptables setup."
```

## Method 2: Git and the GitHub website

1. Create an empty public repository named `paqetX` under `Unknown-sir`.
2. Do not initialize it with a README, license, or `.gitignore` because these files are already included.
3. Run:

```bash
git init
git branch -M main
git add .
git commit -m "Initial release: Paqet X server installer"
git remote add origin https://github.com/Unknown-sir/paqetX.git
git push -u origin main
```

After the first push, the public one-command installer will be:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash
```

---

## راهنمای فارسی

آدرس نهایی ریپو:

```text
https://github.com/Unknown-sir/paqetX
```

توضیح پیشنهادی برای ریپو:

```text
One-command, idempotent Linux server installer for Paqet with verified releases, systemd, and iptables setup.
```

تاپیک‌های پیشنهادی:

```text
paqet linux bash installer systemd iptables kcp proxy networking
```

### روش ساده با GitHub CLI

در پوشه پروژه اجرا کنید:

```bash
git init
git branch -M main
git add .
git commit -m "Initial release: Paqet X server installer"
gh auth login
gh repo create Unknown-sir/paqetX \
  --public \
  --source=. \
  --remote=origin \
  --push \
  --description "One-command, idempotent Linux server installer for Paqet with verified releases, systemd, and iptables setup."
```

### روش معمول با سایت GitHub و Git

ابتدا در حساب `Unknown-sir` یک ریپوی خالی و Public با نام `paqetX` بسازید. هنگام ساخت، README یا License جدید اضافه نکنید چون داخل پروژه وجود دارند. سپس در پوشه پروژه اجرا کنید:

```bash
git init
git branch -M main
git add .
git commit -m "Initial release: Paqet X server installer"
git remote add origin https://github.com/Unknown-sir/paqetX.git
git push -u origin main
```

# Paqet X Server Installer

[English](#english) · [فارسی](#فارسی)

A clean, one-command Linux server installer for the upstream open-source [`hanselime/paqet`](https://github.com/hanselime/paqet) project.

> **Important:** This repository is an independent installer maintained by [`Unknown-sir`](https://github.com/Unknown-sir). It is not the official Paqet repository and does not modify or redistribute the upstream source code.

---

## English

### What it does

`paqet-x-install.sh` automates a Paqet **server** installation on a systemd-based Linux server. It:

- detects the CPU architecture and network settings;
- installs missing system packages with a supported package manager;
- downloads the requested Paqet release directly from the upstream GitHub repository;
- verifies the release using GitHub's published SHA-256 digest;
- creates a secure server configuration and shared key;
- installs idempotent `iptables` rules required by Paqet;
- creates and starts hardened systemd services;
- preserves the existing configuration when safely rerun;
- prints clear progress and actionable errors.

### Requirements

- Linux with `systemd`
- root or `sudo` access
- outbound HTTPS access to GitHub
- one of these architectures:
  - AMD64 / x86_64
  - ARM64 / AArch64
  - ARMv7 / 32-bit ARM
- a non-standard TCP port open in the provider firewall/security group

### One-command installation

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash
```

Use a custom port:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash -s -- --port 10443
```

Install a specific upstream release:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash -s -- --version v1.0.0-alpha.20
```

For a review-before-running workflow:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh -o paqet-x-install.sh
less paqet-x-install.sh
sudo bash paqet-x-install.sh
```

### Options

| Option | Description |
|---|---|
| `--port PORT` | Server port from `1024` to `65535`; ports `80` and `443` are rejected |
| `--version TAG` | Upstream release tag or `latest` |
| `--interface NAME` | Override the detected network interface |
| `--local-ip IPV4` | Override the detected local IPv4 address |
| `--router-mac MAC` | Override the detected gateway/router MAC address |
| `--key KEY` | Set the shared key instead of generating one |
| `--force-config` | Back up and replace an existing configuration |
| `--no-start` | Install files without enabling or starting services |
| `--help` | Show command help |

Equivalent environment variables are supported: `PAQET_PORT`, `PAQET_VERSION`, `PAQET_INTERFACE`, `PAQET_LOCAL_IP`, `PAQET_ROUTER_MAC`, `PAQET_KEY`, `FORCE_CONFIG=1`, `SKIP_START=1`, `GITHUB_TOKEN`, and `NO_COLOR=1`.

### Installed files

| Path | Purpose |
|---|---|
| `/usr/local/bin/paqet` | Paqet executable |
| `/etc/paqet-x/server.yaml` | Server configuration and shared key |
| `/etc/paqet-x/firewall.env` | Firewall port configuration |
| `/usr/local/lib/paqet-x/firewall.sh` | Idempotent firewall helper |
| `/etc/systemd/system/paqet-x.service` | Paqet server service |
| `/etc/systemd/system/paqet-x-firewall.service` | Persistent firewall service |
| `/var/lib/paqet-x/version` | Installed upstream release tag |

### Service management

```bash
sudo systemctl status paqet-x --no-pager
sudo journalctl -u paqet-x -f
sudo systemctl restart paqet-x
sudo systemctl stop paqet-x
/usr/local/bin/paqet version
```

### Rerunning and upgrades

A normal rerun preserves the existing server configuration and recorded Paqet version:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash
```

Upgrade to the latest upstream release:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash -s -- --version latest
```

Paqet releases may include protocol-breaking changes. Keep the client and server on the same release version.

### Troubleshooting

Check the service and recent logs:

```bash
sudo systemctl status paqet-x paqet-x-firewall --no-pager
sudo journalctl -u paqet-x -n 100 --no-pager
sudo journalctl -u paqet-x-firewall -n 100 --no-pager
```

Confirm the server port is allowed by the cloud provider firewall/security group. The installer manages local `iptables` rules but cannot modify provider-level firewall settings.

When automatic network detection is not correct, provide explicit values:

```bash
sudo bash paqet-x-install.sh \
  --interface eth0 \
  --local-ip 192.0.2.10 \
  --router-mac aa:bb:cc:dd:ee:ff \
  --port 9999
```

### Security notes

- Run remote shell scripts only from a repository and commit you trust.
- The downloaded Paqet archive must match GitHub's published SHA-256 digest.
- The generated configuration is readable only by root.
- The shared key is printed once after a new configuration is created; store it securely.
- Use this software only on systems and networks you are authorized to administer.

### License and upstream credit

The installer in this repository is released under the [MIT License](LICENSE).

Paqet itself is developed by [`hanselime/paqet`](https://github.com/hanselime/paqet) and is distributed under its own MIT License. This installer downloads official upstream release assets at runtime.

---

## فارسی

### معرفی

`Paqet X` یک نصب‌کننده مستقل و یک‌دستوری برای راه‌اندازی **سرور** پروژه متن‌باز [`hanselime/paqet`](https://github.com/hanselime/paqet) روی لینوکس است.

> **توجه:** این ریپو توسط [`Unknown-sir`](https://github.com/Unknown-sir) نگهداری می‌شود و ریپوی رسمی Paqet نیست. اسکریپت، فایل اجرایی را مستقیماً از ریلیزهای رسمی پروژه اصلی دانلود می‌کند.

### امکانات

اسکریپت `paqet-x-install.sh` کارهای زیر را خودکار انجام می‌دهد:

- تشخیص معماری پردازنده و تنظیمات شبکه؛
- نصب وابستگی‌های لازم با پکیج‌منیجر سیستم؛
- دانلود نسخه درخواستی Paqet از ریپوی رسمی بالادستی؛
- بررسی صحت فایل دانلودی با SHA-256 منتشرشده توسط GitHub؛
- ساخت کانفیگ امن سرور و کلید اشتراکی؛
- اعمال قوانین لازم و تکرارپذیر `iptables`؛
- ساخت و اجرای سرویس‌های امن‌شده systemd؛
- نگهداری کانفیگ قبلی هنگام اجرای مجدد؛
- نمایش مرحله‌به‌مرحله عملیات و خطاهای قابل‌فهم.

### پیش‌نیازها

- لینوکس دارای `systemd`
- دسترسی `root` یا `sudo`
- دسترسی HTTPS خروجی به GitHub
- یکی از معماری‌های زیر:
  - AMD64 / x86_64
  - ARM64 / AArch64
  - ARMv7 / ARM 32-bit
- باز بودن یک پورت TCP غیراستاندارد در فایروال یا Security Group ارائه‌دهنده سرور

### نصب یک‌دستوری

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash
```

نصب با پورت دلخواه:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash -s -- --port 10443
```

نصب یک نسخه مشخص از Paqet:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash -s -- --version v1.0.0-alpha.20
```

برای بررسی اسکریپت قبل از اجرا:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh -o paqet-x-install.sh
less paqet-x-install.sh
sudo bash paqet-x-install.sh
```

### گزینه‌های اسکریپت

| گزینه | توضیح |
|---|---|
| `--port PORT` | پورت سرور بین `1024` تا `65535`؛ پورت‌های `80` و `443` پذیرفته نمی‌شوند |
| `--version TAG` | تگ ریلیز بالادستی یا مقدار `latest` |
| `--interface NAME` | تعیین دستی اینترفیس شبکه |
| `--local-ip IPV4` | تعیین دستی IPv4 محلی سرور |
| `--router-mac MAC` | تعیین دستی MAC گیت‌وی یا روتر |
| `--key KEY` | تعیین کلید اشتراکی به‌جای تولید خودکار |
| `--force-config` | بکاپ گرفتن و جایگزینی کانفیگ موجود |
| `--no-start` | نصب فایل‌ها بدون فعال‌سازی و اجرای سرویس‌ها |
| `--help` | نمایش راهنمای دستور |

متغیرهای محیطی معادل نیز پشتیبانی می‌شوند: `PAQET_PORT`، `PAQET_VERSION`، `PAQET_INTERFACE`، `PAQET_LOCAL_IP`، `PAQET_ROUTER_MAC`، `PAQET_KEY`، `FORCE_CONFIG=1`، `SKIP_START=1`، `GITHUB_TOKEN` و `NO_COLOR=1`.

### فایل‌های نصب‌شده

| مسیر | کاربرد |
|---|---|
| `/usr/local/bin/paqet` | فایل اجرایی Paqet |
| `/etc/paqet-x/server.yaml` | کانفیگ سرور و کلید اشتراکی |
| `/etc/paqet-x/firewall.env` | تنظیم پورت فایروال |
| `/usr/local/lib/paqet-x/firewall.sh` | مدیریت تکرارپذیر قوانین فایروال |
| `/etc/systemd/system/paqet-x.service` | سرویس اصلی Paqet |
| `/etc/systemd/system/paqet-x-firewall.service` | سرویس دائمی قوانین فایروال |
| `/var/lib/paqet-x/version` | نسخه نصب‌شده Paqet |

### مدیریت سرویس

```bash
sudo systemctl status paqet-x --no-pager
sudo journalctl -u paqet-x -f
sudo systemctl restart paqet-x
sudo systemctl stop paqet-x
/usr/local/bin/paqet version
```

### اجرای مجدد و آپدیت

اجرای عادی مجدد، کانفیگ فعلی و نسخه ثبت‌شده را نگه می‌دارد:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash
```

آپدیت به آخرین ریلیز بالادستی:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash -s -- --version latest
```

ممکن است بعضی ریلیزهای Paqet با نسخه‌های قبلی سازگار نباشند. نسخه کلاینت و سرور را یکسان نگه دارید.

### رفع اشکال

وضعیت سرویس‌ها و لاگ‌ها را بررسی کنید:

```bash
sudo systemctl status paqet-x paqet-x-firewall --no-pager
sudo journalctl -u paqet-x -n 100 --no-pager
sudo journalctl -u paqet-x-firewall -n 100 --no-pager
```

پورت سرور باید در فایروال یا Security Group شرکت ارائه‌دهنده سرور نیز باز باشد. اسکریپت فقط قوانین محلی `iptables` را مدیریت می‌کند و به تنظیمات فایروال پنل ارائه‌دهنده دسترسی ندارد.

اگر تشخیص خودکار شبکه درست نبود، مقادیر را دستی وارد کنید:

```bash
sudo bash paqet-x-install.sh \
  --interface eth0 \
  --local-ip 192.0.2.10 \
  --router-mac aa:bb:cc:dd:ee:ff \
  --port 9999
```

### نکات امنیتی

- اسکریپت راه‌دور را فقط از ریپو و کامیتی اجرا کنید که به آن اعتماد دارید.
- فایل دانلودی Paqet باید با SHA-256 رسمی منتشرشده در GitHub مطابقت داشته باشد.
- کانفیگ تولیدشده فقط برای کاربر root قابل‌خواندن است.
- کلید اشتراکی بعد از ساخت کانفیگ جدید یک‌بار نمایش داده می‌شود؛ آن را امن نگه دارید.
- فقط روی سرورها و شبکه‌هایی استفاده کنید که مجوز مدیریت آن‌ها را دارید.

### مجوز و اعتبار پروژه اصلی

کد نصب‌کننده این ریپو تحت [مجوز MIT](LICENSE) منتشر شده است.

پروژه اصلی Paqet توسط [`hanselime/paqet`](https://github.com/hanselime/paqet) توسعه داده می‌شود و مجوز مستقل MIT دارد. این نصب‌کننده هنگام اجرا، فایل‌های رسمی ریلیز را از پروژه اصلی دریافت می‌کند.

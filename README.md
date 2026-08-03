# Paqet X Enhanced Manager

> **فارسی** | [English](#english)

مدیریت و نصب Paqet‑X بر اساس جریان کاری پروژه‌ی
[`MrAminiDev/Paqet-X-Nulled`](https://github.com/MrAminiDev/Paqet-X-Nulled)،
با حفظ امکانات اصلی آن و افزودن حالت **فوروارد همه پورت‌ها با استثنا** برای سرور ایران.

## هشدار مهم

فایل `Paqet-Xv2` یک باینری ELF بسته و بدون سورس متناظر در آرشیو مرجع است. این پروژه فایل را تغییر یا اجرا نکرده و فقط SHA‑256 آن را ثابت کرده است:

```text
4ece7681bdc6f339307c269bec0ca1a2abd2edc4db1d3b8c644b687d91e061d2
```

ثابت بودن Hash فقط از جایگزینی ناخواسته جلوگیری می‌کند و به معنی ممیزی امنیتی باینری نیست. پیش از انتشار عمومی، مجوز بازتوزیع فایل را بررسی کنید. برای جزئیات، `NOTICE.md` و `SECURITY.md` را بخوانید.

## قابلیت‌ها

- نصب و به‌روزرسانی هسته Paqet‑X با بررسی SHA‑256
- ساخت چند سرویس مستقل روی یک سرور
- نقش Server برای خارج و Client برای ایران
- انتخاب KCP: `normal`، `fast`، `fast2` و `fast3`
- انتخاب رمزنگاری‌های پروژه مرجع
- تنظیم تعداد Connection و MTU
- **Selected Ports:** فوروارد پورت‌های انتخابی با همان بخش native `forward:` پروژه مرجع
- انتخاب TCP، UDP یا هر دو برای هر پورت انتخابی
- SOCKS5 با نام کاربری و رمز اختیاری
- **All Ports:** فوروارد تمام پورت‌های IPv4 ورودی در ایران با TCP، UDP یا هر دو
- استثنای خودکار پورت اتصال تونل
- تشخیص خودکار تمام پورت‌های SSH و افزودن به استثناها
- استثناهای دستی به‌صورت پورت تکی یا Range، مانند `25,3306,5000-5010`
- مدیریت Start، Stop، Restart، Status، Logs، Edit Config و حذف هر سرویس
- Auto‑Restart قابل تنظیم با Cron
- حذف کامل سرویس‌ها، کانفیگ‌ها، Ruleها و Helperها
- systemd سخت‌گیرانه‌تر و کاربر سیستمی جدا برای هر تونل
- تست‌های غیرمخرب و GitHub Actions

## پیش‌نیازها

- Linux با `systemd`
- دسترسی Root
- معماری `x86_64/amd64` برای باینری `Paqet-Xv2` موجود در پروژه مرجع
- Kernel و iptables دارای TPROXY برای حالت All Ports
- IPv4 برای حالت All Ports
- باز بودن پورت اتصال تونل در Firewall یا Security Group سرور خارج

## نصب یک‌دستوری

بعد از انتشار پروژه در `Unknown-sir/paqetX`، روی هر دو سرور اجرا کنید:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/install.sh)
```

ترتیب پیشنهادی:

1. نصب Dependencies
2. نصب/به‌روزرسانی Core
3. پیکربندی Server روی خارج
4. پیکربندی Client روی ایران

## نصب سمت خارج

از منوی اصلی گزینه زیر را انتخاب کنید:

```text
Configure Server (Kharej)
```

نصب‌کننده این موارد را می‌گیرد:

- نام سرویس
- پورت اتصال تونل
- Key خودکار یا دستی
- KCP Mode
- تعداد Connection
- MTU
- Encryption
- Server Profile

### Server Profile

برای Port Forward انتخابی یا All Ports، این گزینه را انتخاب کنید:

```text
Port forwarding (selected/all ports)
```

برای SOCKS5 معمولی اینترنت، گزینه SOCKS5 Profile را انتخاب کنید. پروفایل Forward و SOCKS5 معمولی را روی سرویس‌های جدا بسازید.

در پایان IP، پورت، Key و تنظیمات لازم برای سرور ایران نمایش داده می‌شوند.

## نصب سمت ایران

از منوی اصلی انتخاب کنید:

```text
Configure Client (Iran)
```

ابتدا IP خارج، پورت تونل، Key و تنظیمات KCP مطابق سرور خارج وارد می‌شوند. سپس نوع ترافیک انتخاب می‌شود.

### حالت ۱: Selected Ports

این حالت دقیقاً از ساختار native پروژه مرجع استفاده می‌کند:

```yaml
forward:
  - listen: "0.0.0.0:443"
    target: "127.0.0.1:443"
    protocol: "tcp"
```

برای هر پورت می‌توان TCP، UDP یا هر دو را انتخاب کرد.

### حالت ۲: All Ports with exclusions

تمام پورت‌های ورودی IPv4 روی سرور ایران با همان شماره پورت به سرویس متناظر در سرور خارج منتقل می‌شوند، به‌جز:

- پورت اتصال تونل Paqet‑X
- تمام پورت‌های SSH تشخیص‌داده‌شده
- پورت‌ها یا Rangeهایی که کاربر وارد می‌کند
- پورت‌های داخلی Helper که فقط روی Loopback استفاده می‌شوند

نمونه استثنا:

```text
25,3306,5432,5000-5010
```

نمونه نتیجه با پورت تونل `8888` و SSH روی `22` و `2222`:

```text
Excluded: 22,2222,8888,25,3306,5432,5000-5010
All remaining ports: forwarded
```

پورت SSH از منابع زیر تشخیص داده می‌شود:

- اتصال فعلی `SSH_CONNECTION`
- خروجی مؤثر `sshd -T`
- Socketهای فعال `sshd`
- `/etc/ssh/sshd_config`
- فایل‌های `/etc/ssh/sshd_config.d/*.conf`
- مقدار محافظتی `22` در صورت تشخیص‌ندادن پورت

قبل از اعمال Ruleها، استثناهای نهایی نمایش داده می‌شوند و نیاز به تأیید دارند.

## معماری All Ports

هسته مرجع برای `forward:` فقط پورت مشخص می‌پذیرد. ساخت ده‌ها هزار Listener عملی و پایدار نیست؛ بنابراین حالت All Ports از این مسیر استفاده می‌کند:

```text
Internet client
    → Iran iptables TPROXY
    → HevSocks5TProxy
    → local Paqet-X SOCKS5
    → Paqet-X tunnel
    → Kharej Paqet-X process
    → localhost:same-port
```

Hev فقط از Release رسمی و نسخه ثابت دانلود می‌شود و Digest منتشرشده GitHub بررسی می‌شود. حالت Selected Ports به Hev یا TPROXY وابسته نیست.

## نکات عملیاتی

- روی هر سرور ایران فقط یک سرویس All Ports فعال می‌شود، زیرا ورودی Local سیستم را در اختیار می‌گیرد.
- سرویس‌های Selected Ports و SOCKS5 مستقل قابل ساخت هستند، به شرط نبود تداخل پورت.
- در حالت All Ports، یک راه دسترسی مدیریتی جایگزین از پنل VPS نگه دارید.
- Firewall ابری یا Security Group خارج از سیستم‌عامل توسط اسکریپت قابل تغییر نیست.
- روی سرور خارج باید سرویس مقصد واقعاً روی همان پورت Listen کند.
- Auto‑Restart پروژه مرجع حفظ شده و از منوی مدیریت قابل تغییر یا غیرفعال‌کردن است.

## مدیریت و حذف

منوی Service Management امکانات زیر را دارد:

- Start / Stop / Restart
- Status
- مشاهده Logهای اخیر یا Live
- نمایش و ویرایش Config
- مدیریت Auto‑Restart
- حذف یک سرویس و Helperهای وابسته

گزینه Uninstall می‌تواند فقط باینری یا کل پروژه را حذف کند. در حذف کامل، Ruleهای iptables، Policy Routing، سرویس TPROXY، کانفیگ‌ها و کاربران سیستمی ساخته‌شده نیز پاک می‌شوند.

## تست

```bash
bash -n install.sh tests/test.sh
bash tests/test.sh
```

CI علاوه بر این موارد، ShellCheck و بررسی SHA‑256 باینری را اجرا می‌کند.

## فایل‌ها

```text
install.sh                 Installer and manager
Paqet-Xv2                  Opaque reference binary, checksum-pinned
README.md                  Persian and English documentation
NOTICE.md                  Provenance and redistribution notice
SECURITY.md                Security guidance
CHANGELOG.md               Release history
tests/test.sh              Non-destructive tests
.github/workflows/test.yml GitHub Actions workflow
```

## اعتبارها

- جریان مدیریت و باینری مرجع: `MrAminiDev/Paqet-X-Nulled`
- Helper اختیاری All Ports: `heiher/hev-socks5-tproxy`
- ریپوی مقصد: `Unknown-sir/paqetX`

---

<a id="english"></a>

# English

Paqet‑X installer and service manager rebuilt around the workflow of
[`MrAminiDev/Paqet-X-Nulled`](https://github.com/MrAminiDev/Paqet-X-Nulled),
while preserving its main features and adding an **All Ports with exclusions** mode for the Iran client.

## Important warning

`Paqet-Xv2` is a stripped, opaque third-party ELF binary. The supplied reference archive did not include corresponding source code. This project retains the file unchanged and pins its SHA‑256:

```text
4ece7681bdc6f339307c269bec0ca1a2abd2edc4db1d3b8c644b687d91e061d2
```

A matching checksum prevents accidental replacement; it is not a security audit. Confirm redistribution rights before publishing and review `NOTICE.md` and `SECURITY.md`.

## Features

- Verified Paqet‑X core installation and updates
- Multiple independent tunnel services
- Kharej server and Iran client roles
- KCP mode, encryption, connection count and MTU selection
- Native selected-port forwarding using the reference project's `forward:` configuration
- Per-port TCP, UDP or TCP+UDP selection
- Optional authenticated SOCKS5
- All incoming IPv4 ports forwarding on Iran with TCP, UDP or both
- Automatic tunnel-port and SSH-port exclusions
- User exclusions with individual ports and ranges
- Service management, logs, config editing and configurable cron auto-restart
- Complete uninstall including firewall, policy-routing and helper cleanup
- Per-tunnel system users and hardened systemd units
- Non-destructive integration tests and GitHub Actions

## Requirements

- Root access on a systemd-based Linux server
- `x86_64/amd64` for the supplied reference binary
- TPROXY-capable kernel and iptables for All Ports mode
- IPv4 for All Ports mode
- The tunnel port allowed by the Kharej provider firewall/security group

## One-command install

After publishing to `Unknown-sir/paqetX`:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/install.sh)
```

Install the Kharej server first and copy its IP, tunnel port, key and transport settings into the Iran client wizard.

## Forwarding modes

### Selected Ports

Uses Paqet‑X's native `forward:` list exactly like the reference project. Every port can use TCP, UDP or both.

### All Ports with exclusions

Captures incoming IPv4 traffic on the Iran server and forwards it to the same destination port on the Kharej server, excluding:

- the Paqet‑X tunnel port;
- every automatically detected SSH port;
- user-provided ports and ranges;
- internal loopback-only helper ports.

The installer detects SSH ports from the current session, effective sshd configuration, active sshd sockets and SSH configuration files. It shows the final exclusion list before applying rules.

All Ports uses the native local Paqet‑X SOCKS5 listener, HevSocks5TProxy and Linux TPROXY. Selected Ports does not require Hev or TPROXY. Only one All Ports service may own an Iran host at a time.

## Testing

```bash
bash -n install.sh tests/test.sh
bash tests/test.sh
```

GitHub Actions also runs ShellCheck and verifies the bundled binary checksum.

## Attribution

- Reference workflow and supplied binary: `MrAminiDev/Paqet-X-Nulled`
- Optional All Ports helper: `heiher/hev-socks5-tproxy`
- Target repository: `Unknown-sir/paqetX`

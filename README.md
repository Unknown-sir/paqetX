# Paqet X

نصب‌کننده و مدیر دوطرفه Paqet برای راه‌اندازی تونل بین **سرور خارج** و **سرور ایران** با Port Forward خودکار.

[English documentation](#english)

> این پروژه یک نصب‌کننده مستقل برای هسته متن‌باز [`hanselime/paqet`](https://github.com/hanselime/paqet) است و ریپوی رسمی Paqet نیست. فایل اجرایی فقط از Releaseهای رسمی پروژه اصلی دانلود می‌شود.

## فارسی

### معماری

```text
کاربر یا اپلیکیشن
        │
        ▼
IP ایران : پورت ورودی
        │
        ▼
Paqet Client روی سرور ایران
        ═════ Raw TCP + KCP ═════▶
Paqet Server روی سرور خارج
        │
        ▼
127.0.0.1 : پورت سرویس مقصد
```

نقش‌ها به‌صورت واضح در نصب مشخص می‌شوند:

- **خارج / Abroad:** نقش `server` در Paqet؛ کنار Xray، sing-box، پنل یا سرویس مقصد اجرا می‌شود.
- **ایران / Iran:** نقش `client` در Paqet؛ روی پورت‌های عمومی ایران Listen می‌کند و ترافیک را به پورت‌های مقصد روی خارج می‌فرستد.

برای نمونه، نگاشت `8443:443/tcp` یعنی:

- کاربران به `IP-IRAN:8443` وصل می‌شوند؛
- ترافیک داخل تونل به سرور خارج می‌رود؛
- سرور خارج آن را به `127.0.0.1:443` تحویل می‌دهد.

### امکانات

- ویزارد دو‌زبانه برای انتخاب **سرور خارج** یا **سرور ایران**؛
- یک دستور یکسان برای نصب روی هر دو سرور؛
- تولید کلید امن روی سرور خارج؛
- تولید رشته اتصال `paqetx://...` شامل نسخه، آدرس، پورت، کلید، KCP و نگاشت‌های پیشنهادی؛
- تنظیم خودکار سرور ایران فقط با Paste کردن رشته اتصال؛
- پشتیبانی از چند Port Forward هم‌زمان؛
- پشتیبانی از TCP و UDP؛
- پشتیبانی اختیاری از SOCKS5 در کنار Port Forward؛
- تشخیص خودکار Interface، IPv4 محلی، Gateway و MAC روتر؛
- دانلود نسخه رسمی متناسب با AMD64، ARM64 یا ARMv7؛
- بررسی SHA-256 منتشرشده توسط GitHub قبل از نصب؛
- ساخت سرویس‌های systemd و اجرای خودکار بعد از ریبوت؛
- اعمال idempotent قوانین ضروری `iptables` برای سمت خارج؛
- باز کردن خودکار پورت‌های Forward در فایروال محلی سمت ایران؛
- حفظ کامل کانفیگ هنگام اجرای مجدد؛
- بکاپ خودکار قبل از `--reconfigure`؛
- ابزار مدیریتی `paqetx` برای وضعیت، لاگ، تست، ری‌استارت و حذف؛
- پیام‌های مرحله‌ای و نمایش خطای واضح به‌جای شکست بی‌صدا.

### پیش‌نیازها

- لینوکس با `systemd`؛
- دسترسی `root` یا `sudo`؛
- دسترسی HTTPS خروجی به GitHub؛
- معماری AMD64، ARM64 یا ARMv7؛
- یک پورت TCP غیراستاندارد برای ارتباط Paqet بین ایران و خارج.

پورت Transport را روی `80` یا `443` قرار ندهید. این محدودیت مربوط به قوانین NOTRACK/RST موردنیاز Paqet است. پورت‌های Forward سمت ایران، از جمله `443`، مجاز هستند.

## نصب سریع دو مرحله‌ای

### مرحله ۱ — سرور خارج

روی سرور خارج اجرا کنید:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash
```

گزینه `1` یا **Abroad / خارج** را انتخاب کنید. نصب‌کننده:

1. شبکه را تشخیص می‌دهد؛
2. نسخه رسمی Paqet را نصب می‌کند؛
3. کلید امن تولید می‌کند؛
4. سرویس و قوانین لازم را می‌سازد؛
5. در پایان یک رشته `paqetx://...` نمایش می‌دهد.

رشته اتصال را خصوصی نگه دارید؛ این رشته حاوی کلید مشترک است.

### مرحله ۲ — سرور ایران

همان دستور را روی سرور ایران اجرا کنید:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash
```

گزینه `2` یا **Iran / ایران** را انتخاب و رشته اتصال مرحله قبل را Paste کنید. نسخه، آدرس خارج، پورت، کلید و Forwardها خودکار وارد می‌شوند.

پس از نصب، کاربران باید به **IP سرور ایران** و پورت Listen تعریف‌شده متصل شوند.

## مثال Port Forward

ورودی زیر در ویزارد:

```text
443,8443:443,2053:53/udp
```

این نگاشت‌ها را می‌سازد:

| پورت روی ایران | مقصد روی خارج | پروتکل |
|---:|---:|---|
| `443` | `127.0.0.1:443` | TCP |
| `8443` | `127.0.0.1:443` | TCP |
| `2053` | `127.0.0.1:53` | UDP |

فرمت‌های قابل قبول:

```text
PORT
LOCAL_PORT:TARGET_PORT
LOCAL_PORT:TARGET_PORT/tcp
LOCAL_PORT:TARGET_PORT/udp
```

## نصب غیرتعاملی

### خارج

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | \
  sudo bash -s -- \
  --role abroad \
  --port 9999 \
  --public-host 203.0.113.10 \
  --forward 443:443/tcp \
  --forward 8443:8443/tcp \
  --yes
```

### ایران با رشته اتصال

برای امنیت بیشتر، رشته اتصال را در Prompt تعاملی Paste کنید تا در History شل ذخیره نشود. حالت غیرتعاملی نیز پشتیبانی می‌شود:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | \
  sudo bash -s -- \
  --role iran \
  --connection-string 'paqetx://PASTE_TOKEN_HERE' \
  --yes
```

### ایران با تنظیم دستی

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | \
  sudo bash -s -- \
  --role iran \
  --foreign-host 203.0.113.10 \
  --port 9999 \
  --key 'YOUR_SHARED_KEY' \
  --forward 443:443/tcp \
  --forward 8443:8443/tcp \
  --yes
```

## فایروال و Security Group

اسکریپت قوانین محلی را مدیریت می‌کند، اما به پنل دیتاسنتر یا Cloud Provider دسترسی ندارد.

روی **سرور خارج**:

- پورت TCP مربوط به Transport، برای مثال `9999`، باید در Security Group یا فایروال پنل باز باشد.

روی **سرور ایران**:

- پورت‌های عمومی Forward، برای مثال `443` و `8443`، باید در Security Group یا فایروال پنل باز باشند؛
- اسکریپت به‌صورت پیش‌فرض قوانین محلی `iptables INPUT` را اضافه می‌کند؛
- برای جلوگیری از این کار از `--no-open-forward-ports` استفاده کنید.

## سرویس مقصد روی خارج

مقصد پیش‌فرض Forward برابر `127.0.0.1` است. بنابراین سرویس مقصد باید روی `127.0.0.1:PORT` یا `0.0.0.0:PORT` در دسترس باشد.

برای تغییر مقصد همه نگاشت‌ها:

```bash
sudo bash paqet-x-install.sh \
  --role iran \
  --target-host 10.0.0.5 \
  --forward 8443:443 \
  --reconfigure
```

## مدیریت

```bash
sudo paqetx status
sudo paqetx logs
sudo paqetx test
sudo paqetx restart
sudo paqetx token      # فقط روی خارج؛ حاوی کلید است
sudo paqetx config     # حاوی کلید است
sudo paqetx version
sudo paqetx uninstall
```

فایل‌های اصلی:

| مسیر | کاربرد |
|---|---|
| `/usr/local/bin/paqet` | فایل اجرایی رسمی Paqet |
| `/usr/local/sbin/paqetx` | ابزار مدیریت |
| `/etc/paqet-x/config.yaml` | کانفیگ فعال و کلید مشترک |
| `/etc/paqet-x/connection.txt` | رشته اتصال سمت خارج |
| `/etc/paqet-x/install.env` | وضعیت نصب |
| `/usr/local/lib/paqet-x/firewall.sh` | مدیریت قوانین فایروال |
| `/etc/systemd/system/paqet-x.service` | سرویس اصلی |
| `/etc/systemd/system/paqet-x-firewall.service` | سرویس فایروال |

## اجرای مجدد، تغییر کانفیگ و آپدیت

اجرای عادی مجدد، نقش و کانفیگ قبلی را حفظ می‌کند:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash
```

برای اجرای دوباره ویزارد و جایگزینی کانفیگ با بکاپ خودکار:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash -s -- --reconfigure
```

آپدیت هر دو سمت به آخرین Release رسمی:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash -s -- --version latest
```

نسخه Paqet در دو سمت باید یکسان باشد؛ بعضی Releaseها با نسخه قبلی سازگار نیستند. رشته اتصال، نسخه سرور خارج را نیز منتقل می‌کند.

## رفع اشکال

```bash
sudo paqetx status
sudo paqetx test
sudo journalctl -u paqet-x -n 100 --no-pager
sudo journalctl -u paqet-x-firewall -n 100 --no-pager
```

موارد رایج:

- **Paqet ping ناموفق:** پورت Transport در فایروال دیتاسنتر خارج باز نیست، IP اشتباه است، کلیدها متفاوت‌اند یا نسخه‌ها یکسان نیستند.
- **سرویس فعال است ولی کاربر وصل نمی‌شود:** پورت Forward در پنل سرور ایران باز نیست یا سرویس مقصد روی خارج Listen نمی‌کند.
- **تشخیص شبکه اشتباه است:** از `--interface`، `--local-ip` و `--router-mac` همراه `--reconfigure` استفاده کنید.
- **GitHub در ایران در دسترس نیست:** فایل اسکریپت و Release رسمی را از یک مسیر مورداعتماد به سرور منتقل کنید؛ از باینری ناشناس استفاده نکنید.

## نکات امنیتی

- فقط روی سرورها و شبکه‌هایی اجرا کنید که مجوز مدیریتشان را دارید.
- قبل از اجرای مستقیم اسکریپت راه‌دور می‌توانید آن را دانلود و بررسی کنید:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh -o paqet-x-install.sh
less paqet-x-install.sh
sudo bash paqet-x-install.sh
```

- کانفیگ و رشته اتصال با مجوز `0600` نگهداری می‌شوند.
- رشته اتصال و خروجی `paqetx config` شامل Secret هستند و نباید عمومی شوند.
- حالت‌های رمزنگاری بدون احراز هویت `none` و `null` عمداً توسط نصب‌کننده پذیرفته نمی‌شوند.

## مجوز

کد این نصب‌کننده تحت [MIT License](LICENSE) منتشر شده است. Paqet متعلق به پروژه اصلی [`hanselime/paqet`](https://github.com/hanselime/paqet) و دارای مجوز مستقل خود است.

---

<a id="english"></a>

## English

Paqet X is a guided, two-sided installer and manager for an **Abroad Paqet server** and an **Iran entry server with port forwarding**.

### Topology

```text
User or application
        │
        ▼
Iran server IP : public listen port
        │
        ▼
Paqet client on Iran server
        ═════ Raw TCP + KCP ═════▶
Paqet server abroad
        │
        ▼
127.0.0.1 : target service port
```

- **Abroad role:** runs Paqet as `server` next to the destination service.
- **Iran role:** runs Paqet as `client`, listens on public entry ports, and forwards traffic through the tunnel.

A mapping such as `8443:443/tcp` listens on port `8443` in Iran and delivers traffic to `127.0.0.1:443` on the abroad side.

### Features

- Explicit Abroad/Iran role wizard;
- the same one-command installer on both servers;
- secure key generation on the abroad server;
- a `paqetx://` connection string containing the host, port, version, key, KCP settings, and suggested mappings;
- automatic Iran configuration by pasting the connection string;
- multiple TCP and UDP port forwards;
- optional SOCKS5 alongside port forwarding;
- automatic interface, local IPv4, gateway, and router-MAC detection;
- verified official upstream releases for AMD64, ARM64, and ARMv7;
- SHA-256 verification using the digest published by GitHub;
- hardened systemd services and persistent idempotent firewall rules;
- configuration-preserving reruns and backups before reconfiguration;
- `paqetx` status, log, test, restart, token, config, version, and uninstall commands.

### Two-step installation

Run on the abroad server:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash
```

Choose **Abroad**, complete the short wizard, and copy the printed `paqetx://` connection string.

Run the same command on the Iran server, choose **Iran**, and paste the connection string. The installer imports the matching version, host, port, secret, KCP settings, and forward presets.

### Forward syntax

```text
PORT
LOCAL_PORT:TARGET_PORT
LOCAL_PORT:TARGET_PORT/tcp
LOCAL_PORT:TARGET_PORT/udp
```

Example:

```text
443,8443:443,2053:53/udp
```

### Non-interactive abroad setup

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | \
  sudo bash -s -- \
  --role abroad \
  --port 9999 \
  --public-host 203.0.113.10 \
  --forward 443:443/tcp \
  --forward 8443:8443/tcp \
  --yes
```

### Non-interactive Iran setup

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | \
  sudo bash -s -- \
  --role iran \
  --connection-string 'paqetx://PASTE_TOKEN_HERE' \
  --yes
```

Pasting the token interactively is safer because a command-line token can be stored in shell history or briefly exposed in the process list.

### Firewall requirements

The installer manages local iptables rules. It cannot change a cloud provider firewall or security group.

- On the **abroad server**, allow inbound TCP on the Paqet transport port, such as `9999`.
- On the **Iran server**, allow the public forwarded ports, such as `443` and `8443`.
- The installer opens local Iran INPUT rules by default. Use `--no-open-forward-ports` to disable this behavior.

Do not use `80` or `443` as the Paqet transport port. Forwarded Iran listen ports may use `80` or `443`.

### Management

```bash
sudo paqetx status
sudo paqetx logs
sudo paqetx test
sudo paqetx restart
sudo paqetx token
sudo paqetx config
sudo paqetx version
sudo paqetx uninstall
```

### Reruns and upgrades

A normal rerun preserves the existing role and configuration:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash
```

Run the wizard again, with automatic backups:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash -s -- --reconfigure
```

Upgrade both sides to the latest official release:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash -s -- --version latest
```

The client and server must run matching Paqet versions. Upstream releases may contain protocol-breaking changes.

### Security

- Use only on systems and networks you are authorized to administer.
- Review remote scripts before running them when possible.
- The configuration and connection token are root-only files.
- The connection string contains the shared secret; keep it private.
- Unauthenticated `none` and `null` cipher modes are deliberately rejected.

### License and upstream credit

This installer is released under the [MIT License](LICENSE). The Paqet core is developed by [`hanselime/paqet`](https://github.com/hanselime/paqet) and is distributed under its own license.

# Paqet X

نصب‌کننده دوطرفه و یک‌دستوری برای راه‌اندازی Paqet بین **سرور خارج** و **سرور ایران**، با دو روش فوروارد:

- پورت‌های انتخابی کاربر
- همه پورت‌ها، به‌جز پورت تونل، پورت‌های SSH شناسایی‌شده و پورت‌های استثنای کاربر

[English documentation](#english)

> این پروژه یک نصب‌کننده مستقل برای هسته متن‌باز [`hanselime/paqet`](https://github.com/hanselime/paqet) است و ریپوی رسمی Paqet نیست. در حالت همه‌پورت، از [`heiher/hev-socks5-tproxy`](https://github.com/heiher/hev-socks5-tproxy) به‌عنوان لایه Transparent Proxy استفاده می‌شود.

## فارسی

### معماری نصب

```text
سرور خارج
  ├─ نصب Paqet با نقش server
  ├─ ساخت Key امن
  ├─ نصب سرویس systemd و قوانین لازم شبکه
  └─ نمایش نسخه، پورت تونل و Key

سرور ایران
  ├─ دریافت IP/دامنه، پورت تونل و Key سرور خارج
  ├─ انتخاب TCP، UDP یا هر دو
  ├─ انتخاب یکی از دو حالت Forward
  │    ├─ پورت‌های انتخابی
  │    └─ همه پورت‌ها با استثناها
  ├─ نصب Paqet با نقش client
  └─ تست اتصال تونل پیش از اعلام موفقیت
```

سمت خارج هیچ لیست Port Forward از کاربر نمی‌گیرد. تمام تصمیم‌های Forward روی سرور ایران انجام می‌شوند.

### نصب یک‌دستوری

روی هر دو سرور همین دستور را اجرا کنید:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash
```

منوی اصلی:

```text
1) Install Abroad / نصب سرور خارج
2) Install Iran / نصب سرور ایران
3) Uninstall completely / حذف کامل
4) Exit / خروج
```

## نصب سرور خارج

گزینه `1` را انتخاب کنید. نصب‌کننده:

1. پورت تونل Paqet را می‌گیرد؛ مقدار پیشنهادی `9999` است.
2. Interface، IPv4 محلی و MAC گیت‌وی را تشخیص می‌دهد.
3. یک Key تصادفی امن می‌سازد.
4. Paqet را با نقش رسمی `server` نصب می‌کند.
5. سرویس systemd و قوانین ضروری iptables را می‌سازد.
6. این اطلاعات را برای واردکردن روی سرور ایران نمایش می‌دهد:

```text
Paqet version: v1.0.0-alpha.20
Tunnel port: 9999
Shared key: 0123456789abcdef...
```

برای نمایش مجدد:

```bash
sudo paqetx key
```

TCP پورت تونل را در Firewall یا Security Group سرور خارج باز کنید. برای پورت تونل از `80` یا `443` استفاده نکنید.

## نصب سرور ایران

گزینه `2` را انتخاب کنید. اطلاعات زیر گرفته می‌شوند:

1. IP عمومی یا دامنه سرور خارج
2. پورت تونل سرور خارج
3. Key ساخته‌شده روی سرور خارج
4. پروتکل:

```text
1) فقط TCP
2) فقط UDP
3) TCP و UDP
```

5. روش Forward:

```text
1) Selected ports / پورت‌های انتخابی
2) All ports except tunnel, SSH, and exclusions
   همه پورت‌ها به‌جز تونل، SSH و استثناها
```

### حالت اول: پورت‌های انتخابی

پورت‌ها را با کاما وارد کنید:

```text
443,8443,2053
```

اگر `443,8443` و گزینه «هر دو» انتخاب شود، این Forwardها ساخته می‌شوند:

```text
Iran :443/TCP   -> Abroad 127.0.0.1:443/TCP
Iran :443/UDP   -> Abroad 127.0.0.1:443/UDP
Iran :8443/TCP  -> Abroad 127.0.0.1:8443/TCP
Iran :8443/UDP  -> Abroad 127.0.0.1:8443/UDP
```

برای جلوگیری از قطع دسترسی، نصب‌کننده اجازه نمی‌دهد پورت تونل یا پورت SSH فعال سرور ایران در حالت انتخابی Forward شود.

### حالت دوم: همه پورت‌ها

در این حالت شماره پورت حفظ می‌شود:

```text
Iran :PORT/TCP or UDP -> Abroad 127.0.0.1:PORT
```

موارد زیر خودکار از Forward خارج می‌شوند:

- پورت تونل Paqet
- تمام پورت‌های SSH شناسایی‌شده روی سرور ایران
- هر تعداد پورت اضافی که کاربر وارد کند

نمونه پورت‌های استثنا:

```text
25,3306,5432,6379
```

پورت SSH با چند روش بررسی می‌شود:

- اتصال فعلی از متغیر `SSH_CONNECTION`
- خروجی مؤثر `sshd -T`
- سوکت‌های فعال متعلق به `sshd`
- `sshd_config` و فایل‌های `sshd_config.d`

اگر هیچ پورت فعالی قابل اثبات نباشد، پورت `22` برای حفظ دسترسی مستثنا می‌شود. برای تعیین دستی چند پورت SSH می‌توان از این گزینه استفاده کرد:

```bash
--ssh-ports 22,2222
```

Paqet برای Forwardهای ثابت، ورودی تک‌پورت تعریف می‌کند. بنابراین حالت همه‌پورت به‌جای ساخت هزاران Listener، SOCKS5 داخلی Paqet را به HevSocks5TProxy و قوانین Linux TPROXY متصل می‌کند. این حالت برای ترافیک ورودی IPv4 طراحی شده است.

### اصلاح حالت همه‌پورت در نسخه 4.1.0

نسخه 4.0 فقط فعال بودن سرویس و سلامت تونل Paqet را بررسی می‌کرد و مسیر واقعی Transparent Forward را تست نمی‌کرد. در نسخه 4.1 این موارد اصلاح شده‌اند:

- قانون مقصد سمت خارج از DNAT عمومی به REDIRECT محدود به UID سرویس Paqet تغییر کرده است؛ شماره پورت حفظ می‌شود.
- hook حالت همه‌پورت دیگر به یک Interface تشخیص‌داده‌شده محدود نیست؛ این محدودیت روی بعضی VPSها و شبکه‌های 1:1 NAT باعث می‌شد بسته‌ها وارد chain نشوند.
- ترافیک loopback، mark داخلی Hev، پورت SOCKS5 و پورت listener داخلی TPROXY از بازگشت دوباره به تونل مستثنا می‌شوند.
- بعد از نصب، وجود ruleها، policy route و listenerهای TCP/UDP بررسی می‌شود و نصب در صورت ناقص بودن موفق اعلام نمی‌شود.
- دستور `sudo paqetx diagnose` برای نمایش listenerها، routeها، ruleها و شمارنده بسته‌ها اضافه شده است.

برای ارتقا از نسخه 4.0، اسکریپت جدید را **روی هر دو سرور** دوباره اجرا کنید. کانفیگ و Key فعلی حفظ می‌شوند و ruleهای قدیمی با ruleهای اصلاح‌شده جایگزین می‌شوند:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash
```

بعد از ارتقا اجرا کنید:

```bash
sudo paqetx test
sudo paqetx diagnose
```

در خروجی `diagnose`، افزایش شمارنده chain با نام `PAQETX_ALLPORT` هنگام تست یک پورت عمومی نشان می‌دهد بسته به سرور ایران رسیده است. صفر ماندن شمارنده معمولاً به Firewall یا Security Group شرکت میزبان اشاره می‌کند.

> در Firewall یا Security Group سرور ایران نیز باید پورت‌هایی که قرار است از اینترنت دریافت شوند مجاز باشند. نصب‌کننده نمی‌تواند قوانین خارج از سیستم‌عامل، مانند پنل Cloud Provider، را تغییر دهد.

## نمونه نصب غیرتعاملی

سرور خارج:

```bash
sudo bash paqet-x-install.sh \
  --role abroad \
  --port 9999 \
  --yes
```

سرور ایران، پورت‌های انتخابی:

```bash
sudo bash paqet-x-install.sh \
  --role iran \
  --foreign-host 203.0.113.10 \
  --port 9999 \
  --key 'KEY-FROM-ABROAD' \
  --forward-mode selected \
  --ports 443,8443 \
  --protocol both \
  --yes
```

سرور ایران، همه پورت‌های TCP و UDP با چند استثنا:

```bash
sudo bash paqet-x-install.sh \
  --role iran \
  --foreign-host 203.0.113.10 \
  --port 9999 \
  --key 'KEY-FROM-ABROAD' \
  --all-ports \
  --exclude-ports 25,3306,5432 \
  --protocol both \
  --yes
```

`--exclude-ports` قابل تکرار است:

```bash
--exclude-ports 25,3306 --exclude-ports 5432,6379
```

حالت‌های معتبر پروتکل:

```text
tcp
udp
both
```

## حذف کامل

دستور نصب را دوباره اجرا و گزینه `3` را انتخاب کنید، یا:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh \
  | sudo bash -s -- --uninstall --yes
```

حذف کامل شامل این موارد است:

- سرویس Paqet، Firewall و سرویس TPROXY در صورت نصب
- قوانین iptables و policy routing ثبت‌شده
- باینری Paqet و HevSocks5TProxy
- کانفیگ، State و فایل‌های systemd
- ابزار `paqetx`
- کاربر سیستمی `paqetx`، فقط در صورتی که خود نصب‌کننده آن را ساخته باشد

## دستورات مدیریت

```bash
sudo paqetx status
sudo paqetx logs
sudo paqetx test
sudo paqetx diagnose
sudo paqetx restart
sudo paqetx start
sudo paqetx stop
sudo paqetx version
sudo paqetx config
sudo paqetx uninstall
```

روی سرور خارج:

```bash
sudo paqetx key
```

## اجرای مجدد

اجرای مجدد با همان نقش، نسخه و کانفیگ فعلی را حفظ می‌کند. برای ساخت کانفیگ جدید:

```bash
sudo bash paqet-x-install.sh --role iran --reconfigure
```

برای تغییر نقش، ابتدا حذف کامل را اجرا کنید.

## امنیت و یکپارچگی دانلود

- باینری Paqet فقط از Release رسمی `hanselime/paqet` دریافت می‌شود.
- HevSocks5TProxy فقط در حالت همه‌پورت و از Release رسمی `heiher/hev-socks5-tproxy` دریافت می‌شود.
- URL دارایی Release و SHA-256 منتشرشده توسط GitHub بررسی می‌شوند.
- فایل کانفیگ شامل Key است و برای `root` و گروه سرویس با دسترسی محدود نصب می‌شود.
- بهتر است Key را تعاملی وارد کنید؛ قرار دادن `--key` در خط فرمان ممکن است آن را وارد Shell History کند.

## نیازمندی‌ها

- Linux با systemd
- دسترسی root یا sudo
- AMD64، ARM64 یا ARMv7
- iptables و پشتیبانی Kernel از TPROXY برای حالت همه‌پورت
- دسترسی HTTPS به GitHub Releases
- دسترسی قانونی و مجاز به سرورها و شبکه

## فایل‌های اصلی نصب‌شده

```text
/usr/local/bin/paqet
/usr/local/bin/hev-socks5-tproxy       # فقط حالت همه‌پورت
/usr/local/sbin/paqetx
/etc/paqet-x/config.yaml
/etc/paqet-x/tproxy.yaml               # فقط حالت همه‌پورت
/etc/paqet-x/install.env
/etc/paqet-x/firewall.env
/usr/local/lib/paqet-x/firewall.sh
/etc/systemd/system/paqet-x.service
/etc/systemd/system/paqet-x-firewall.service
/etc/systemd/system/paqet-x-tproxy.service  # فقط حالت همه‌پورت
/var/lib/paqet-x/version
```

---

## English

Paqet X is a one-command, two-server installer for an **Abroad Paqet server** and an **Iran Paqet client**. The Iran side supports:

- user-selected forwarding ports; or
- all inbound ports except the Paqet tunnel port, automatically detected SSH ports, and user-defined exclusions.

### Installation architecture

```text
Abroad server
  ├─ Install Paqet in server role
  ├─ Generate a secure shared key
  ├─ Install systemd and required network rules
  └─ Print version, tunnel port, and shared key

Iran server
  ├─ Ask for Abroad host, tunnel port, and shared key
  ├─ Select TCP, UDP, or both
  ├─ Select chosen-port or all-port forwarding
  ├─ Install Paqet in client role
  └─ Test the tunnel before reporting success
```

### One-command installer

Run the same command on both servers:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash
```

Main menu:

```text
1) Install Abroad
2) Install Iran
3) Uninstall completely
4) Exit
```

### Abroad server

Choose option `1`. The installer asks for the tunnel port, generates a key, installs the Paqet server service, and prints:

```text
Paqet version: v1.0.0-alpha.20
Tunnel port: 9999
Shared key: 0123456789abcdef...
```

Show the values later with:

```bash
sudo paqetx key
```

Allow inbound TCP on the tunnel port in the provider firewall. Do not use `80` or `443` as the Paqet tunnel port.

### Iran server

Choose option `2`, then enter the Abroad host, tunnel port, and shared key. Select one protocol mode:

```text
1) TCP only
2) UDP only
3) TCP and UDP
```

Then select one forwarding mode.

#### Selected ports

Enter ports such as:

```text
443,8443,2053
```

The same port number is used on Iran and Abroad by default. Paqet X refuses to forward the tunnel port or a detected active SSH port in selected mode.

#### All ports with exclusions

All selected-protocol IPv4 inbound ports keep their original number and terminate on `127.0.0.1:<same-port>` on the Abroad server, except:

- the Paqet tunnel port;
- automatically detected Iran SSH ports; and
- extra exclusions entered by the user.

Example exclusions:

```text
25,3306,5432,6379
```

SSH detection checks `SSH_CONNECTION`, effective `sshd -T` output, active `sshd` listeners, and SSH configuration files. Port `22` is protected as a fallback when an active port cannot be proven. Advanced override:

```bash
--ssh-ports 22,2222
```

Paqet's fixed-forward configuration uses individual port entries. Paqet X implements all-port mode by connecting Paqet's local SOCKS5 listener to HevSocks5TProxy and Linux TPROXY rules, rather than creating tens of thousands of listeners.

#### All-port forwarding fix in 4.1.0

Version 4.0 checked only service activity and the Paqet tunnel ping; it did not validate the complete transparent-forwarding path. Version 4.1 fixes that path:

- Abroad destination rewriting now uses a Paqet-UID-scoped `REDIRECT`, preserving the original destination port.
- The Iran PREROUTING hook is no longer tied to one detected interface, which failed on some VPS and 1:1 NAT layouts.
- Loopback traffic, Hev's internal socket mark, the SOCKS5 port, and the internal TPROXY listener are bypassed to prevent recapture.
- Installation verifies the firewall rules, policy route, and TCP/UDP listeners before reporting success.
- `sudo paqetx diagnose` displays listeners, routes, firewall rules, and packet counters.

Upgrade both servers by rerunning the new installer. Existing role, key, and configuration are preserved while old rules are replaced:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh | sudo bash
```

Then run:

```bash
sudo paqetx test
sudo paqetx diagnose
```

When testing a public port, the `PAQETX_ALLPORT` counters should increase. Counters that remain at zero usually mean the provider firewall or security group did not deliver the packet to the Iran host.

Provider-level firewalls on the Iran server must also permit the intended public ports.

### Non-interactive examples

Abroad:

```bash
sudo bash paqet-x-install.sh --role abroad --port 9999 --yes
```

Iran, selected ports:

```bash
sudo bash paqet-x-install.sh \
  --role iran \
  --foreign-host 203.0.113.10 \
  --port 9999 \
  --key 'KEY-FROM-ABROAD' \
  --forward-mode selected \
  --ports 443,8443 \
  --protocol both \
  --yes
```

Iran, all TCP and UDP ports with exclusions:

```bash
sudo bash paqet-x-install.sh \
  --role iran \
  --foreign-host 203.0.113.10 \
  --port 9999 \
  --key 'KEY-FROM-ABROAD' \
  --all-ports \
  --exclude-ports 25,3306,5432 \
  --protocol both \
  --yes
```

### Complete uninstall

Choose menu option `3`, or run:

```bash
sudo bash paqet-x-install.sh --uninstall --yes
```

The uninstall removes Paqet X services, the optional transparent-proxy helper, recorded firewall and policy-routing rules, binaries, configuration, state, and the service account when it was created by the installer.

### Management commands

```bash
sudo paqetx status
sudo paqetx logs
sudo paqetx test
sudo paqetx restart
sudo paqetx start
sudo paqetx stop
sudo paqetx version
sudo paqetx config
sudo paqetx uninstall
```

### Integrity and requirements

Paqet and the optional transparent-proxy helper are downloaded only from their official GitHub releases. The installer validates the expected release URL and GitHub-published SHA-256 digest before installation.

Requirements:

- Linux with systemd
- root or sudo
- AMD64, ARM64, or ARMv7
- iptables and kernel TPROXY support for all-port mode
- authorized administrative access to both servers and their network

## Testing

```bash
bash -n paqet-x-install.sh
./tests/smoke.sh
./tests/integration.sh
shellcheck -x paqet-x-install.sh tests/smoke.sh tests/integration.sh
```

The integration test uses mocked release assets, network discovery, services, and tunnel health checks. A real deployment should still be tested on the target kernel, hosting provider firewall, and both actual servers.

## License

MIT — see [LICENSE](LICENSE).

# Paqet X

نصب‌کننده ساده و دوطرفه برای راه‌اندازی Paqet بین **سرور خارج** و **سرور ایران**، همراه با Port Forward انتخابی برای TCP، UDP یا هر دو.

[English documentation](#english)

> این پروژه نصب‌کننده‌ای مستقل برای هسته متن‌باز [`hanselime/paqet`](https://github.com/hanselime/paqet) است و ریپوی رسمی Paqet نیست. باینری فقط از Releaseهای رسمی upstream دانلود و با SHA-256 منتشرشده در GitHub بررسی می‌شود.

## فارسی

### روند دقیق نصب

```text
سرور خارج
  └─ نصب سرویس Paqet Server
  └─ تولید Key
  └─ نمایش نسخه Paqet + پورت تونل + Key

سرور ایران
  └─ دریافت IP/دامنه سرور خارج
  └─ دریافت پورت تونل خارج
  └─ دریافت Key ساخته‌شده روی خارج
  └─ دریافت پورت‌های Forward
  └─ انتخاب 1) TCP  2) UDP  3) هر دو
  └─ نصب سرویس Paqet Client و برقراری تونل
```

سمت خارج هیچ Port Forwardی تعریف نمی‌کند. تمام Forwardها فقط داخل کانفیگ سمت ایران ساخته می‌شوند.

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

### مرحله اول: سرور خارج

گزینه `1` را انتخاب کنید. نصب‌کننده فقط این کارها را انجام می‌دهد:

1. پورت تونل Paqet را می‌گیرد؛ مقدار پیشنهادی `9999` است.
2. Interface، IP محلی و MAC گیت‌وی را تشخیص می‌دهد.
3. یک Key تصادفی امن می‌سازد.
4. سرویس `paqet-x.service` را در نقش `server` نصب و اجرا می‌کند.
5. قوانین ضروری iptables برای پورت Raw TCP را ایجاد می‌کند.
6. نسخه Paqet، پورت تونل و Key را نمایش می‌دهد.

خروجی مهم شبیه این است:

```text
Paqet version: v1.0.0-alpha.20
Tunnel port: 9999
Shared key: 0123456789abcdef...
```

این سه مقدار را نگه دارید. برای نمایش دوباره آن‌ها:

```bash
sudo paqetx key
```

در Firewall یا Security Group ارائه‌دهنده سرور خارج، **TCP پورت تونل** را باز کنید. برای پورت تونل از `80` یا `443` استفاده نکنید.

### مرحله دوم: سرور ایران

گزینه `2` را انتخاب کنید. نصب‌کننده به‌ترتیب این اطلاعات را می‌گیرد:

1. IP عمومی یا دامنه سرور خارج
2. پورت تونل نمایش‌داده‌شده روی سرور خارج
3. Key نمایش‌داده‌شده روی سرور خارج
4. پورت‌های موردنظر برای Forward، با کاما؛ مانند:

```text
443,8443,2053
```

5. نوع پروتکل:

```text
1) فقط TCP
2) فقط UDP
3) TCP و UDP با هم
```

اگر پورت `443` و گزینه `3` انتخاب شود، دو Forward ساخته می‌شود:

```text
Iran 0.0.0.0:443/TCP  ->  Abroad 127.0.0.1:443/TCP
Iran 0.0.0.0:443/UDP  ->  Abroad 127.0.0.1:443/UDP
```

به‌صورت پیش‌فرض، پورت ورودی روی ایران و پورت مقصد روی خارج یکسان هستند. سرویس مقصد، مانند Xray یا sing-box، باید روی همان پورت در `127.0.0.1` سرور خارج در حال Listen باشد.

### حذف کامل

دوباره دستور نصب را اجرا و گزینه `3` را انتخاب کنید. این گزینه موارد زیر را حذف می‌کند:

- سرویس اصلی و سرویس Firewall
- قوانین iptables ساخته‌شده توسط پروژه
- باینری Paqet
- ابزار مدیریتی `paqetx`
- کانفیگ، State و فایل‌های systemd

حذف غیرتعاملی:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh \
  | sudo bash -s -- --uninstall --yes
```

### نصب غیرتعاملی

سرور خارج:

```bash
sudo bash paqet-x-install.sh \
  --role abroad \
  --port 9999 \
  --yes
```

سرور ایران با TCP و UDP برای پورت‌های 443 و 8443:

```bash
sudo bash paqet-x-install.sh \
  --role iran \
  --foreign-host 203.0.113.10 \
  --port 9999 \
  --key 'KEY-FROM-ABROAD' \
  --ports 443,8443 \
  --protocol both \
  --yes
```

حالت‌های معتبر `--protocol`:

```text
tcp
udp
both
```

برای نگاشت پیشرفته یک پورت محلی به پورت متفاوت روی خارج:

```bash
--forward 8443:443/tcp
```

### دستورات مدیریت

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

روی نقش خارج:

```bash
sudo paqetx key
```

### اجرای مجدد

اجرای مجدد با همان نقش، کانفیگ فعلی را حفظ می‌کند و فایل‌ها و سرویس‌ها را دوباره سالم‌سازی می‌کند. برای جایگزینی کانفیگ:

```bash
sudo bash paqet-x-install.sh --role iran --reconfigure
```

برای تغییر نقش، روش پیشنهادی این است که ابتدا گزینه حذف کامل را اجرا کنید و سپس نقش جدید را نصب کنید.

### نسخه و سازگاری

نصب‌کننده به‌صورت پیش‌فرض Paqet `v1.0.0-alpha.20` را روی هر دو سمت نصب می‌کند تا نسخه‌ها با هم یکسان بمانند. این Release تغییر پروتکلی ناسازگار با نسخه‌های قبلی دارد؛ بنابراین نسخه ایران و خارج باید دقیقاً یکسان باشد.

### نیازمندی‌ها

- Linux با systemd
- دسترسی root یا sudo
- معماری AMD64، ARM64 یا ARMv7
- دسترسی HTTPS به GitHub Releases
- دسترسی مدیریتی مجاز به سرورها و شبکه

### فایل‌های نصب‌شده

```text
/usr/local/bin/paqet
/usr/local/sbin/paqetx
/etc/paqet-x/config.yaml
/etc/paqet-x/install.env
/etc/paqet-x/firewall.env
/usr/local/lib/paqet-x/firewall.sh
/etc/systemd/system/paqet-x.service
/etc/systemd/system/paqet-x-firewall.service
/var/lib/paqet-x/version
```

کانفیگ شامل Key است و با مجوز `0600` نگهداری می‌شود.

---

## English

Paqet X is a guided two-server installer for an **Abroad Paqet server** and an **Iran Paqet client**, with selectable TCP, UDP, or dual-protocol port forwarding.

### Exact installation flow

```text
Abroad server
  └─ Install Paqet Server service
  └─ Generate a shared key
  └─ Print Paqet version + tunnel port + shared key

Iran server
  └─ Ask for Abroad host
  └─ Ask for Abroad tunnel port
  └─ Ask for the shared key
  └─ Ask for forwarding ports
  └─ Select 1) TCP  2) UDP  3) Both
  └─ Install Paqet Client and start the tunnel
```

No forwarding rules are configured in the Abroad Paqet configuration. All port forwards are created on the Iran client.

### One-command installer

Run the same command on both machines:

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

### Abroad installation

Choose option `1`. The installer:

1. Asks for the Paqet tunnel port, defaulting to `9999`.
2. Detects the interface, local IPv4 address, and gateway MAC.
3. Generates a cryptographically random shared key.
4. Installs and starts Paqet in the official `server` role.
5. Adds the required raw-table and TCP RST iptables rules.
6. Prints the Paqet version, tunnel port, and shared key.

Show the values again later:

```bash
sudo paqetx key
```

Allow inbound TCP on the tunnel port in the Abroad provider firewall or security group. Do not use port `80` or `443` as the Paqet tunnel port.

### Iran installation

Choose option `2`. The installer asks for:

1. The Abroad public IP address or DNS name
2. The Abroad tunnel port
3. The shared key printed by the Abroad installation
4. A comma-separated list of forwarding ports, such as `443,8443,2053`
5. One forwarding protocol mode:

```text
1) TCP only
2) UDP only
3) TCP and UDP
```

Selecting port `443` and mode `3` creates:

```text
Iran 0.0.0.0:443/TCP  ->  Abroad 127.0.0.1:443/TCP
Iran 0.0.0.0:443/UDP  ->  Abroad 127.0.0.1:443/UDP
```

By default, the Iran listen port and Abroad target port are identical. The target service must be listening on that port at `127.0.0.1` on the Abroad server.

### Complete uninstall

Run the installer again and choose option `3`, or use:

```bash
curl -fsSL https://raw.githubusercontent.com/Unknown-sir/paqetX/main/paqet-x-install.sh \
  | sudo bash -s -- --uninstall --yes
```

The uninstall removes the services, project firewall rules, binary, manager, configuration, state, and systemd files.

### Non-interactive examples

Abroad:

```bash
sudo bash paqet-x-install.sh --role abroad --port 9999 --yes
```

Iran with TCP and UDP forwarding for ports 443 and 8443:

```bash
sudo bash paqet-x-install.sh \
  --role iran \
  --foreign-host 203.0.113.10 \
  --port 9999 \
  --key 'KEY-FROM-ABROAD' \
  --ports 443,8443 \
  --protocol both \
  --yes
```

Advanced different-port mapping:

```bash
--forward 8443:443/tcp
```

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

On the Abroad role:

```bash
sudo paqetx key
```

### Version compatibility

The installer pins Paqet `v1.0.0-alpha.20` by default so both sides receive the same protocol version. This upstream release is not wire-compatible with older releases.

### Safety and integrity

- Downloads are restricted to official `hanselime/paqet` GitHub Release URLs.
- The archive must match GitHub's published SHA-256 asset digest.
- Archive paths and entry types are checked before extraction.
- Configuration and keys are root-readable only.
- Installation is atomic and safe to rerun.
- Use the project only on systems and networks you are authorized to administer.

## License

The installer is released under the MIT License. Paqet itself is provided by its upstream project under its own license.

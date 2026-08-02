# Contributing

Contributions should keep the installer auditable, idempotent, and compatible with the current official `hanselime/paqet` configuration format.

Before opening a pull request:

```bash
bash -n paqet-x-install.sh
tests/smoke.sh
tests/integration.sh
shellcheck -x paqet-x-install.sh tests/smoke.sh tests/integration.sh
```

Please update both Persian and English README sections when changing user-facing behavior. Never commit real `paqetx://` tokens, shared keys, server addresses, generated configurations, or logs containing private data.

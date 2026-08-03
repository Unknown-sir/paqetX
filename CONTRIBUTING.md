# Contributing

1. Do not replace `Paqet-Xv2` without documenting provenance and updating every pinned checksum.
2. Keep installer changes idempotent and safe to rerun.
3. Preserve SSH and tunnel-port bypass rules in All Ports mode.
4. Run before submitting changes:

```bash
bash -n install.sh
bash tests/test.sh
shellcheck -x -S error install.sh tests/test.sh
```

5. Never add real server addresses, keys, passwords or production configurations to the repository.

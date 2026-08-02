# Contributing

Contributions that improve reliability, portability, documentation, and security are welcome.

1. Fork the repository and create a focused branch.
2. Keep the installer compatible with Bash and systemd-based Linux systems.
3. Run the local checks before opening a pull request:

   ```bash
   bash -n paqet-x-install.sh
   shellcheck -x paqet-x-install.sh tests/smoke.sh
   tests/smoke.sh
   ```

4. Do not add opaque download sources, embedded binaries, telemetry, secrets, or unrelated software.
5. Explain behavior changes and update `README.md` and `CHANGELOG.md` when needed.

Pull requests should be small enough to review safely and should include reproduction or test details.

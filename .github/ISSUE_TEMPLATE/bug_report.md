---
name: Bug report
about: Something does not work as described
labels: bug
---

**What happened**

**What you expected**

**Environment**
- Omarchy version (`omarchy version`):
- Plugin version (`agent-acct version`):
- CLI and version (e.g. `codex --version`):

**Diagnostics** (redact emails; never paste credential files)

```
$ agent-acct setup --status

$ agent-acct tools --all

$ agent-acct status
```

**Shell log** (optional): `journalctl --user -u omarchy-shell --since "10 min ago" | grep -i multi-account`

# Security

This plugin reads credential files only to decide whether an account is
signed in and to show its email and plan. It never prints, copies, logs or
transmits tokens, makes no network requests of its own, and needs no sudo.

If you believe you have found a way it could leak a credential, execute
untrusted input, or modify files it should not, please **do not open a public
issue**. Use GitHub's private vulnerability reporting on this repository
("Security" tab → "Report a vulnerability"), or email the maintainer address
on the GitHub profile. You will get an acknowledgement within a few days and
a fix or an explanation before anything is published.

Things that are *by design* and not vulnerabilities:

- Tool definitions under `~/.config/agent-accounts/tools/` run the `login`,
  `logout` and `emailCommand` commands they declare; they are yours to trust.
- `agent-acct setup` edits `~/.bashrc` and installs a `systemd --user`
  timer, at your explicit request, and `setup --remove` undoes it.

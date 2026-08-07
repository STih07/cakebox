# Security

Cakebox is a prototype. Please do not use it for sensitive production workloads yet.

## Reporting

If you find a security issue, please open a private report through GitHub Security Advisories when available, or contact the maintainer directly.

Please avoid posting exploit details in public issues before there is time to respond.

## Current Security Notes

- AI provider keys are read from environment variables.
- Runtime SQLite traces may contain chat text and tool payloads.
- The demo stores traces locally under `var/`, which is ignored by git.
- The browser applies server-emitted UI actions, so tool contracts should stay explicit and narrow.


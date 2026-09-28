# Security and disclosure policy

This repository intentionally contains no credentials, production configuration, private infrastructure details, or production data.

If sensitive information is ever committed:

1. remove it from the public branch immediately;
2. rotate or revoke the exposed credential or key at its source;
3. remove the secret from Git history where appropriate;
4. treat scanners as defense in depth, not proof that a repository is safe.

Do not submit real connection strings, hostnames, IP addresses, database identifiers, user identifiers, environment dumps, or private logs in issues, pull requests, benchmark fixtures, or workflow output.

#!/usr/bin/env python3
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]

FORBIDDEN_NAMES = (
    re.compile(r"(^|/)\.env(?:\.|$)", re.I),
    re.compile(r"\.(?:pem|key|p12|pfx|sqlite3?|db|dump)$", re.I),
)

PATTERNS = (
    ("private-key", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
    ("credential-assignment", re.compile(
        r"(?i)\b(?:password|passwd|pwd|secret|api[_-]?key|access[_-]?token|auth[_-]?token)"
        r"\b\s*[:=]\s*[\"'][^\"'\n]{4,}[\"']")),
    ("database-dsn", re.compile(
        r"(?i)\b(?:mysql|postgres(?:ql)?|mariadb|mongodb|redis|starrocks)://[^\s]+")),
    ("ipv4-address", re.compile(
        r"(?<![0-9])(?:25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})"
        r"(?:\.(?:25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})){3}(?![0-9])")),
    ("ssh-target", re.compile(r"(?i)\bssh\s+(?:[^\s@]+@)?[^\s]+")),
)

CONTENT_EXEMPT = {
    "PUBLIC_REPO_POLICY.md",
    "SECURITY.md",
    "scripts/check_public_repo.py",
}

def tracked_files():
    out = subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "-z"])
    return [p.decode() for p in out.split(b"\0") if p]

def main():
    failures = []
    for rel in tracked_files():
        for rx in FORBIDDEN_NAMES:
            if rx.search(rel):
                failures.append((rel, "forbidden-filename", rel))
        if rel in CONTENT_EXEMPT:
            continue
        path = ROOT / rel
        try:
            data = path.read_bytes()
        except OSError:
            continue
        if b"\0" in data[:8192]:
            continue
        text = data.decode("utf-8", "replace")
        for label, rx in PATTERNS:
            m = rx.search(text)
            if m:
                excerpt = m.group(0)
                if len(excerpt) > 120:
                    excerpt = excerpt[:117] + "..."
                failures.append((rel, label, excerpt))
    if failures:
        for rel, label, excerpt in failures:
            print(f"PUBLIC_REPO_SCAN_FAIL file={rel} rule={label} match={excerpt!r}")
        return 1
    print("PUBLIC_REPO_SCAN_PASS")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

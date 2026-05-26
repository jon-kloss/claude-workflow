#!/usr/bin/env python3
"""
Detect secret-shaped strings in agent-memory content.

Called by hooks/guard-agent-memory-secrets.sh with the proposed new_content
on stdin. Prints one finding per line (label + redacted preview); empty
stdout = no findings.

Exit code is always 0 — the calling hook reads stdout.
"""
import sys
import re

content = sys.stdin.read()

# Patterns are intentionally tight to keep false positives low. Each pair is
# (regex, human-readable label).
PATTERNS = [
    # JWT-like tokens (eyJ... format). Catches Bearer tokens, Auth.js sessions, GitHub PATs in JWT form.
    (r"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b",
     "JWT-shaped token (eyJ...header.payload.signature)"),
    # AWS access keys
    (r"\bAKIA[0-9A-Z]{16}\b", "AWS Access Key ID (AKIA prefix)"),
    (r"\bASIA[0-9A-Z]{16}\b", "AWS STS Access Key ID (ASIA prefix)"),
    # Stripe live keys
    (r"\bsk_live_[A-Za-z0-9]{20,}\b", "Stripe live secret key (sk_live_)"),
    (r"\brk_live_[A-Za-z0-9]{20,}\b", "Stripe live restricted key (rk_live_)"),
    # GitHub PAT (new format)
    (r"\bghp_[A-Za-z0-9]{36}\b", "GitHub Personal Access Token (ghp_)"),
    (r"\bghs_[A-Za-z0-9]{36}\b", "GitHub Server-to-Server Token (ghs_)"),
    (r"\bghu_[A-Za-z0-9]{36}\b", "GitHub User-to-Server Token (ghu_)"),
    # GitLab PAT
    (r"\bglpat-[A-Za-z0-9_-]{20,}\b", "GitLab Personal Access Token (glpat-)"),
    # Slack tokens
    (r"\bxox[bpoars]-[0-9A-Za-z-]{10,}\b", "Slack token (xox*-)"),
    # OpenAI keys (sk- but not sk-ant-)
    (r"\bsk-(?!ant-)[A-Za-z0-9]{32,}\b", "OpenAI-style API key (sk-...)"),
    # Anthropic keys
    (r"\bsk-ant-[A-Za-z0-9_-]{32,}\b", "Anthropic API key (sk-ant-...)"),
    # Generic high-entropy hex/base64 strings labeled as secret/token/key
    (r"(?im)(?:secret|token|key|password|passwd|api[_-]?key)\s*[:=]\s*[\"']?([a-fA-F0-9]{32,}|[A-Za-z0-9+/=]{40,})[\"']?",
     "labeled secret/token/key with high-entropy value"),
    # PEM private keys
    (r"-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY-----",
     "PEM private key block"),
    # SSH private key labels
    (r"\bssh-(?:rsa|ed25519|dss|ecdsa)\s+[A-Za-z0-9+/=]{100,}", "SSH key material"),
    # bcrypt hashes
    (r"\$2[abxy]\$\d{2}\$[./A-Za-z0-9]{53}", "bcrypt hash"),
    # Database connection strings with embedded credentials
    (r"(?im)(?:postgres|postgresql|mysql|mariadb|mongodb|redis)://[^:\s]+:[^@\s]{6,}@",
     "database URL with embedded credentials"),
]


def redact(matched: str) -> str:
    if len(matched) > 24:
        return matched[:8] + "..." + matched[-4:]
    return matched[:4] + "..."


def find_secrets(text: str) -> list[str]:
    findings: list[str] = []
    seen: set[str] = set()
    for pattern, label in PATTERNS:
        for match in re.finditer(pattern, text):
            entry = f"{label}: {redact(match.group(0))}"
            if entry not in seen:
                seen.add(entry)
                findings.append(entry)
    return findings


if __name__ == "__main__":
    for finding in find_secrets(content):
        print(finding)

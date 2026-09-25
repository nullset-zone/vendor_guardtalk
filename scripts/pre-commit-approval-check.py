#!/usr/bin/env python3
"""AEGIS pre-commit approval gate (GuardTalk / GrapheneOS workspace).

Enforces the ``AGENTS.md`` "Git Rule":

    Engineers may NOT ``git commit`` or ``git push`` until the Architect marks
    their task as ``APPROVED`` in ``TASK_QUEUE.md``.

Which commits are checked
-------------------------
The task id(s) a commit claims to implement are resolved, in priority order, from:

1. ``AEGIS_TASK_ID`` — explicit, authoritative, comma/space separated, e.g.
   ``AEGIS_TASK_ID=T-EXAMPLE-001 git commit -m "..."``. If it is set it must
   name a real card, and that card must be ``APPROVED``.
2. A ``Task: <ID>`` trailer in the commit message file ``$GIT_DIR/COMMIT_EDITMSG``
   (best effort — see the caveat below).
3. Task ids that literally appear in the **staged diff** *and* resolve to a real
   card in the authoritative queue. Tokens that do not resolve to a card are
   ignored so prose, examples and regex literals cannot cause a false block.

Every resolved task id that is not marked ``APPROVED`` blocks the commit
(exit code 1, git aborts the commit).

Caveat on the commit message
----------------------------
Git runs ``pre-commit`` **before** it writes ``COMMIT_EDITMSG``, so for the
common ``git commit -m "..."`` form the message is not yet on disk. The message
channel is therefore best effort and guarded against staleness (a message file
older than the index is ignored). The reliable channel is ``AEGIS_TASK_ID``.

FAIL-CLOSED default (Operator ruling 2026-09-25)
-----------------------------------------------
Every commit **must** name a task that is ``APPROVED`` in the authoritative
``TASK_QUEUE.md``. There is no silent skip:

* **No task id can be resolved -> FAIL CLOSED** (exit 1, with instructions to set
  ``AEGIS_TASK_ID=<TASK-ID>``). The earlier fail-open behaviour was ruled
  unacceptable by the Human Operator: an un-attributed commit is exactly the
  change this gate exists to stop.
* **A task id is resolved but the authoritative queue cannot be read -> FAIL
  CLOSED** (exit 1). An explicit claim that cannot be verified must not be
  silently trusted (cf. Law 7).
* **A resolved task is missing or not APPROVED -> FAIL CLOSED** (exit 1).

Bypass (deliberate, loud, human-only)
-------------------------------------
``AEGIS_SKIP_APPROVAL_CHECK=1`` allows the commit, but prints an explicit banner
stating that the APPROVED gate was bypassed. Human Authority (Law 0) permits a
human to override the gate — it does **not** permit a silent override.

Exit codes: 0 = allow, 1 = block (refuse).
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

BYPASS_ENV = "AEGIS_SKIP_APPROVAL_CHECK"
TASK_ID_ENV = "AEGIS_TASK_ID"
QUEUE_ENV = "AEGIS_TASK_QUEUE"

# `T-`/`Q-`/`M-`/`P-`/`F-` prefixes are the documented AEGIS task prefixes.
TASK_ID_RE = re.compile(r"\b(?:T|Q|M|P|F)-[A-Za-z0-9][A-Za-z0-9_-]*")
TASK_TRAILER_RE = re.compile(
    r"\bTask:\s*((?:T|Q|M|P|F)-[A-Za-z0-9][A-Za-z0-9_-]*)", re.IGNORECASE
)
CARD_HEADER_RE = re.compile(
    r"^#{2,6}\s+(?P<id>(?:T|Q|M|P|F)-[A-Za-z0-9][A-Za-z0-9_-]*)\b"
)
STATUS_RE = re.compile(r"\*\*Status:?\*?\*?\s*(?P<rest>[^\n]*)")


def _run_git(*args: str) -> str:
    """Run a git command, returning stdout or "" on any failure."""
    try:
        result = subprocess.run(
            ["git", *args], capture_output=True, text=True, check=True
        )
        return result.stdout
    except (subprocess.CalledProcessError, FileNotFoundError, OSError):
        return ""


def git_toplevel() -> Path:
    """Return the git work-tree root (falls back to cwd)."""
    out = _run_git("rev-parse", "--show-toplevel").strip()
    return Path(out) if out else Path.cwd()


def git_dir() -> Path | None:
    """Return the absolute git directory, or None if not in a repo."""
    out = _run_git("rev-parse", "--absolute-git-dir").strip()
    return Path(out) if out else None


def get_staged_text() -> str:
    """Return the staged diff (context-free) used for heuristic task-id scan."""
    return _run_git("diff", "--cached", "-U0")


def locate_task_queue(repo_root: Path) -> Path | None:
    """Locate the authoritative TASK_QUEUE.md.

    Resolution order: ``AEGIS_TASK_QUEUE`` override, then the workspace root
    relative to this script (``<root>/scripts/pre-commit-approval-check.py``),
    then a walk up from the git toplevel.
    """
    override = os.environ.get(QUEUE_ENV)
    if override:
        candidate = Path(override)
        return candidate if candidate.is_file() else None

    here = Path(__file__).resolve().parent.parent / "TASK_QUEUE.md"
    if here.is_file():
        return here

    for base in (repo_root, *repo_root.parents):
        candidate = base / "TASK_QUEUE.md"
        if candidate.is_file():
            return candidate
    return None


def normalize_status(raw: str) -> str:
    """Normalize a raw status-line remainder into a bare status keyword."""
    text = raw.split("**", 1)[0]  # drop the closing bold marker and any tail
    text = text.strip().lstrip("\u2705\u2714\ufe0f ").strip()
    return text.strip("`* \t")


def parse_statuses(queue_path: Path) -> dict[str, str]:
    """Return ``{task_id: status}`` parsed from the authoritative queue.

    A card's status is the first ``**Status: ...`` line following its heading.
    """
    statuses: dict[str, str] = {}
    current: str | None = None
    content = queue_path.read_text(encoding="utf-8", errors="ignore")
    for line in content.splitlines():
        header = CARD_HEADER_RE.match(line)
        if header:
            current = header.group("id")
            statuses.setdefault(current, "")
            continue
        if current is None or statuses.get(current):
            continue
        match = STATUS_RE.search(line)
        if match:
            statuses[current] = normalize_status(match.group("rest"))
    return statuses


def is_approved(status: str) -> bool:
    """True only when the status keyword is APPROVED (not e.g. 'BLOCKED ... APPROVED')."""
    return bool(re.match(r"APPROVED\b", status.upper()))


def env_task_ids() -> tuple[list[str], bool]:
    """Return ``(ids, malformed)`` for the AEGIS_TASK_ID declaration."""
    raw = os.environ.get(TASK_ID_ENV, "").strip()
    if not raw:
        return [], False
    ids = TASK_ID_RE.findall(raw)
    return list(dict.fromkeys(ids)), not ids


def message_task_ids(gitdir: Path | None) -> list[str]:
    """Best-effort task ids from a fresh ``Task:`` trailer in COMMIT_EDITMSG."""
    if gitdir is None:
        return []
    msg = gitdir / "COMMIT_EDITMSG"
    index = gitdir / "index"
    try:
        if not msg.is_file():
            return []
        if index.is_file() and msg.stat().st_mtime < index.stat().st_mtime:
            return []  # stale message from a previous commit
        text = msg.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return []
    return list(dict.fromkeys(TASK_TRAILER_RE.findall(text)))


def content_task_ids(staged_text: str, known: set[str]) -> list[str]:
    """Task ids in the staged diff that resolve to a real card."""
    found = []
    for tid in TASK_ID_RE.findall(staged_text):
        if tid in known and tid not in found:
            found.append(tid)
    return found


def _print_block(
    queue_path: Path | None,
    unknown: list[str],
    unapproved: list[str],
    statuses: dict[str, str],
) -> None:
    print()
    print("=" * 70)
    print("  AEGIS GOVERNANCE: COMMIT BLOCKED - Unapproved Work Detected")
    print("=" * 70)
    if queue_path is not None:
        print(f"  Authority queue: {queue_path}")
    for tid in unknown:
        print(f"    {tid}: NOT FOUND in the authoritative TASK_QUEUE.md")
    for tid in unapproved:
        print(f"    {tid}: {statuses.get(tid) or 'UNKNOWN'}")
    print()
    print("  RULE: Engineers may NOT commit or push until the Architect")
    print("        marks the task as APPROVED in TASK_QUEUE.md.")
    print()
    print("  Declare the task at commit time with AEGIS_TASK_ID=<TASK-ID>.")
    print("  To bypass (Architect only): AEGIS_SKIP_APPROVAL_CHECK=1")
    print("=" * 70)
    print()


def _print_no_task_id_block() -> None:
    print()
    print("=" * 70)
    print("  AEGIS GOVERNANCE: COMMIT BLOCKED - No Task Id Declared")
    print("=" * 70)
    print()
    print("  FAIL-CLOSED: every commit must name a task that is APPROVED in")
    print("  the authoritative TASK_QUEUE.md. No task id could be resolved")
    print("  from AEGIS_TASK_ID, the commit message, or the staged diff.")
    print()
    print("  Declare it at commit time, e.g.:")
    print(f"    {TASK_ID_ENV}=<TASK-ID> git commit -m \"...\"")
    print()
    print("  RULE: Engineers may NOT commit or push until the Architect")
    print("        marks the task as APPROVED in TASK_QUEUE.md.")
    print()
    print("  To bypass (Architect only): AEGIS_SKIP_APPROVAL_CHECK=1")
    print("=" * 70)
    print()


def _print_bypass_banner() -> None:
    print()
    print("=" * 70)
    print("  AEGIS GOVERNANCE: APPROVAL GATE BYPASSED")
    print(f"  ({BYPASS_ENV}=1)")
    print("=" * 70)
    print("  WHAT WAS BYPASSED: the check that every resolved task id is")
    print("  APPROVED in the authoritative TASK_QUEUE.md. This commit will")
    print("  proceed WITHOUT proving Architect approval.")
    print("  Human Authority (Law 0) permits an explicit override, but never")
    print("  a silent one. This bypass is recorded loudly by design.")
    print("=" * 70)
    print()


def main() -> int:
    """Pre-commit entry point. Returns 0 to allow, 1 to block."""
    if os.environ.get(BYPASS_ENV) == "1":
        _print_bypass_banner()
        return 0

    repo_root = git_toplevel()
    repo_git_dir = git_dir()
    queue_path = locate_task_queue(repo_root)
    statuses = parse_statuses(queue_path) if queue_path else {}

    env_ids, malformed_env = env_task_ids()
    if malformed_env:
        print(
            f"[AEGIS] {TASK_ID_ENV} is set but contains no valid task id "
            f"(expected e.g. T-EXAMPLE-001); refusing commit."
        )
        return 1

    declared = list(dict.fromkeys(env_ids + message_task_ids(repo_git_dir)))
    heuristic = content_task_ids(get_staged_text(), set(statuses))
    resolved = list(dict.fromkeys(declared + heuristic))

    if not resolved:
        _print_no_task_id_block()
        return 1

    if queue_path is None:
        print(
            "[AEGIS] Task id(s) declared but the authoritative TASK_QUEUE.md "
            "could not be read; refusing commit (fail-closed)."
        )
        return 1

    unknown = [tid for tid in resolved if tid not in statuses]
    unapproved = [
        tid for tid in resolved if tid in statuses and not is_approved(statuses[tid])
    ]

    if unknown or unapproved:
        _print_block(queue_path, unknown, unapproved, statuses)
        return 1

    print(f"[AEGIS] Approval check passed - APPROVED: {', '.join(resolved)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

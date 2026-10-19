#!/usr/bin/env python3
"""AEGIS push-side / CI-side approval backstop (GuardTalk / GrapheneOS workspace).

``T-EXCISE-COMMITGATE-PUSH-BACKSTOP``.

WHY THIS EXISTS
---------------
The client-side ``pre-commit`` hook (``pre-commit-approval-check.py``) cannot
close the "un-attributed commit" class. Proven, reproducible git properties:

    $ git commit --no-verify -m "..."            # rc=0, no id, no banner
    $ git -c core.hooksPath=/dev/null commit ... # rc=0, no id, no banner
    $ git push                                   # ungated

A hook the committer can skip is not a control over that committer. This script
is the *push-side* half: it re-runs the approval gate over the **pushed range**
(``<old>..<new>``) and refuses the push unless **every** pushed commit carries a
durable, in-band task declaration that resolves to a card marked ``APPROVED`` in
the **authoritative** workspace-root ``TASK_QUEUE.md``.

DURABLE TASK DECLARATION (push-time channel)
--------------------------------------------
``AEGIS_TASK_ID`` is a *client-side* convenience: it is not stored in the commit
object, so it is invisible to a server/CI that only sees the pushed commits. The
only channel a push-side gate can read is the **commit message**, so a commit
that must survive the backstop has to carry the same ``Task: <ID>`` trailer the
pre-commit checker already understands::

    git commit -m "do the thing

    Task: T-EXAMPLE-001"

A ``--no-verify`` commit that declares nothing therefore has *no* id at push
time and is refused here — which is exactly the negative control this backstop
exists for.

AUTHORITY (``T-EXCISE-COMMITGATE-QUEUE-OVERRIDE`` consistency)
--------------------------------------------------------------
The authoritative queue is the workspace-root ``TASK_QUEUE.md`` (resolved
relative to the sibling checker, then by walking up from the git toplevel, or
given explicitly by the *host* via ``--authoritative-queue``).

``AEGIS_TASK_QUEUE`` may point the gate at a different file, but a
**non-authoritative** queue is always **refused** here: at push/CI time there is
no human at the console to "loudly acknowledge" a substitution, and the whole
point of a backstop is that the actor being bound does not get to choose the
rulebook. There is **no ACK escape hatch** on the push side. This is the
deliberate difference from the pre-commit checker (which allows a loudly
acknowledged substitution for a human operator sitting at the terminal).

``AEGIS_SKIP_APPROVAL_CHECK`` (the client bypass) is **ignored** here, on
purpose and loudly. A client-controlled skip flag must never gate the server.

FAIL-CLOSED
-----------
* authoritative queue missing/unreadable                -> REFUSE (exit 1)
* ``AEGIS_TASK_QUEUE`` names a non-authoritative queue  -> REFUSE (exit 1)
* git/rev-list failure (cannot enumerate the range)     -> REFUSE (exit 1)
* sibling checker (status parser) cannot be loaded      -> REFUSE (exit 1)
* pushed commit with no ``Task: <ID>`` trailer          -> REFUSE (exit 1)
* pushed commit naming a card not APPROVED / unknown    -> REFUSE (exit 1)

Exit codes: 0 = allow (push may proceed), 1 = refuse (block the push).

Reuse
-----
Status parsing, task-id regexes and authoritative-queue resolution are **not**
re-implemented here: they are imported from the versioned sibling
``pre-commit-approval-check.py`` so there is exactly one source of truth for the
approval rule (``AGENTS.md`` "Git Rule").
"""

from __future__ import annotations

import argparse
import importlib.util
import os
import subprocess
import sys
from pathlib import Path

ZERO_RE = "0" * 40  # SHA-1 zero id (git also uses 64 for SHA-256 repos)

# NOTE: AEGIS_TASK_ID is intentionally NOT an authorisation channel here.
CLIENT_BYPASS_ENV = "AEGIS_SKIP_APPROVAL_CHECK"


class GateError(RuntimeError):
    """A fail-closed condition: refuse the push rather than allow it."""


# ---------------------------------------------------------------------------
# sibling checker (single source of truth for the approval rule)
# ---------------------------------------------------------------------------
def load_checker():
    """Import the versioned sibling pre-commit checker module.

    Fail-closed: if the checker cannot be loaded we cannot apply the approval
    rule at all, so we must not pretend the push is fine.
    """
    here = Path(__file__).resolve().parent
    candidate = here / "pre-commit-approval-check.py"
    if not candidate.is_file():
        raise GateError(
            f"sibling checker not found at {candidate}; cannot apply the "
            "approval rule (fail-closed)."
        )
    spec = importlib.util.spec_from_file_location("_aegis_pre_commit_checker", candidate)
    if spec is None or spec.loader is None:
        raise GateError(f"sibling checker at {candidate} is not importable (fail-closed).")
    module = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(module)
    except Exception as exc:  # noqa: BLE001 - any load failure is fail-closed
        raise GateError(f"sibling checker at {candidate} failed to load: {exc}") from exc
    return module


# ---------------------------------------------------------------------------
# git plumbing
# ---------------------------------------------------------------------------
def _git(args: list[str], repo: str | None = None) -> tuple[int, str, str]:
    cmd = ["git"]
    if repo:
        cmd += ["-C", repo]
    cmd += args
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True)
    except (FileNotFoundError, OSError) as exc:
        raise GateError(f"cannot run git ({exc}); refusing (fail-closed).") from exc
    return proc.returncode, proc.stdout, proc.stderr


def _git_or_fail(args: list[str], repo: str | None, what: str) -> str:
    rc, out, err = _git(args, repo)
    if rc != 0:
        raise GateError(
            f"git {' '.join(args)} failed while {what} (rc={rc}): "
            f"{err.strip() or out.strip() or 'no output'}"
        )
    return out


def _is_zero(ref: str) -> bool:
    return bool(ref) and set(ref) == {"0"}


def commits_for_push(old: str, new: str, repo: str | None,
                     base_ref: str | None = None) -> list[str]:
    """Return the commit shas a single ref update introduces.

    * ref deletion (``new`` all-zero)         -> [] (nothing to approve)
    * new branch  (``old`` all-zero)          -> ``rev-list <new> --not --all``
                                                 (server-side pre-push state);
                                                 or ``--not <base_ref>`` in CI,
                                                 where ``--all`` would already
                                                 contain the pushed ref.
    * normal update (``old``..``new``)        -> ``rev-list <old>..<new>``
    """
    if _is_zero(new):
        return []
    if _is_zero(old):
        if base_ref:
            out = _git_or_fail(
                ["rev-list", new, "--not", base_ref], repo,
                f"enumerating commits introduced by new ref {new[:12]} vs {base_ref}",
            )
        else:
            out = _git_or_fail(
                ["rev-list", new, "--not", "--all"], repo,
                f"enumerating commits introduced by new ref {new[:12]}",
            )
    else:
        out = _git_or_fail(
            ["rev-list", f"{old}..{new}"], repo,
            f"enumerating pushed range {old[:12]}..{new[:12]}",
        )
    return [line.strip() for line in out.splitlines() if line.strip()]


def commit_message(sha: str, repo: str | None) -> str:
    return _git_or_fail(
        ["log", "-1", "--format=%B", sha], repo,
        f"reading the message of commit {sha[:12]}",
    )


def resolve_repo_root(repo: str | None) -> Path:
    """Best-effort repository root, used only for queue walk-up fallback.

    A ``pre-receive`` hook runs inside a *bare* repository, where
    ``rev-parse --show-toplevel`` fails; that is expected and not an error.
    Falls back to the git dir, then the current directory.
    """
    rc, out, _err = _git(["rev-parse", "--show-toplevel"], repo)
    if rc == 0 and out.strip():
        return Path(out.strip())
    rc, out, _err = _git(["rev-parse", "--absolute-git-dir"], repo)
    if rc == 0 and out.strip():
        return Path(out.strip())
    return Path(repo) if repo else Path.cwd()


# ---------------------------------------------------------------------------
# authority
# ---------------------------------------------------------------------------
def resolve_authoritative_queue(checker, repo_root: Path, explicit: str | None) -> Path:
    """Resolve the authoritative queue, refusing a substituted override.

    The host may name the authoritative queue explicitly (``--authoritative-queue``)
    — that is *server configuration*, not something the pushing committer sets.
    Otherwise we fall back to the sibling checker's own resolution.
    """
    override_raw = os.environ.get(checker.QUEUE_ENV, "").strip()

    if explicit:
        path = Path(explicit)
        if not path.is_file():
            raise GateError(
                f"--authoritative-queue {explicit} is not a readable file (fail-closed)."
            )
    else:
        resolved = checker.authoritative_task_queue(repo_root)
        if resolved is None:
            raise GateError(
                "the authoritative workspace-root TASK_QUEUE.md could not be located "
                "(fail-closed). Provide it to the host with --authoritative-queue."
            )
        path = resolved

    if override_raw:
        candidate = Path(override_raw)
        same = candidate.is_file() and checker._same_file(candidate, path)
        if not same:
            raise GateError(
                f"{checker.QUEUE_ENV} points at a queue that is NOT the authoritative "
                f"TASK_QUEUE.md (override: {candidate}; authoritative: {path}). "
                "Approval resolved from a substituted queue is fail-open, and a "
                "push-side gate has no human at the console to acknowledge it. "
                "Refusing (no ACK escape hatch on the push side)."
            )
    return path


# ---------------------------------------------------------------------------
# checks
# ---------------------------------------------------------------------------
def check_commits(checker, statuses: dict[str, str], shas: list[str], repo: str | None):
    """Return a list of violation dicts for commits lacking a valid approval."""
    violations: list[dict] = []
    for sha in shas:
        message = commit_message(sha, repo)
        declared = list(dict.fromkeys(checker.TASK_TRAILER_RE.findall(message)))
        if not declared:
            violations.append({
                "sha": sha,
                "kind": "NO_TASK_ID",
                "ids": [],
                "detail": ("no 'Task: <ID>' trailer in the commit message "
                           "(a --no-verify / core.hooksPath=/dev/null commit "
                           "leaves no durable task declaration)"),
            })
            continue
        for tid in declared:
            if tid not in statuses:
                violations.append({
                    "sha": sha, "kind": "UNKNOWN", "ids": [tid],
                    "detail": "NOT FOUND in the authoritative TASK_QUEUE.md",
                })
            elif not checker.is_approved(statuses[tid]):
                violations.append({
                    "sha": sha, "kind": "UNAPPROVED", "ids": [tid],
                    "detail": f"status is {statuses[tid] or 'UNKNOWN'} (not APPROVED)",
                })
    return violations


def _print_violations(queue_path: Path, violations: list[dict]) -> None:
    print()
    print("=" * 70)
    print("  AEGIS GOVERNANCE: PUSH BLOCKED - Unapproved Work Detected")
    print("=" * 70)
    print(f"  Authority queue: {queue_path}")
    print(f"  Pushed commits refused: {len(violations)}")
    for v in violations:
        ids = ", ".join(v["ids"]) if v["ids"] else "(none declared)"
        print(f"    {v['sha'][:12]}  [{v['kind']}] {ids}: {v['detail']}")
    print()
    print("  RULE: every pushed commit must declare 'Task: <ID>' naming a task")
    print("        APPROVED in the authoritative workspace-root TASK_QUEUE.md.")
    print("        A client-side pre-commit hook cannot be trusted for this:")
    print("        --no-verify / core.hooksPath=/dev/null skip it entirely.")
    print("=" * 70)
    print()


# ---------------------------------------------------------------------------
# entry point
# ---------------------------------------------------------------------------
def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="pre-receive-approval-check.py",
        description=(
            "AEGIS push-side/CI-side approval backstop: re-run the approval gate "
            "over a pushed range against the authoritative root TASK_QUEUE.md."
        ),
    )
    p.add_argument(
        "--authoritative-queue", default=None,
        help=("host-configured path to the authoritative TASK_QUEUE.md. Server "
              "configuration, never a committer-supplied value."),
    )
    p.add_argument(
        "--range", dest="rev_range", default=None,
        help="CI mode: a rev range '<base>..<head>'. If omitted, pre-receive ref lines are read from stdin.",
    )
    p.add_argument(
        "--repo", default=None,
        help="run git against this repository (default: the current directory).",
    )
    p.add_argument(
        "--base-ref", default=None,
        help=("CI only: ref to exclude when the pushed base is all-zero (a new "
              "branch push). Prevents a vacuous pass where '--not --all' already "
              "contains the pushed ref in a CI checkout."),
    )
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    if os.environ.get(CLIENT_BYPASS_ENV) == "1":
        print()
        print("=" * 70)
        print("  AEGIS GOVERNANCE: CLIENT BYPASS IGNORED")
        print(f"  ({CLIENT_BYPASS_ENV}=1)")
        print("=" * 70)
        print("  This is a push-side/CI-side backstop. The client bypass flag is")
        print("  deliberately ignored: a flag the committer controls must never")
        print("  gate the server.")
        print("=" * 70)
        print()

    try:
        checker = load_checker()
        repo_root = resolve_repo_root(args.repo)
        queue_path = resolve_authoritative_queue(checker, repo_root, args.authoritative_queue)
        statuses = checker.parse_statuses(queue_path)
        if not statuses:
            raise GateError(
                f"the authoritative queue {queue_path} parsed to zero cards (fail-closed)."
            )

        shas: list[str] = []
        if args.rev_range:
            if ".." not in args.rev_range:
                raise GateError(f"--range must be '<base>..<head>', got {args.rev_range!r}")
            base, head = args.rev_range.split("..", 1)
            shas = commits_for_push(base.strip(), head.strip(), args.repo,
                                    base_ref=args.base_ref)
        else:
            lines = [ln.strip() for ln in sys.stdin.read().splitlines() if ln.strip()]
            if not lines:
                raise GateError(
                    "no ref updates on stdin and no --range given (fail-closed)."
                )
            for line in lines:
                parts = line.split()
                if len(parts) < 3:
                    raise GateError(f"malformed pre-receive line: {line!r}")
                old, new, _ref = parts[0], parts[1], parts[2]
                for sha in commits_for_push(old, new, args.repo):
                    if sha not in shas:
                        shas.append(sha)

        if not shas:
            print("[AEGIS] push gate: no commits in range (ref deletion / fast-forward "
                  "of already-approved commits); nothing to approve.")
            return 0

        violations = check_commits(checker, statuses, shas, args.repo)
        if violations:
            _print_violations(queue_path, violations)
            return 1

        print(f"[AEGIS] push gate passed - {len(shas)} commit(s) carry an APPROVED "
              f"'Task:' declaration (authority: {queue_path}).")
        return 0

    except GateError as exc:
        print()
        print("=" * 70)
        print("  AEGIS GOVERNANCE: PUSH BLOCKED - Fail-Closed")
        print("=" * 70)
        print(f"  {exc}")
        print("=" * 70)
        print()
        return 1


if __name__ == "__main__":
    sys.exit(main())

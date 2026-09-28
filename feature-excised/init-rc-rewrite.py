#!/usr/bin/env python3
"""T-EXCISE-INIT-RC-REWRITE — build-time init-rc rewrite filter (mechanics).

Durable, per-service rewrite of a factory-derived vendor init ``.rc`` file at
build time, WITHOUT ever touching the read-only, regen-managed
``vendor/google_devices/<dev>/proprietary/**`` prebuilt.

The *policy* (which device drops which service, and the exact binary that must
appear on the ``service`` line) lives in the hand-maintained overlay
``vendor/guardtalk/feature-excised/init-rc-excised.mk``. This tool is the
generic, testable mechanism it invokes:

    init-rc-rewrite.py --src <prebuilt .rc> --dst <generated .rc> \
        --service <name> --binary </vendor/bin/...>

It removes, fail-closed and per-service-scoped:

  1. the block
         service <name> <binary> [args...]
             <indented option lines ...>      # class/user/group/seclabel/...
     (the whole block plus exactly one following blank line), and
  2. every ``start <name>`` line inside an ``on <trigger>`` action block.  A
     block whose body is ONLY that start line is removed whole (trigger + body
     + one trailing blank); a *shared* block is edited in place so its unrelated
     commands survive (QIRC-1 hardening — never drop collateral commands).

Everything else in the file is preserved byte-for-byte (no whole-file copy of a
shared rc; the file carries many other unrelated services).  The tool NEVER
matches a same-named service bound to a different binary (e.g. comet's shipped
``service init_thermal_config /vendor/bin/init_thermal_config`` is left intact
when the requested binary is ``/vendor/bin/rango_init_thermal_config``).

Exit codes / stdout (consumed by the overlay via ``$(shell ...)``):

  * ``REWRITTEN ...``  — one service block (and N start actions) removed
  * ``NOOP ...``       — block already absent (idempotent re-run / regen) **and no
    exact-token reference to the service survives**
  * non-zero + ``ERROR ...`` on stderr — malformed input, a partial block, or a
    dangling consumer left behind (Law 3: fail loudly, never silently no-op).
    The NOOP early-return itself is fail-closed: it refuses to declare "already
    excised" while any exact-token reference (e.g. a bare column-0
    ``start <svc>`` or an ``exec_start <svc>``) still survives, because the
    block-scoped start detector does not see those (T-EXCISE-INIT-RC-START-DETECT-FAILOPEN).

No build/flash/boot; pure host-side text transform (Law 7: static only).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def _tokens(line: str) -> list[str]:
    return line.split()


def _is_indented(line: str) -> bool:
    return bool(line) and line[0] in " \t" and line.strip() != ""


def _is_blank(line: str) -> bool:
    return line.strip() == ""


def find_service_block(lines: list[str], service: str, binary: str) -> tuple[int, int] | None:
    """Return [start, end) of the exact ``service <name> <binary>`` block.

    Returns ``None`` when no service line names ``service`` at all.  Raises when
    a line names the service but binds a different binary (partial/ambiguous
    match — fail closed rather than guess).
    """
    hit: tuple[int, int] | None = None
    for i, line in enumerate(lines):
        toks = _tokens(line)
        if len(toks) >= 3 and toks[0] == "service" and toks[1] == service:
            if toks[2] != binary:
                raise ValueError(
                    f"service '{service}' is bound to '{toks[2]}', not the expected "
                    f"'{binary}' — refusing a partial/ambiguous match"
                )
            if hit is not None:
                raise ValueError(f"service '{service}' {binary} declared more than once")
            j = i + 1
            while j < len(lines) and _is_indented(lines[j]):
                j += 1
            if j < len(lines) and _is_blank(lines[j]):
                j += 1  # drop exactly one trailing blank
            hit = (i, j)
    return hit


def find_start_blocks(
    lines: list[str], service: str
) -> tuple[list[tuple[int, int]], int]:
    """Return deletion ``[start, end)`` ranges + count for ``start <service>``.

    A **dedicated** block — one whose body consists solely of
    ``start <service>`` lines — is removed whole (trigger + body + exactly one
    trailing blank).  The real 14 files are all dedicated, so this keeps the
    emitted rc byte-for-byte identical to the pre-hardening tool.

    A **shared** block — one whose body also carries unrelated commands — is
    edited in place: only the ``start <service>`` line(s) are deleted, so the
    trigger and every unrelated command survive.  QIRC-1: removing the whole
    shared block would silently drop those commands (a build-time over-match),
    so it is never done.  A surviving exact *token* reference to the service
    (e.g. ``exec_start <service>``) is still caught by
    :func:`dangling_references` and fails the build closed (Law 3).
    """
    ranges: list[tuple[int, int]] = []
    actions = 0
    i = 0
    n = len(lines)
    while i < n:
        toks = _tokens(lines[i])
        if toks and toks[0] == "on":
            j = i + 1
            while j < n and _is_indented(lines[j]):
                j += 1
            starts = [b for b in range(i + 1, j) if _tokens(lines[b])[:2] == ["start", service]]
            if starts:
                if len(starts) == j - (i + 1):
                    # Dedicated: every body line starts the service -> cut the
                    # whole block (identical to the pre-hardening behaviour).
                    k = j
                    if k < n and _is_blank(lines[k]):
                        k += 1  # drop exactly one trailing blank
                    ranges.append((i, k))
                    actions += len(starts)
                    i = k
                    continue
                # Shared: cut ONLY the `start <service>` line(s), keep the rest.
                for b in starts:
                    ranges.append((b, b + 1))
                    actions += 1
                i = j
                continue
        i += 1
    return ranges, actions


def dangling_references(
    lines: list[str], service: str, removed: set[int] | None = None
) -> list[int]:
    """1-based SOURCE line numbers of any surviving token reference to ``service``.

    ``removed`` (optional) is the set of 0-based indices that the caller is
    deleting.  Those lines are skipped — they are the references being cut, not
    survivors — so the numbers returned are **source** line numbers even when
    the caller later mutates ``lines``.  This replaces the earlier behaviour that
    ran the check on the already-mutated list and therefore reported *post*-
    removal indices (e.g. a stray reference on source L7 was reported as [4]).

    Skipping whole-line ranges cannot change *which* references survive (each
    removed element is a complete line, so no adjacent tokens merge), so the
    fail-closed verdict is identical to the post-removal check — only the line
    numbers are corrected.  Comments are inert: the token after ``#`` is not an
    active reference.
    """
    skip = removed or frozenset()
    out = []
    for i, line in enumerate(lines):
        if i in skip:
            continue
        stripped = line.split("#", 1)[0]
        if service in _tokens(stripped):
            out.append(i + 1)
    return out


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--src", required=True, help="factory prebuilt .rc (read-only)")
    ap.add_argument("--dst", required=True, help="generated filtered .rc to write")
    ap.add_argument("--service", required=True, help="exact init service name to remove")
    ap.add_argument("--binary", required=True, help="exact binary that must appear on the service line")
    ap.add_argument("--report", help="optional path to append a JSON result line")
    args = ap.parse_args(argv)

    src = Path(args.src)
    dst = Path(args.dst)

    def emit(status: str, detail: dict) -> None:
        line = {"status": status, "service": args.service, "binary": args.binary,
                "src": str(src), "dst": str(dst), **detail}
        if args.report:
            with open(args.report, "a", encoding="utf-8") as fh:
                fh.write(json.dumps(line, sort_keys=True) + "\n")
        print(f"GT_INIT_RC_REWRITE status={status} service={args.service} "
              f"src={src} dst={dst} {detail.get('note', '')}".rstrip())

    try:
        raw = src.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"ERROR: cannot read source rc: {exc}", file=sys.stderr)
        return 2

    lines = raw.splitlines(keepends=True)
    try:
        block = find_service_block(lines, args.service, args.binary)
        starts, removed_actions = find_start_blocks(lines, args.service)

        if block is None and not starts:
            # Idempotence guard (T-EXCISE-INIT-RC-START-DETECT-FAILOPEN): the
            # start-action detector only counts `start <svc>` *inside* an `on`
            # block, so a bare column-0 `start <svc>` (or an `exec_start <svc>`)
            # with no service block yields starts == [] and block is None.  Do
            # NOT declare "already excised" while any exact token reference
            # still survives — that is the same dangling-consumer failure the
            # rewritten path already refuses, and refusing it here keeps the
            # NOOP path from silently returning 0 with the reference intact.
            leftover = dangling_references(lines, args.service)
            if leftover:
                raise ValueError(
                    f"service '{args.service}' still referenced at source line(s) "
                    f"{leftover} with no matching service block or 'start' action "
                    f"— refusing to declare it 'already excised'"
                )
            # Idempotent: the excision is already present in the source. Copy
            # through unchanged (the source is still the read-only prebuilt).
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_text(raw, encoding="utf-8")
            emit("NOOP", {"removed_service_blocks": 0, "removed_start_actions": 0,
                          "note": "already excised"})
            return 0

        if block is None and starts:
            raise ValueError(
                f"found {len(starts)} 'start {args.service}' action(s) but no "
                f"matching service block — malformed/partial rc"
            )

        # Remove trailing ranges first so earlier indices stay valid.  The
        # dangling check is evaluated against the ORIGINAL list (minus the
        # removed ranges) so its line numbers are source line numbers; whole
        # lines are removed, so the surviving token set is unchanged.
        ranges = sorted(([block] if block else []) + starts, reverse=True)
        removed: set[int] = {i for (a, b) in ranges for i in range(a, b)}
        leftover = dangling_references(lines, args.service, removed)
        if leftover:
            raise ValueError(
                f"service '{args.service}' still referenced at source line(s) "
                f"{leftover} after removal — refusing to leave a dangling consumer"
            )
        for (a, b) in ranges:
            del lines[a:b]

        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text("".join(lines), encoding="utf-8")
        emit("REWRITTEN", {"removed_service_blocks": 1,
                           "removed_start_actions": removed_actions,
                           "note": f"removed {1 + removed_actions} block(s)"})
        return 0
    except ValueError as exc:
        print(f"ERROR: {src}: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())

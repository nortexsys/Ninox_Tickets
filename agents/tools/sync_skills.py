"""Materialise each agent role's skill subset from agents/skills/ according to agents/roles.yaml.

    python agents/tools/sync_skills.py            # write the per-role copies
    python agents/tools/sync_skills.py --check    # exit 1 if any copy is missing, stale or modified

Targets:
  * a role with `runtime: claude-code` -> its `materialize_to` (e.g. .claude/skills/), where Claude Code
    discovers skills natively;
  * a role with `runtime: langgraph`   -> agents/.build/skills/<role>/, the directory handed to deepagents'
    SkillsMiddleware as that agent's only skill source.

The script only ever deletes directories it created itself: every target keeps a
`.sync-manifest.json` listing the skills it manages. Anything else in a target is left alone.
No symlinks are used, so the result is identical on Windows and Linux.
"""
from __future__ import annotations

import argparse, hashlib, json, re, shutil, sys
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parents[2]
ROLES_FILE = REPO / "agents" / "roles.yaml"
BUILD = REPO / "agents" / ".build" / "skills"
MANIFEST = ".sync-manifest.json"
NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def load_roles(path: Path = ROLES_FILE) -> dict:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if data.get("version") != 1:
        raise SystemExit(f"{path}: unsupported version {data.get('version')!r}")
    return data


def frontmatter(skill_md: Path) -> dict:
    text = skill_md.read_text(encoding="utf-8")
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.S)
    if not m:
        raise ValueError(f"{skill_md}: no YAML frontmatter")
    return yaml.safe_load(m.group(1)) or {}


def validate_store(root: Path) -> list[str]:
    """Return the names of valid skills in the store; raise on anything malformed."""
    errors, names = [], []
    loose = [p.name for p in root.iterdir() if p.is_file() and p.suffix == ".md"]
    if loose:
        errors.append(f"loose .md files directly in {root} (would be read as skills): {loose}")
    for d in sorted(p for p in root.iterdir() if p.is_dir()):
        md = d / "SKILL.md"
        if not md.exists():
            errors.append(f"{d.name}: no SKILL.md"); continue
        try:
            fm = frontmatter(md)
        except ValueError as e:
            errors.append(str(e)); continue
        if fm.get("name") != d.name:
            errors.append(f"{d.name}: frontmatter name {fm.get('name')!r} does not match its directory")
        if not NAME_RE.match(d.name):
            errors.append(f"{d.name}: not kebab-case")
        if not str(fm.get("description", "")).strip():
            errors.append(f"{d.name}: empty description")
        names.append(d.name)
    if errors:
        raise SystemExit("skill store invalid:\n  " + "\n  ".join(errors))
    return names


def tree_hash(d: Path) -> str:
    h = hashlib.sha256()
    for f in sorted(p for p in d.rglob("*") if p.is_file()):
        h.update(f.relative_to(d).as_posix().encode()); h.update(b"\0"); h.update(f.read_bytes()); h.update(b"\0")
    return h.hexdigest()


def targets(data: dict) -> dict[str, tuple[Path, list[str]]]:
    out = {}
    for role, spec in data["roles"].items():
        runtime = spec.get("runtime")
        if runtime == "claude-code":
            target = REPO / spec["materialize_to"]
        elif runtime == "langgraph":
            target = BUILD / role
        else:
            raise SystemExit(f"role {role}: unknown runtime {runtime!r}")
        out[role] = (target, list(spec.get("skills", [])))
    return out


def plan(data: dict) -> tuple[dict, list[str]]:
    store = REPO / data["skills_root"]
    names = set(validate_store(store))
    t = targets(data)
    missing = sorted({(r, s) for r, (_, skills) in t.items() for s in skills if s not in names})
    if missing:
        raise SystemExit("roles.yaml names skills that do not exist: " + ", ".join(f"{r}:{s}" for r, s in missing))
    assigned = {s for _, skills in t.values() for s in skills}
    return t, sorted(names - assigned)


def sync(data: dict) -> None:
    store = REPO / data["skills_root"]
    t, unassigned = plan(data)
    for role, (target, skills) in t.items():
        target.mkdir(parents=True, exist_ok=True)
        mf = target / MANIFEST
        previous = json.loads(mf.read_text(encoding="utf-8"))["skills"] if mf.exists() else {}
        for old in set(previous) - set(skills):          # only what this script created
            shutil.rmtree(target / old, ignore_errors=True)
        manifest = {}
        for s in skills:
            dst = target / s
            if dst.exists():
                shutil.rmtree(dst)
            shutil.copytree(store / s, dst)
            manifest[s] = tree_hash(dst)
        mf.write_text(json.dumps({"role": role, "source": data["skills_root"], "skills": manifest}, indent=2) + "\n", encoding="utf-8")
        print(f"{role:12s} -> {target.relative_to(REPO).as_posix()}  ({len(skills)} skills)")
    if unassigned:
        print("unassigned (vendored, given to no role): " + ", ".join(unassigned))


def check(data: dict) -> int:
    store = REPO / data["skills_root"]
    t, _ = plan(data)
    problems = []
    for role, (target, skills) in t.items():
        mf = target / MANIFEST
        if not mf.exists():
            problems.append(f"{role}: {target.relative_to(REPO).as_posix()} not materialised"); continue
        recorded = json.loads(mf.read_text(encoding="utf-8"))["skills"]
        if sorted(recorded) != sorted(skills):
            problems.append(f"{role}: skills differ from roles.yaml")
        for s in skills:
            d = target / s
            if not d.exists():
                problems.append(f"{role}:{s} missing"); continue
            if tree_hash(d) != tree_hash(store / s):
                problems.append(f"{role}:{s} differs from agents/skills/{s}")
    for p in problems:
        print("OUT OF SYNC:", p)
    print("skills in sync" if not problems else f"{len(problems)} problem(s); run agents/tools/sync_skills.py")
    return 1 if problems else 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    data = load_roles()
    sys.exit(check(data) if args.check else (sync(data) or 0))

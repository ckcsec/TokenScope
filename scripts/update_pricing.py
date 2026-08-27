#!/usr/bin/env python3
"""Regenerate pricing.json from the models.dev community catalog.

Policy:
- Never overwrite entries that already exist in pricing.json (curated and
  previously imported prices always win; models.dev data can lag official
  price changes).
- Only append models that are not present yet, with a conservative filter.
- Keep the file sorted by modelID for stable diffs.

Usage:
    python3 scripts/update_pricing.py [--source-url URL] [--dry-run]
"""

from __future__ import annotations

import argparse
import datetime
import json
import sys
import urllib.request
from pathlib import Path

DEFAULT_SOURCE_URL = "https://models.dev/api.json"
REPO_ROOT = Path(__file__).resolve().parent.parent
PRICING_PATH = REPO_ROOT / "pricing.json"


def fetch_json(url: str) -> dict:
    request = urllib.request.Request(url, headers={"User-Agent": "TokenScope-pricing-sync"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def normalize_model_id(raw_id: str) -> str:
    """Map a models.dev model id to the slug used in local agent logs."""
    slug = raw_id.rsplit("/", 1)[-1]
    slug = slug.split(":", 1)[0]
    slug = slug.replace("@", "-")
    return slug.strip().lower()


def to_entry(model_id: str, model: dict) -> dict | None:
    cost = model.get("cost") or {}
    if model.get("disabled") or model.get("deprecated"):
        return None
    input_price = cost.get("input") or 0
    output_price = cost.get("output") or 0
    if input_price < 0 or output_price < 0 or (input_price == 0 and output_price == 0):
        return None
    entry = {
        "modelID": model_id,
        "inputPerMillion": input_price,
        "outputPerMillion": output_price,
        "cacheReadPerMillion": cost.get("cache_read") or 0,
        "cacheWritePerMillion": 0,
    }
    return entry


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-url", default=DEFAULT_SOURCE_URL)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    catalog = fetch_json(args.source_url)
    providers = catalog.get("providers", catalog)
    if not isinstance(providers, dict):
        print("unexpected models.dev payload shape", file=sys.stderr)
        return 1

    existing = json.loads(PRICING_PATH.read_text())
    known = {entry["modelID"].lower() for entry in existing["models"]}

    candidates: dict[str, dict] = {}
    seen_total = 0
    for provider in providers.values():
        if not isinstance(provider, dict) or provider.get("disabled"):
            continue
        for raw_id, model in (provider.get("models") or {}).items():
            if not isinstance(model, dict):
                continue
            seen_total += 1
            model_id = normalize_model_id(raw_id)
            if not model_id or model_id in known or model_id in candidates:
                continue
            entry = to_entry(model_id, model)
            if entry is not None:
                candidates[model_id] = entry

    added = sorted(candidates.values(), key=lambda entry: entry["modelID"].lower())
    print(
        f"seen={seen_total} valid_candidates={len(added)} "
        f"skipped_existing={sum(1 for _ in known) if False else len(known)}",
        file=sys.stderr,
    )

    if args.dry_run:
        print(f"dry-run: would add {len(added)} models to {PRICING_PATH.name}")
        return 0

    if not added:
        print("no new models to add")
        return 0

    existing["version"] = datetime.datetime.now(datetime.timezone.utc).date().isoformat()
    existing["models"] = sorted(
        existing["models"] + added, key=lambda entry: entry["modelID"].lower()
    )
    PRICING_PATH.write_text(json.dumps(existing, indent=2) + "\n")
    print(f"added {len(added)} models, total {len(existing['models'])}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

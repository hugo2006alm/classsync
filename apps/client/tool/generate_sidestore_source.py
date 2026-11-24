#!/usr/bin/env python3
"""Generate a SideStore source from the IPA selected by the release workflow."""

import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path

repo = "hugo2006alm/classsync"
tag = os.environ["GITHUB_REF_NAME"]
if not re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+", tag):
    raise SystemExit("Expected a stable ClassSync release tag")

release = Path("release")
ipa = release / "ClassSync-iOS.ipa"
size = ipa.stat().st_size
if size <= 0:
    raise SystemExit("ClassSync IPA is empty")

website = f"https://github.com/{repo}"
icon = f"https://raw.githubusercontent.com/{repo}/{tag}/apps/client/assets/classsync_icon.png"
description = "Local-first university manager and lecture automation."
source = {
    "name": "ClassSync",
    "subtitle": description,
    "iconURL": icon,
    "website": website,
    "apps": [
        {
            "name": "ClassSync",
            "bundleIdentifier": "app.classsync.classsync",
            "developerName": "ClassSync",
            "localizedDescription": description,
            "iconURL": icon,
            "versions": [
                {
                    "version": tag[1:],
                    "date": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                    "localizedDescription": f"Release notes: {website}/releases/tag/{tag}",
                    "downloadURL": f"{website}/releases/download/{tag}/{ipa.name}",
                    "size": size,
                    "minOSVersion": "15.0",
                }
            ],
            "appPermissions": {"entitlements": [], "privacy": {}},
        }
    ],
    "news": [],
}
(release / "sidestore-source.json").write_text(
    json.dumps(source, indent=2) + "\n", encoding="utf-8"
)

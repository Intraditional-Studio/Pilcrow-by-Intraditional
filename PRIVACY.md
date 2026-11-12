# Privacy

Pilcrow is built to keep your work on your Mac. It has no analytics, no
telemetry, no advertising SDKs, and no third-party servers of its own.

## What is stored locally

Pilcrow writes a single state file:

```
~/Library/Application Support/Pilcrow/state.json
```

It contains your sessions, repositories (names and local paths), focus
statistics, quests, streaks, coins, purchases, preferences, and the GitHub
account profile you chose to connect. You can reveal or remove this file
from **Settings → Your data**.

Focus history is also kept in memory while the app runs. Nothing in the
state file is uploaded anywhere.

## GitHub

Connecting GitHub is optional. When you choose to connect:

- Pilcrow uses GitHub's **OAuth Device Flow**. You approve the device in
  your browser; Pilcrow never sees your GitHub password.
- The resulting access token is stored only in the **macOS Keychain**
  (service `studio.intraditional.pilcrow.github`). It is never written to
  `state.json`.
- Pilcrow calls the GitHub REST API only to read your profile, verify the
  token, and enrich commits you already have locally with GitHub metadata.
  Requests go to `api.github.com` and `github.com` only.
- You can disconnect at any time, which deletes the token from the
  Keychain.

If you add a classic personal access token instead, the same rules apply:
Keychain storage only, GitHub API only.

Pilcrow's use of GitHub data is subject to
[GitHub's Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-privacy-statement).

## Local git

Pilcrow reads commit history by running the system `git` binary against
folders you explicitly add. It does not modify your repositories, doesn't
push, and doesn't fetch unless you ask it to sync GitHub metadata.

## Network connections

Pilcrow makes network requests only when you connect or refresh GitHub.
There is no background telemetry, crash reporting, or update check.

## Children

Pilcrow is a productivity tool and is not directed at children.

## Changes

Material changes to this policy will be published with the release notes
and reflected in this file.

## Contact

Privacy questions: see the contact details published with the Pilcrow
release.

# EraUI Discord notifications

Author: Squirt

Public invite: https://discord.gg/fp6HHNYNMm

The STAFF category is restricted to the owner, Admin and Moderator roles.
Keep `github-feed` and `curseforge-feed` synchronized with its permissions.

## GitHub

The repository webhook sends issue, issue-comment, discussion, discussion-comment,
pull-request, review, review-comment and commit-comment events to Discord's
GitHub-compatible endpoint in `github-feed`. Payload format: JSON. SSL verification: on.
The webhook URL is a credential. Do not paste it into documentation or source code.

## CurseForge

`.github/workflows/curseforge-comments.yml` runs about every 30 minutes on GitHub's
free hosted Linux runners for this public repository. Delivery can be delayed by
GitHub's scheduler. It uses the public website's comments endpoint, which is not a
documented/stable CurseForge API and may change or block automated requests.

Required repository Actions secret: `CURSEFORGE_DISCORD_WEBHOOK`.
Its value is the Discord webhook for the private `curseforge-feed` channel.

First setup: run the workflow manually with `initialize_state` and
`test_notification` enabled. Existing comments become the baseline rather than
being reposted. Later manual runs should leave `initialize_state` off.

Every scan includes older pages and nested replies. Comment IDs are deduplicated;
edits to an existing comment are not forwarded again. Messages cannot ping roles
or members. At most 100 new comments are sent per run, oldest first.

State contains only IDs and timestamps and is saved in the
`curseforge-comment-state` Actions artifact. Each acknowledged delivery is
checkpointed, and state is uploaded even if a later delivery fails. A crash
between Discord accepting a message and state being saved/uploaded can still
cause that message to be repeated. Do not delete the newest state artifact.
Missing or invalid state causes failure rather than an automatic reset.

Artifacts last 90 days and are renewed each run. GitHub can disable scheduled
workflows in public repositories after 60 days without repository activity.
Re-enable the workflow in the Actions tab if this happens. If all state expires,
review any missed comments before explicitly creating a fresh baseline.
Keep GitHub Actions failure notifications enabled for this workflow.

The script uses no external packages. Check it locally with:

```sh
node --test Tools/TestCurseForgeNotifier.mjs
node .github/scripts/curseforge-comments.mjs probe
```

`.github` and `Tools` are excluded from the CurseForge addon package. This
automation does not change addon features, its version, or its public description.

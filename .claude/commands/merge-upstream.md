---
description: Merge ironic-image upstream to downstream
---

# Merging upstream to downstream

This command merges changes from upstream `metal3-io/ironic-image`
into its downstream fork `openshift/ironic-image`.
This operation is necessary to keep the downstream fork up-to-date with any
upstream changes.

## Context

- downstream: git remote corresponding to `openshift/ironic-image`
- upstream: git remote corresponding to `metal3-io/ironic-image`

Note that the actual fork names might be different in the local environment

## Merge Steps

### 1. Preparation

Ensure your local repository is up to date by fetching all remote branches from
git.

Check the current branch. Here you need to make sure that:
- There are no local changes you may overwrite
- You are on the right branch that is based on the `main` branch of
  `openshift/ironic-image`
- You're on the latest commit in that branch.

Check if the remote branch `main` on `metal3-io/ironic-image` has
any outstanding changes compared to the current branch.

Create a new branch for the merge named `merge-upstream-$(date +%Y-%m-%d)`.

### 2. Merge Upstream Changes

Merge the upstream branch into the current one, replacing `upstream` with the
correct name of the remote branch, if necessary:

```bash
git merge --no-ff --no-commit upstream/main
```

### 3. Handle Common Conflicts

**GitHub Workflows**: We only keep donwstream files in the `.github/` directory.
- If conflicts occur keep the downstream version
- If no conflicts, remove the new files incoming from upstream.
- Verify with `git diff downstream/main -- .github/`, this must return empty
- If the above command result it not empty investigate or repeat above steps

**Hack tools**: We don't have these scripts in downstream:
- Remove all files added in the `hack/` directory
- Verify with `git diff downstream/main -- hack/`, this must return empty
- If the above command result it not empty investigate or repeat above steps

**Release notes**: We don't have release notes in downstream repos, so this is upstream only, so all incoming changes need to be discarded. It includes the `releasenotes` directory and the `renovate.json` file.
- Verify with `git diff downstream/main -- releasenotes/` and `git diff downstream/main -- renovate.json`
- The above commands must return empty, if not then investigate or repeat above steps

**Downstream-Specific Changes**: Look for commit messages starting with:
- `DOWNSTREAM:` - Changes specific to OpenShift
- `OCPBUGS-*:` - OpenShift bug fixes
- These must be preserved during the merge, unless replaced by an equivalent
upstream commit.

### 4. Downstream specific actions

**OWNERS**: Revert any changes to `OWNERS`, you must keep the downstream
version of this file.

**Gitignore**: Revert any changes to `.gitignore` file, you must keep the
downstream version of this file.

### 5. Handling other conflicts

**Packages lists**: There is no upstream to downstream sync of package lists.
Discard any changes to the downstream package files `main-packages-list.ocp`
and `main-packages-list.okd`

Don't do conflict resolution for other files automatically.

### 6. Next steps

Prompt the user for next steps, and show a brief summary of what you did.


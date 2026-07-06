# Feedback: SPM Dependency Resolution via Artifactory

**From:** Segment SDK team (analytics-swift)
**To:** Secure Supply Chain / Platform team
**Date:** 2026-07-02
**Repo:** `segmentio/analytics-swift`
**Branch:** `poc/binary-xcframework-release-pipeline`

## What works

| Step | Status | Evidence |
| --- | --- | --- |
| OIDC token exchange (`github-actions-segmentio` provider) | Working | Token mints successfully, `segmentio/analytics-swift` is in the OIDC trust |
| Token validation (Artifactory REST API ping) | Working | `GET /artifactory/api/system/ping` returns HTTP 200 with the OIDC-issued token |

## What doesn't work

SPM cannot clone dependencies through Artifactory. Git clone fails regardless
of URL format or auth mechanism.

### Auth mechanisms tried

| Approach | Result |
| --- | --- |
| `~/.netrc` (`machine twilio.jfrog.io login token password $TOKEN`) | `could not read Username` — git on Linux didn't read it |
| `git credential.helper store` with `~/.git-credentials` (`https://token:$TOKEN@twilio.jfrog.io`) | `Authentication failed` |
| `git config url.insteadOf` (embed token in URL rewrite) | `repository not found` (404) |
| `git config http.extraHeader "Authorization: Bearer $TOKEN"` | `repository not found` (404) |

The Bearer header approach is what the internal docs recommend for Swift. Once
auth was resolved, the underlying issue became clear: **the URL path returns 404
or 500 regardless of auth**.

### URL paths probed

All probed with a valid Bearer token (confirmed via ping).

| URL path | HTTP | Response |
| --- | --- | --- |
| `artifactory/api/swift/virtual-swift-thirdparty/segmentio/sovran-swift.git/info/refs` | 404 | Not found |
| `artifactory/git/virtual-swift-thirdparty/segmentio/sovran-swift.git/info/refs` | 500 | `"Expected Repository attribute"` |
| `artifactory/git/virtual-swift-thirdparty/segmentio/sovran-swift/info/refs` | 500 | `"Expected Repository attribute"` |
| `artifactory/git/virtual-swift-thirdparty/sovran-swift.git/info/refs` | 500 | `"Expected Repository attribute"` |
| `artifactory/git/remote-swift-github/segmentio/sovran-swift.git/info/refs` | 500 | `"Expected Repository attribute"` |
| `artifactory/git/remote-swift-github/segmentio/sovran-swift/info/refs` | 500 | `"Expected Repository attribute"` |
| `artifactory/remote-swift-github/segmentio/sovran-swift.git/info/refs` | 404 | Not found |
| `artifactory/virtual-swift-thirdparty/segmentio/sovran-swift.git/info/refs` | 404 | Not found |
| `artifactory/api/vcs/virtual-swift-thirdparty/segmentio/sovran-swift.git/info/refs` | 404 | Not found |

## Root cause (our assessment)

The `"Expected Repository attribute"` error on all `/git/` paths suggests the
Artifactory instance does not have a **Git LFS / Git repository type** enabled.
The Swift virtual repo (`virtual-swift-thirdparty`) is configured as a `swift`
package type, which likely supports the Swift Package Registry protocol
(SE-0292) but **not raw git clone over HTTPS** — which is what SPM uses to
resolve dependencies.

SPM resolves packages by git-cloning the repository URL declared in
`Package.swift`. The `swift package config set-mirror` command redirects those
clones to a different URL, but the target must still be a git-cloneable
endpoint.

## Proposed solutions

We need one of the following to resolve Swift dependencies through Artifactory
in CI:

1. **Provide a git-cloneable URL path** for the `virtual-swift-thirdparty`
   repo. If there is a URL format that supports `git clone` over HTTPS with
   a Bearer token, we need documentation on it.

2. **Or, enable a git-type repository** in Artifactory that proxies
   `https://github.com` and supports the git smart HTTP protocol
   (`/info/refs?service=git-upload-pack`). The current Swift-type repo does
   not support raw git clone.

3. **Or, provide documentation on Swift Package Registry (SE-0292) mode** if
   that's how the Swift virtual repo is meant to be consumed. SPM 5.7+ supports
   registry-based resolution (`swift package-registry set`), but this is a
   different mechanism than git mirrors and we have no example of it working
   against this Artifactory instance.

## Questions

1. **Does `virtual-swift-thirdparty` support git clone?** If so, what is the
   correct URL format? The docs say to "configure SPM to resolve through
   `https://twilio.jfrog.io/artifactory/api/swift/virtual-swift-thirdparty/`"
   but don't specify the git clone path.

2. **If it only supports the Swift Package Registry protocol (SE-0292):** is
   there documentation on how to configure SPM to use registry mode instead of
   git mode? SPM 5.7+ has `swift package-registry set`, but this is a different
   resolution mechanism than git-based mirrors.

3. **Is a separate git-type repository needed?** Would the solution be to
   create a `remote-git-github` repository (Artifactory Git LFS type) that
   proxies `https://github.com` and can serve git clone requests?

## Environment

- Runner: `ubuntu-latest-large` (GitHub-hosted)
- Swift: version available on the runner image
- Git: version available on the runner image
- Artifactory: `twilio.jfrog.io` (cloud instance)

## How to reproduce

See workflow at:
`segmentio/analytics-swift/.github/workflows/resolve-dependencies.yml`
(branch `poc/binary-xcframework-release-pipeline`)

Trigger manually via Actions > "Resolve Dependencies (Artifactory OIDC)" >
Run workflow.

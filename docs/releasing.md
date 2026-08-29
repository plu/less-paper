# Releasing

Every push to `main` ships a build to TestFlight, numbered with the CI run number — a tester
looking at 3.0.1 (68) is looking at run 68 of `ci.yml`.

Promoting one of those builds to the App Store is the Release workflow, which takes that number and
nothing else:

```sh
gh workflow run release.yml -f build=68
```

It resolves the number back to the commit and marketing version that produced it, refuses if that
run never uploaded a build or if the build is not `VALID` on App Store Connect, uploads the
listing, submits for review, and tags the commit as `v3.0.1+68` with a GitHub release. Add
`-f dry_run=true` to see all of that without doing any of it, and `-f skip_screenshots=true` to
leave the images on the listing alone.

Apple holds the approved version in Pending Developer Release until you press Release in App Store
Connect; it then rolls out over seven days.

Nothing bumps `marketingVersion` in
`Tuist/ProjectDescriptionHelpers/Extensions/String+Extensions.swift`. Edit it by hand after a
submission — otherwise every subsequent TestFlight build carries a version that has already been
used and can never be submitted.

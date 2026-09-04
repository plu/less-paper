import ProjectDescription

let tuist = Tuist(
    // Connects the project to the Tuist server, which is what `url` already defaults to
    // (https://tuist.dev). Everything server-side is keyed off this handle: build and test
    // insights, the binary cache, previews. Without it those commands still work, purely locally.
    fullHandle: "plu/less-paper",
    project: .tuist(
        compatibleXcodeVersions: [
            .exact(Version(26, 5, 0)),
        ],
        // Without this a handle makes every command require authentication, `tuist generate`
        // included, and it fails outright rather than degrading. This is a public repository whose
        // README tells a contributor to run `tuist generate`, so on a fresh clone that has to work
        // without a Tuist account. With it, an authenticated run still gets insights and the
        // binary cache; an unauthenticated one simply goes without.
        generationOptions: .options(optionalAuthentication: true),
        // External dependencies only. `.allPossible` was tried and reverted for caching this
        // repository's own modules too. The snapshot-directory walk that used to crash under a
        // cached `TestSupport` was fixed in this same branch, so that is no longer the blocker —
        // but `URL.projectRoot` (`Modules/ApiInterface/Extensions/URL+Extensions.swift`) still
        // resolves a bare `#filePath` inside a function body, baked in when `ApiInterface` is
        // compiled. A binary from the cache carries the path of whatever machine built it, and
        // that is not fixed here. `ApiInterface` is a normal cacheable module, and `URL.projectRoot`
        // is used by `ApiImplementationTests`, `MarketingKitTests`, `SnapshotSupport`,
        // `ShareFeature` and `UITestSupport`. Re-enabling `.allPossible` would break that instead —
        // silently, as a wrong path rather than a crash.
        //
        // The profile still lives here rather than on `tuist cache`'s command line, because
        // `tuist generate` reads it from this file: a warm that filtered targets differently from
        // the generate that looks them up fills the cache with entries nobody ever finds.
        cacheOptions: .options(profiles: .profiles(default: .onlyExternal))
    )
)

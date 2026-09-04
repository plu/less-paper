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
        // External dependencies only. `.allPossible` was tried and reverted: it also caches this
        // repository's own modules, and a cached `TestSupport` breaks every snapshot test in the
        // project. `snapshotDirectory(file:)` finds `Snapshots/` by walking up from `#filePath`,
        // which is baked in when the module is compiled — a binary from the cache carries the path
        // of whatever machine built it, so the walk runs to `/` and trips its own precondition. The
        // test process crashes rather than failing an assertion, which reads as an unexplained
        // xctest crash and not as a caching problem. Anything else that resolves a path from
        // `#file` or `#filePath` at runtime has the same fault line.
        //
        // The profile still lives here rather than on `tuist cache`'s command line, because
        // `tuist generate` reads it from this file: a warm that filtered targets differently from
        // the generate that looks them up fills the cache with entries nobody ever finds.
        cacheOptions: .options(profiles: .profiles(default: .onlyExternal))
    )
)

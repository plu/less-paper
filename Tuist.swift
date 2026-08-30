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
        generationOptions: .options(optionalAuthentication: true)
    )
)

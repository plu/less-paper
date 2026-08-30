import ProjectDescription

let tuist = Tuist(
    // Connects the project to the Tuist server, which is what `url` already defaults to
    // (https://tuist.dev). Everything server-side is keyed off this handle: build and test
    // insights, the binary cache, previews. Without it those commands still work, purely locally.
    fullHandle: "plu/less-paper",
    project: .tuist(
        compatibleXcodeVersions: [
            .exact(Version(26, 5, 0)),
        ]
    )
)

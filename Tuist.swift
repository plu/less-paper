import ProjectDescription

let tuist = Tuist(
    project: .tuist(
        compatibleXcodeVersions: [
            .exact(Version(26, 5, 0)),
        ]
    )
)

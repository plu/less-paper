import Foundation
import ProjectDescription
import ProjectDescriptionHelpers

let workspace = Workspace(
    name: "LessPaper",
    projects: ["."],
    generationOptions: .options(
        lastXcodeUpgradeCheck: Version(26, 5, 0)
    )
)

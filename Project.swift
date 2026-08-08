import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "LessPaper",
    options: .options(
        automaticSchemesOptions: .disabled,
        disableBundleAccessors: true,
        textSettings: .textSettings(usesTabs: false, indentWidth: 4, tabWidth: 4)
    ),
    settings: .settings(
        base: .default
    ),
    targets: Module.allCases.flatMap(\.targets),
    schemes: Module.allCases.flatMap(\.schemes),
    additionalFiles: [.folderReference(path: .relativeToRoot("Snapshots"))],
    resourceSynthesizers: []
)

import ProjectDescription

extension TargetReference {
    static func target(_ module: Module) -> TargetReference {
        .target(module.rawValue)
    }
}

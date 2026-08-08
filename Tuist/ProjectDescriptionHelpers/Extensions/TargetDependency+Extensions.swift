import ProjectDescription

extension TargetDependency {
    static func external(_ dependency: Dependency) -> TargetDependency {
        .external(name: dependency.rawValue)
    }

    static func target(_ module: Module) -> TargetDependency {
        .target(name: module.rawValue)
    }
}

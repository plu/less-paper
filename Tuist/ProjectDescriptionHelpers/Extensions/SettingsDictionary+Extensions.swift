import Foundation
import ProjectDescription

/**
 * Extension providing default build settings configuration for the project.
 *
 * This extension defines the standard build settings that should be applied
 * across all targets in the Less Paper iOS project. It ensures consistency
 * in build configuration while supporting environment-specific overrides
 * for code signing and team settings.
 */
public extension SettingsDictionary {
    /**
     * Default build settings configuration for all project targets.
     *
     * Provides a comprehensive set of build settings that enforce:
     * - Modern Swift language features (Swift 6 with strict concurrency)
     * - Asset catalog optimizations with symbol generation
     * - Localization preferences using string catalogs
     * - Version management from environment variables
     * - Code signing configuration from environment
     *
     * ## Key Settings
     * - **Swift 6**: Latest Swift version with complete strict concurrency
     * - **Asset Symbols**: Automatic generation of Swift symbols for assets
     * - **String Catalogs**: Modern localization approach with symbol generation
     * - **Versioning**: Dynamic version numbers from build environment
     * - **Code Signing**: Environment-based configuration for different build contexts
     *
     * - Returns: A configured SettingsDictionary with all necessary build settings
     */
    static var `default`: Self {
        var settings: SettingsDictionary = [
            "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
            "CURRENT_PROJECT_VERSION": .string(.buildNumber),
            "DEVELOPMENT_TEAM": "HZ7YVCSB89",
            "LOCALIZATION_EXPORT_SUPPORTED": "YES",
            "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES",
            "LOCALIZED_STRING_SWIFTUI_SUPPORT": "NO",
            "MARKETING_VERSION": .string(.marketingVersion),
            "STRING_CATALOG_GENERATE_SYMBOLS": "YES",
            "SWIFT_EMIT_LOC_STRINGS": "NO",
            "SWIFT_STRICT_CONCURRENCY": "complete",
            "SWIFT_VERSION": "6",
        ]

        return settings
    }
}

/**
 * Extension providing utility methods for environment-based setting configuration.
 */
extension SettingsDictionary {
    /**
     * Conditionally sets a build setting from an environment value.
     *
     * This method provides a safe way to apply environment-specific build settings
     * without overriding existing values when the environment value is unavailable.
     * It's particularly useful for code signing settings that vary between
     * development, CI, and release builds.
     *
     * - Parameters:
     *   - value: The optional environment value to apply
     *   - key: The build setting key to configure
     *
     * ## Usage
     * ```swift
     * settings.set(Environment.developmentTeam, forKey: "DEVELOPMENT_TEAM")
     * ```
     */
    mutating func set(_ value: Environment.Value?, forKey key: String) {
        if let value = value.getString() {
            self[key] = .string(value)
        }
    }
}

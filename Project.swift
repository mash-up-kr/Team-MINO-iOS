import ProjectDescription

let project = Project(
    name: "iOS-mini-fig",
    organizationName: "yizihn",
    targets: [
        .target(
            name: "iOS-mini-fig",
            destinations: .iOS,
            product: .app,
            bundleId: "yizihn.com.iOS-mini-fig",
            deploymentTargets: .iOS("16.0"),
            infoPlist: .extendingDefault(with: [
                "UIApplicationSceneManifest": .dictionary([
                    "UIApplicationSupportsMultipleScenes": .boolean(false),
                    "UISceneConfigurations": .dictionary([
                        "UIWindowSceneSessionRoleApplication": .array([
                            .dictionary([
                                "UISceneConfigurationName": .string("Default Configuration"),
                                "UISceneDelegateClassName": .string("$(PRODUCT_MODULE_NAME).SceneDelegate"),
                            ]),
                        ]),
                    ]),
                ]),
            ]),
            sources: ["Targets/iOS-mini-fig/Sources/**"],
            resources: ["Targets/iOS-mini-fig/Resources/**"]
        ),
        .target(
            name: "iOS-mini-figTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "yizihn.com.iOS-mini-figTests",
            deploymentTargets: .iOS("16.0"),
            sources: ["Targets/iOS-mini-figTests/**"],
            dependencies: [
                .target(name: "iOS-mini-fig"),
            ]
        ),
        .target(
            name: "iOS-mini-figUITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId: "yizihn.com.iOS-mini-figUITests",
            deploymentTargets: .iOS("16.0"),
            sources: ["Targets/iOS-mini-figUITests/**"],
            dependencies: [
                .target(name: "iOS-mini-fig"),
            ]
        ),
    ]
)

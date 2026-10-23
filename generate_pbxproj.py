#!/usr/bin/env python3
import hashlib
import os

def uuid_for(name):
    # Deterministic 24-char hex string from name
    return hashlib.md5(name.encode("utf-8")).hexdigest()[:24].upper()

def generate_pbxproj(project_dir):
    sources = [
        ("App/PureLibraryApp.swift", "PureLibraryApp.swift"),
        ("Theme/AppTheme.swift", "AppTheme.swift"),
        ("Theme/VectorIconLibrary.swift", "VectorIconLibrary.swift"),
        ("Models/PhotoAssetItem.swift", "PhotoAssetItem.swift"),
        ("Models/PhotoClusterGroup.swift", "PhotoClusterGroup.swift"),
        ("Models/ScanSummaryReport.swift", "ScanSummaryReport.swift"),
        ("Engines/PerceptualHashEngine.swift", "PerceptualHashEngine.swift"),
        ("Engines/PhotoQualityScoringEngine.swift", "PhotoQualityScoringEngine.swift"),
        ("Engines/SimilarityClusterEngine.swift", "SimilarityClusterEngine.swift"),
        ("Engines/JunkAndBlurDetectorEngine.swift", "JunkAndBlurDetectorEngine.swift"),
        ("Services/PhotoLibraryService.swift", "PhotoLibraryService.swift"),
        ("Services/CoreMLNeuralEngineService.swift", "CoreMLNeuralEngineService.swift"),
        ("Services/ScanCacheService.swift", "ScanCacheService.swift"),
        ("Services/LocalizationManager.swift", "LocalizationManager.swift"),
        ("ViewModels/LibraryScannerViewModel.swift", "LibraryScannerViewModel.swift"),
        ("ViewModels/ClusterReviewViewModel.swift", "ClusterReviewViewModel.swift"),
        ("ViewModels/SwipeCullViewModel.swift", "SwipeCullViewModel.swift"),
        ("Views/DashboardView.swift", "DashboardView.swift"),
        ("Views/SettingsView.swift", "SettingsView.swift"),
        ("Views/CategoryPhotoGridView.swift", "CategoryPhotoGridView.swift"),
        ("Views/FullScreenPhotoInspectorView.swift", "FullScreenPhotoInspectorView.swift"),
        ("Views/ClusterCompareView.swift", "ClusterCompareView.swift"),
        ("Views/SwipeCullView.swift", "SwipeCullView.swift"),
        ("Views/TrashStagingView.swift", "TrashStagingView.swift"),
        ("Views/Components/StorageBar.swift", "StorageBar.swift"),
        ("Views/Components/MetricBadge.swift", "MetricBadge.swift"),
        ("Views/Components/ScoreBreakdownView.swift", "ScoreBreakdownView.swift"),
        ("Views/Components/PhotoThumbnailView.swift", "PhotoThumbnailView.swift"),
        ("Views/Components/CategoryCardView.swift", "CategoryCardView.swift"),
    ]

    # File refs and build files
    build_files_content = []
    file_refs_content = []
    sources_entries = []
    
    for path, filename in sources:
        file_ref_id = uuid_for("FILEREF_" + path)
        build_file_id = uuid_for("BUILDFILE_" + path)
        
        build_files_content.append(f"\t\t{build_file_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};")
        file_refs_content.append(f"\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"{path}\"; sourceTree = \"<group>\"; }};")
        sources_entries.append(f"\t\t\t\t{build_file_id} /* {filename} in Sources */,")

    # Resources
    resources = [
        ("Models/ZeroShotPromptBank.json", "ZeroShotPromptBank.json", "text.json"),
        ("Models/PureSemanticEncoder.mlpackage", "PureSemanticEncoder.mlpackage", "wrapper.mlpackage"),
        ("Models/PureAestheticNIMA.mlpackage", "PureAestheticNIMA.mlpackage", "wrapper.mlpackage"),
        ("Models/PureTechnicalIQA.mlpackage", "PureTechnicalIQA.mlpackage", "wrapper.mlpackage"),
    ]
    resources_build_files = []
    for path, filename, ftype in resources:
        f_id = uuid_for("FILEREF_" + path)
        b_id = uuid_for("BUILDFILE_" + path)
        build_files_content.append(f"\t\t{b_id} /* {filename} in Resources */ = {{isa = PBXBuildFile; fileRef = {f_id} /* {filename} */; }};")
        file_refs_content.append(f"\t\t{f_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = \"{path}\"; sourceTree = \"<group>\"; }};")
        resources_build_files.append(f"\t\t\t\t{b_id} /* {filename} in Resources */,")

    info_plist_ref_id = uuid_for("FILEREF_Info.plist")
    file_refs_content.append(f"\t\t{info_plist_ref_id} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")

    app_product_ref_id = uuid_for("PRODUCT_PureLibrary.app")
    file_refs_content.append(f"\t\t{app_product_ref_id} /* PureLibrary.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = PureLibrary.app; sourceTree = BUILT_PRODUCTS_DIR; }};")

    # IDs for core structures
    main_group_id = uuid_for("MAIN_GROUP")
    products_group_id = uuid_for("PRODUCTS_GROUP")
    project_id = uuid_for("PBX_PROJECT")
    native_target_id = uuid_for("NATIVE_TARGET")
    sources_build_phase_id = uuid_for("SOURCES_PHASE")
    frameworks_build_phase_id = uuid_for("FRAMEWORKS_PHASE")
    resources_build_phase_id = uuid_for("RESOURCES_PHASE")
    
    target_debug_cfg_id = uuid_for("TARGET_CFG_DEBUG")
    target_release_cfg_id = uuid_for("TARGET_CFG_RELEASE")
    project_debug_cfg_id = uuid_for("PROJECT_CFG_DEBUG")
    project_release_cfg_id = uuid_for("PROJECT_CFG_RELEASE")
    target_cfg_list_id = uuid_for("TARGET_CFG_LIST")
    project_cfg_list_id = uuid_for("PROJECT_CFG_LIST")

    # Groups
    file_children = [f"\t\t\t\t{uuid_for('FILEREF_' + path)} /* {fn} */," for path, fn in sources]
    file_children.extend([f"\t\t\t\t{uuid_for('FILEREF_' + path)} /* {fn} */," for path, fn, _ in resources])
    file_children.append(f"\t\t\t\t{info_plist_ref_id} /* Info.plist */,")
    file_children.append(f"\t\t\t\t{products_group_id} /* Products */,")

    pbx = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_files_content)}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{chr(10).join(file_refs_content)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{frameworks_build_phase_id} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{main_group_id} = {{
			isa = PBXGroup;
			children = (
{chr(10).join(file_children)}
			);
			sourceTree = "<group>";
		}};
		{products_group_id} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{app_product_ref_id} /* PureLibrary.app */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{native_target_id} /* PureLibrary */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {target_cfg_list_id} /* Build configuration list for PBXNativeTarget "PureLibrary" */;
			buildPhases = (
				{sources_build_phase_id} /* Sources */,
				{frameworks_build_phase_id} /* Frameworks */,
				{resources_build_phase_id} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = PureLibrary;
			productName = PureLibrary;
			productReference = {app_product_ref_id} /* PureLibrary.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{project_id} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
				TargetAttributes = {{
					{native_target_id} = {{
						CreatedOnToolsVersion = 15.0;
					}};
				}};
			}};
			buildConfigurationList = {project_cfg_list_id} /* Build configuration list for PBXProject "PureLibrary" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {main_group_id};
			productRefGroup = {products_group_id} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{native_target_id} /* PureLibrary */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{resources_build_phase_id} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{chr(10).join(resources_build_files)}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{sources_build_phase_id} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{chr(10).join(sources_entries)}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{project_debug_cfg_id} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = NO;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDEFINED_VARIABLES = YES;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 16.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				ARCHS = arm64;
				TARGETED_DEVICE_FAMILY = "1,2";
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			}};
			name = Debug;
		}};
		{project_release_cfg_id} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = NO;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDEFINED_VARIABLES = YES;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 16.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				ARCHS = arm64;
				TARGETED_DEVICE_FAMILY = "1,2";
				ONLY_ACTIVE_ARCH = NO;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				VALIDATE_PRODUCT = YES;
			}};
			name = Release;
		}};
		{target_debug_cfg_id} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = "";
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = "";
				CODE_SIGN_STYLE = Automatic;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGNING_ALLOWED = NO;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = "PureLibrary";
				INFOPLIST_KEY_LSRequiresIPhoneOS = YES;
				INFOPLIST_KEY_NSPhotoLibraryUsageDescription = "PureLibrary analyzes your photo library 100% on-device to identify duplicate groups, blurry shots, and reclaim device storage without network access.";
				INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription = "PureLibrary requires photo management access to save storage and move culled photos to Recently Deleted.";
				IPHONEOS_DEPLOYMENT_TARGET = 16.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.purelibrary.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphoneos;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				ARCHS = arm64;
				TARGETED_DEVICE_FAMILY = "1,2";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			}};
			name = Debug;
		}};
		{target_release_cfg_id} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = "";
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = "";
				CODE_SIGN_STYLE = Automatic;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGNING_ALLOWED = NO;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = "PureLibrary";
				INFOPLIST_KEY_LSRequiresIPhoneOS = YES;
				INFOPLIST_KEY_NSPhotoLibraryUsageDescription = "PureLibrary analyzes your photo library 100% on-device to identify duplicate groups, blurry shots, and reclaim device storage without network access.";
				INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription = "PureLibrary requires photo management access to save storage and move culled photos to Recently Deleted.";
				IPHONEOS_DEPLOYMENT_TARGET = 16.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.purelibrary.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphoneos;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				ARCHS = arm64;
				ONLY_ACTIVE_ARCH = NO;
				TARGETED_DEVICE_FAMILY = "1,2";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{project_cfg_list_id} /* Build configuration list for PBXProject "PureLibrary" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{project_debug_cfg_id} /* Debug */,
				{project_release_cfg_id} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{target_cfg_list_id} /* Build configuration list for PBXNativeTarget "PureLibrary" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{target_debug_cfg_id} /* Debug */,
				{target_release_cfg_id} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */

	}};
	rootObject = {project_id} /* Project object */;
}}
"""
    dest = os.path.join(project_dir, "PureLibrary.xcodeproj", "project.pbxproj")
    with open(dest, "w", encoding="utf-8") as f:
        f.write(pbx)
    print(f"Generated PBXProject at {dest}")

if __name__ == "__main__":
    generate_pbxproj(os.path.dirname(os.path.abspath(__file__)))

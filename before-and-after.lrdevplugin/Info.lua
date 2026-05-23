return {
    LrSdkVersion = 5.0,
    LrSdkMinimumVersion = 5.0,

    LrToolkitIdentifier = "com.beforeandafter.export",
    LrPluginName = "Before and After Export",

    LrPluginInfoProvider = "PluginInfoProvider.lua",

    LrLibraryMenuItems = {
        {
            title = "Export Before and After",
            file = "ExportBeforeAndAfter.lua",
        },
        {
            title = "Audit Metadata",
            file = "AuditMetadata.lua",
        },
        {
            title = "Go to Published Before",
            file = "GoToPublishedBefore.lua",
        },
        {
            title = "Go to Published After",
            file = "GoToPublishedAfter.lua",
        },
    },

    LrExportMenuItems = {
        {
            title = "Export Before and After",
            file = "ExportBeforeAndAfter.lua",
        },
    },

    LrExportServiceProvider = {
        title = "Before and After Publish",
        file = "PublishService.lua",
        id = "beforeandafter",
    },

    VERSION = { major = 1, minor = 0, revision = 0, display = "1.0.0" },
}

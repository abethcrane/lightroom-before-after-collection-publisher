return {
    LrSdkVersion = 5.0,
    LrSdkMinimumVersion = 5.0,

    LrToolkitIdentifier = "com.beforeandafter.export",
    LrPluginName = "Before and After Export",
    LrPluginInfoUrl = "https://github.com/abethcrane/lightroom-before-after-collection-publisher",

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
        {
            title = "Before and After Export",
            file = "ExportService.lua",
        },
        {
            title = "Before and After Publish",
            file = "PublishService.lua",
            id = "beforeandafter",
        },
    },

    VERSION = { major = 1, minor = 1, revision = 4, display = "1.1.4" },
}

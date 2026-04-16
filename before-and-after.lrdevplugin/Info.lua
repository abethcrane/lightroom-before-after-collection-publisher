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
            file = "TestMenu.lua",
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

    VERSION = { major = 0, minor = 3, revision = 0, display = "0.3.0" },
}

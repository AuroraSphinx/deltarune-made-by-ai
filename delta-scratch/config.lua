-- config.lua — game and build configuration
-- Edit this file to change window branding, identity, paths, and runtime defaults.
-- conf.lua requires this file before LÖVE's love.conf() runs so the title and
-- icon are correct during startup. The game code can also require it at runtime.
return {
    identity = "deltarune-made-by-ai",
    window = {
        title = "Deltarune made by AI",
        icon = "icon.png",
        bigicon = "bigicon.png",
        width = 640,
        height = 480,
        minwidth = 320,
        minheight = 240,
        resizable = true,
        vsync = true,
        highdpi = true,
        usedpiscale = false,
    },
    display = {
        virtual_width = 320,
        virtual_height = 240,
        integer_scaling = true,
        filter = "nearest",
    },
    audio = {
        master = 1.0,
        music = 0.8,
        sfx = 1.0,
    },
    paths = {
        fonts = "assets/fonts",
        characters = "assets/characters",
        enemies = "assets/enemies",
        npcs = "assets/npcs",
        ui = "assets/ui",
        audio = "assets/audio",
    },
    build = {
        archive = "deltarune.love",
        exe = "deltarune.exe",
        release_dir = "build/release",
    },
    love_version = "11.5",
    externalstorage = true,
    console = false,
}

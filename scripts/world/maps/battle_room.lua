return {
    version = "1.5",
    luaversion = "5.1",
    tiledversion = "1.10.2",
    orientation = "orthogonal",
    renderorder = "right-down",
    width = 16,
    height = 12,
    tilewidth = 40,
    tileheight = 40,
    nextlayerid = 2,
    nextobjectid = 2,
    properties = {name = "Battle Boot Room"},
    tilesets = {},
    layers = {
        {
            type = "objectgroup",
            draworder = "topdown",
            id = 1,
            name = "markers",
            visible = true,
            opacity = 1,
            offsetx = 0,
            offsety = 0,
            parallaxx = 1,
            parallaxy = 1,
            properties = {},
            objects = {
                {
                    id = 1,
                    name = "spawn",
                    type = "",
                    shape = "point",
                    x = 320,
                    y = 280,
                    width = 0,
                    height = 0,
                    rotation = 0,
                    visible = true,
                    properties = {}
                }
            }
        }
    }
}

require("mod-gui")

local unfulfilled_requests = {}
local NEWVERSION = false

script.on_configuration_changed(function() 
    for k,v in pairs(game.players) do
        local flow = mod_gui.get_button_flow(v)
        local button = flow['whats-missing-button']
        if (button and button.valid) then button.destroy() end
    end
end)

script.on_event(defines.events.on_gui_click, function(event)
    -- local buttonFlow = mod_gui.get_button_flow
    local button = event.element
    local ply = game.players[event.player_index]

    if (button.name == 'whats-missing-button') then
        if (ply.gui.screen['whats-missing-gui'] and
            ply.gui.screen['whats-missing-gui'].valid) then
            ply.gui.screen['whats-missing-gui'].destroy()
            return
        end
        -- game.print("Hello!")
        local frame = ply.gui.screen.add(
                          {
                name = "whats-missing-gui",
                type = "frame",
                caption = "What's Missing?",
                direction = "vertical"
            })
        local WIDTH = 300
        local HEIGHT = 400
        local res = ply.display_resolution
        local scl = ply.display_scale
        local scrollPaneFrame = frame.add(
                                    {
                name = "frame",
                type = "frame",
                style = "dark_frame",
                direction = "vertical"
            })
        local scrollPane = scrollPaneFrame.add(
                               {name = "scrollpane", type = "scroll-pane"})

        local refreshButton = frame.add({
            name = "whats-missing-refresh",
            type = "button",
            caption = "Refresh"
        })
        local closeButton = frame.add({
            name = "whats-missing-close",
            type = "button",
            caption = "Close"
        })
        frame.style.width = WIDTH
        frame.style.height = HEIGHT
        scrollPaneFrame.style.width = WIDTH - 25
        scrollPaneFrame.style.height = HEIGHT - 110
        scrollPane.style.width = WIDTH - 25
        scrollPane.style.horizontal_align = "center"
        scrollPane.style.vertical_align = "center"
        -- centering stuff
        frame.location = {
            (res.width / 2) - ((WIDTH / 2) * scl),
            (res.height / 2) - ((HEIGHT / 2) * scl)
        }

        updateGUI(ply, ply.gui.screen)

    elseif (button.name == "whats-missing-close" and
        ply.gui.screen['whats-missing-gui'] and
        ply.gui.screen['whats-missing-gui'].valid) then
        ply.gui.screen['whats-missing-gui'].destroy()

    elseif (button.name == 'whats-missing-refresh') then
        updateGUI(ply, ply.gui.screen)
    end

end)

script.on_nth_tick(120, function(event)
    checkGUIExistence()
end)



function checkGUIExistence()
    for k, ply in pairs(game.players) do
        local gui = ply.gui.top
        local buttonFlow = mod_gui.get_button_flow(ply)
        if (not buttonFlow['whats-missing-button']) then
            -- local button = gui.add()
            buttonFlow.add {
                type =      'sprite-button',
                style =     'mod_gui_button',
                name =      'whats-missing-button',
                sprite =    'whats-missing-button',
                tooltip =   "What's Missing?\nShow what's being requested and \nnot fulfilled in your logistics network.",
                -- caption = "What's Missing?\nShow what's being requested and not fulfilled in your logistics network."
            }

        end

    end

end

script.on_configuration_changed(function(event)

end)

function updateGUI(player, gui)
    if (not gui['whats-missing-gui'] or not gui['whats-missing-gui'].valid) then
        return
    end
    local scrollPane = gui['whats-missing-gui']['frame']['scrollpane']
    scrollPane.clear()

    local label

    -- if (not player.character) then

    --     label = scrollPane.add {
    --         name = 'label',
    --         caption = "You need to be a character, not god! :(",
    --         type = "label"
    --     }
    -- end


    local network = player.surface.find_logistic_network_by_position(player.position, player.force)
    if (not network) then
        label = scrollPane.add {
            name = 'label',
            caption = "You're not in a logistics network! :(",
            type = "label"
        }
    elseif (not logisticNetworkHasMembers(network)) then

        label = scrollPane.add {
            name = 'label',
            caption = "Your logistics network has no requester points! :(",
            type = "label"
        }

    elseif (not logisticNetworkHasRequests(network)) then
        label = scrollPane.add {
            name = 'label',
            caption = "Your logistics network has no requests! :(",
            type = "label"
        }
    elseif (logisticNetworkHasRequests(network)) then
        -- if (logistic)
        updateLogisticNetworkRequests(network)

        if (logisticNetworkHasUnfulfilledRequests(network)) then
            buildGUIList(player, scrollPane, network)
        else
            label = scrollPane.add {
                name = 'label',
                caption = "Your logistics network has no unfulfilled requests! :(",
                type = "label"
            }
        end
    end
    if (label) then
        label.style.horizontal_align = "center"
        -- 329, 314 ends up being parent content-size
        setGUISize(label, label.parent.style.maximal_width - 6)
    end
end

function logisticNetworkHasMembers(ln)
    for k, v in pairs(ln.requester_points) do
        if (v.owner.name ~= "character") then return true end
    end
    return false
end

function setGUISize(element, w, h)
    if (not element.style) then return end
    if (w) then element.style.width = w end
    if (h) then element.style.height = h end
end

function logisticNetworkHasRequests(ln)

    for k, v in pairs(ln.requester_points) do
        if (v.owner.name ~= "character") then
            -- __DebugAdapter.print(v.owner.name)
            if (v.filters == nil) then return false end;
            if (table_size(v.filters) > 0) then return true end
        end
    end
    return false
end

function updateLogisticNetworkRequests(ln)

    unfulfilled_requests[ln] = {}

    for k, v in pairs(ln.requester_points) do
        if (v.owner.name ~= "character") then
            if (v.filters and table_size(v.filters) > 0) then
                for k2, v2 in pairs(v.filters) do
                    local count = v2.count
                    if (v.targeted_items_deliver[v2.name] ~= nil) then
                        count = count - v.targeted_items_deliver[v2.name]
                    end
                    local networkCount = ln.get_item_count(v2.name)
                    local containerCount = v.owner.get_item_count(v2.name)
                    count = count - networkCount - containerCount

                    if (count > 0) then
                        addItemToUnfulfilledRequests(ln, v2.name, count)
                    end
                end
            end
        end
    end
end

function buildGUIList(player, basegui, network) 
    
    for k,v in pairs(unfulfilled_requests[network]) do
        local itemProto = game.item_prototypes[k]
        -- local itemProto = game.item_prototypes[k].name
        -- local localeName = player.request_translation()
        local itemflow = basegui.add({name=k .. "-flow", type="flow", direction = "horizontal"})
        local itemsprite = itemflow.add({name=k..'-sprite', type='sprite'})
        local itemlabel = itemflow.add({name='itemlabel', type='label', caption = {"", itemProto.localised_name, '\nMissing: ' .. v}})

        itemflow.style.vertical_align = "center"
        itemsprite.sprite = 'item/' .. k
        itemlabel.style.single_line = false
        itemlabel.style.vertical_align = "center"
        local line = basegui.add({type="line", direction="horizontal"})
        
    end
end

function addItemToUnfulfilledRequests(network, item, count)
    if (not unfulfilled_requests[network]) then
        unfulfilled_requests[network] = {}
    end
    local reqItem = unfulfilled_requests[network][item]
    if (reqItem == nil) then
        unfulfilled_requests[network][item] = count
    else
        unfulfilled_requests[network][item] = count + reqItem
    end
end

function logisticNetworkHasUnfulfilledRequests(network)
    if (unfulfilled_requests[network] == nil) then
        return false
    end
    return table_size(unfulfilled_requests[network]) > 0
end

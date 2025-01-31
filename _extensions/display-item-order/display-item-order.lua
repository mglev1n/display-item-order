local function parse_crossref_metadata(meta)
    local crossref = meta.crossref or {}
    local float_types = {}
    
    -- Default figures
    local fig_section = "Figures"
    if crossref['fig-prefix'] then
        fig_section = pandoc.utils.stringify(crossref['fig-prefix']) .. "s"
    end
    table.insert(float_types, {
        key = "fig",
        id_prefix = "fig-",
        section_title = fig_section
    })

    -- Default tables
    local tbl_section = "Tables"
    if crossref['tbl-prefix'] then
        tbl_section = pandoc.utils.stringify(crossref['tbl-prefix']) .. "s"
    end
    table.insert(float_types, {
        key = "tbl",
        id_prefix = "tbl-",
        section_title = tbl_section
    })

    -- Custom float entries
    if crossref.custom then
        for _, entry in ipairs(crossref.custom) do
            if pandoc.utils.stringify(entry.kind or '') == 'float' then
                local key = pandoc.utils.stringify(entry.key or '')
                local ref_prefix = pandoc.utils.stringify(entry['reference-prefix'] or '')
                if key ~= '' and ref_prefix ~= '' then
                    table.insert(float_types, {
                        key = key,
                        id_prefix = key .. '-',
                        section_title = ref_prefix .. 's'
                    })
                end
            end
        end
    end

    return float_types
end

-- New function to get ordered float types based on section-order
local function get_ordered_float_types(float_types, meta)
    local section_order = meta['display-item-order']
    if not section_order then
        return float_types
    end

    -- Convert section order to string array
    local order = {}
    for i, item in ipairs(section_order) do
        order[i] = pandoc.utils.stringify(item)
    end

    -- Create lookup table for float types
    local float_lookup = {}
    for _, ft in ipairs(float_types) do
        float_lookup[ft.key] = ft
    end

    -- Check for duplicate keys in display-item-order
    local seen_keys = {}
    for _, key in ipairs(order) do
        if seen_keys[key] then
            error(string.format("Duplicate key '%s' found in display-item-order", key))
        end
        seen_keys[key] = true
    end

    -- Validate all keys in display-item-order exist in float types
    for _, key in ipairs(order) do
        if not float_lookup[key] then
            error(string.format("Key '%s' in display-item-order not found in crossref configuration", key))
        end
    end

    -- Create ordered array based on display-item-order
    local ordered_types = {}
    for _, key in ipairs(order) do
        table.insert(ordered_types, float_lookup[key])
        float_lookup[key] = nil  -- Mark as used
    end

    -- Add any remaining float types that weren't in the order
    for _, ft in ipairs(float_types) do
        if float_lookup[ft.key] then
            table.insert(ordered_types, ft)
        end
    end

    return ordered_types
end

function Pandoc(doc)
    local float_types = parse_crossref_metadata(doc.meta)
    -- Get ordered float types
    float_types = get_ordered_float_types(float_types, doc.meta)
    local sections = {}
    local collected = {}

    -- Initialize sections
    for _, ft in ipairs(float_types) do
        sections[ft.section_title] = {}
    end

    -- Recursive function to process blocks
    local function process_blocks(blocks)
        local new_blocks = {}
        for _, block in ipairs(blocks) do
            if block.t == "Div" then
                local should_collect = false
                local section_title = nil

                -- Check direct Div ID
                local div_id = block.identifier or ''
                for _, ft in ipairs(float_types) do
                    if div_id:match('^' .. ft.id_prefix) then
                        section_title = ft.section_title
                        should_collect = true
                        break
                    end
                end

                -- Check nested in cell-output-display
                if not should_collect and block.classes:includes('cell-output-display') then
                    for _, child in ipairs(block.content) do
                        if child.t == "Div" then
                            local child_id = child.identifier or ''
                            for _, ft in ipairs(float_types) do
                                if child_id:match('^' .. ft.id_prefix) then
                                    section_title = ft.section_title
                                    should_collect = true
                                    break
                                end
                            end
                            if should_collect then break end
                        end
                    end
                end

                if should_collect then
                    table.insert(sections[section_title], block)
                else
                    -- Recurse into Div content
                    block.content = process_blocks(block.content)
                    table.insert(new_blocks, block)
                end
            else
                -- Recurse into other block types
                if block.content and (block.t == "BlockQuote" or block.t == "OrderedList" or 
                   block.t == "BulletList" or block.t == "Div") then
                    block.content = process_blocks(block.content)
                end
                table.insert(new_blocks, block)
            end
        end
        return new_blocks
    end

    -- Process document blocks and collect floats
    local processed_blocks = process_blocks(doc.blocks)

    -- Build final document with collected sections in specified order
    local final_blocks = processed_blocks
    for _, ft in ipairs(float_types) do
        if #sections[ft.section_title] > 0 then
            table.insert(final_blocks, pandoc.Header(2, ft.section_title))
            for _, elem in ipairs(sections[ft.section_title]) do
                table.insert(final_blocks, elem)
            end
        end
    end

    return pandoc.Pandoc(final_blocks, doc.meta)
end
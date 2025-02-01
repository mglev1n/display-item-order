-- Cross-reference filter for HTML and DOCX outputs
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
        section_title = fig_section,
        should_move = false,  -- Will be set based on display-item-order
        order = 0            -- Will be set based on display-item-order
    })

    -- Default tables
    local tbl_section = "Tables"
    if crossref['tbl-prefix'] then
        tbl_section = pandoc.utils.stringify(crossref['tbl-prefix']) .. "s"
    end
    table.insert(float_types, {
        key = "tbl",
        id_prefix = "tbl-",
        section_title = tbl_section,
        should_move = false,
        order = 0
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
                        section_title = ref_prefix .. 's',
                        should_move = false,
                        order = 0
                    })
                end
            end
        end
    end

    return float_types
end

local function mark_float_types_to_move(float_types, meta)
    local section_order = meta['display-item-order']
    if not section_order then
        return float_types
    end

    -- Convert order to lookup table with position
    local order_lookup = {}
    for pos, item in ipairs(section_order) do
        local key = pandoc.utils.stringify(item)
        order_lookup[key] = pos
    end

    -- Mark which float types should be moved and set their order
    local move_list = {}
    local keep_list = {}
    for _, ft in ipairs(float_types) do
        local order_pos = order_lookup[ft.key]
        if order_pos then
            ft.should_move = true
            ft.order = order_pos
            table.insert(move_list, ft.section_title)
        else
            ft.order = math.huge  -- Set to highest possible value for non-moved items
            table.insert(keep_list, ft.section_title)
        end
    end

    -- Log configuration
    if #move_list > 0 then
        io.stderr:write("[display-item-order] Moving sections: " .. table.concat(move_list, ", ") .. "\n")
    end
    if #keep_list > 0 then
        io.stderr:write("[display-item-order] Keeping in place: " .. table.concat(keep_list, ", ") .. "\n")
    end

    return float_types
end

-- Helper function to find float divs in a block
local function find_float_div(block, float_types)
    -- Direct match for div id
    if block.t == "Div" and block.identifier then
        for _, ft in ipairs(float_types) do
            if block.identifier:match("^" .. ft.id_prefix) then
                return block, ft.section_title, ft.should_move
            end
        end
    end
    
    -- Search in cell-output-display for HTML
    if block.t == "Div" and block.classes and block.classes:includes('cell-output-display') then
        for _, child in ipairs(block.content or {}) do
            if child.t == "Div" then
                for _, ft in ipairs(float_types) do
                    if child.identifier:match("^" .. ft.id_prefix) then
                        return block, ft.section_title, ft.should_move
                    end
                end
            end
        end
    end
    
    -- Search in Table cells for DOCX
    if block.t == "Table" then
        for _, body in ipairs(block.bodies or {}) do
            for _, row in ipairs(body.body or {}) do
                for _, cell in ipairs(row.cells or {}) do
                    for _, content in ipairs(cell.contents or {}) do
                        if content.t == "Div" and content.identifier then
                            for _, ft in ipairs(float_types) do
                                if content.identifier:match("^" .. ft.id_prefix) then
                                    return block, ft.section_title, ft.should_move
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return nil, nil, false
end

local function process_blocks(blocks, float_types)
    local main_blocks = {}
    local float_blocks = {}
    local float_counts = {}
    
    for _, block in ipairs(blocks) do
        local float_block, section, should_move = find_float_div(block, float_types)
        
        if float_block and section then
            if should_move then
                float_blocks[section] = float_blocks[section] or {}
                float_counts[section] = (float_counts[section] or 0) + 1
                table.insert(float_blocks[section], float_block)
            else
                -- Keep non-moved floats in their original position
                table.insert(main_blocks, float_block)
            end
        else
            if block.content then
                -- Process nested content
                local nested_main, nested_floats, nested_counts = process_blocks(block.content, float_types)
                block.content = nested_main
                
                -- Merge nested floats and counts
                for section, blocks in pairs(nested_floats) do
                    float_blocks[section] = float_blocks[section] or {}
                    for _, b in ipairs(blocks) do
                        table.insert(float_blocks[section], b)
                    end
                    float_counts[section] = (float_counts[section] or 0) + (nested_counts[section] or 0)
                end
            end
            table.insert(main_blocks, block)
        end
    end
    
    return main_blocks, float_blocks, float_counts
end

function Pandoc(doc)
    -- Check document format first
    if not (quarto.doc.is_format("docx") or quarto.doc.is_format("html")) then
        io.stderr:write("[display-item-order] WARNING: This filter is only compatible with DOCX and HTML outputs.\n")
        return doc
    end
    
    local float_types = parse_crossref_metadata(doc.meta)
    float_types = mark_float_types_to_move(float_types, doc.meta)
    
    -- Process all blocks
    local main_blocks, float_blocks, float_counts = process_blocks(doc.blocks, float_types)
    
    -- Build final document
    local final_blocks = main_blocks
    
    -- Sort float_types by order
    table.sort(float_types, function(a, b) return a.order < b.order end)
    
    -- Add float sections in sorted order (only for those in display-item-order)
    for _, ft in ipairs(float_types) do
        if ft.should_move then
            local section_blocks = float_blocks[ft.section_title]
            if section_blocks and #section_blocks > 0 then
                io.stderr:write(string.format("[display-item-order] Moving %d items to '%s'\n",
                    float_counts[ft.section_title], ft.section_title))
                table.insert(final_blocks, pandoc.Header(2, ft.section_title))
                for _, block in ipairs(section_blocks) do
                    table.insert(final_blocks, block)
                end
            end
        end
    end
    
    return pandoc.Pandoc(final_blocks, doc.meta)
end
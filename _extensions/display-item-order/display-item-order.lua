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

    -- Log configured float types
    io.stderr:write("[display-item-order] Configured sections: ")
    local sections = {}
    for _, ft in ipairs(float_types) do
        table.insert(sections, ft.section_title)
    end
    io.stderr:write(table.concat(sections, ", ") .. "\n")

    return float_types
end

local function get_ordered_float_types(float_types, meta)
    local section_order = meta['display-item-order']
    if not section_order then
        return float_types
    end

    local order = {}
    for i, item in ipairs(section_order) do
        order[i] = pandoc.utils.stringify(item)
    end

    local float_lookup = {}
    for _, ft in ipairs(float_types) do
        float_lookup[ft.key] = ft
    end

    local ordered_types = {}
    for _, key in ipairs(order) do
        if float_lookup[key] then
            table.insert(ordered_types, float_lookup[key])
            float_lookup[key] = nil
        end
    end

    -- Add any remaining types
    for _, ft in ipairs(float_types) do
        if float_lookup[ft.key] then
            table.insert(ordered_types, ft)
        end
    end

    return ordered_types
end

-- Helper function to find float divs in a block
local function find_float_div(block, float_types)
    -- Direct match for div id
    if block.t == "Div" and block.identifier then
        for _, ft in ipairs(float_types) do
            if block.identifier:match("^" .. ft.id_prefix) then
                return block, ft.section_title
            end
        end
    end
    
    -- Search in cell-output-display for HTML
    if block.t == "Div" and block.classes and block.classes:includes('cell-output-display') then
        for _, child in ipairs(block.content or {}) do
            if child.t == "Div" then
                for _, ft in ipairs(float_types) do
                    if child.identifier:match("^" .. ft.id_prefix) then
                        return block, ft.section_title
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
                                    return block, ft.section_title
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return nil, nil
end

local function process_blocks(blocks, float_types)
    local main_blocks = {}
    local float_blocks = {}
    local float_counts = {}
    
    for _, block in ipairs(blocks) do
        local float_block, section = find_float_div(block, float_types)
        
        if float_block and section then
            float_blocks[section] = float_blocks[section] or {}
            float_counts[section] = (float_counts[section] or 0) + 1
            table.insert(float_blocks[section], float_block)
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
    local float_types = parse_crossref_metadata(doc.meta)
    float_types = get_ordered_float_types(float_types, doc.meta)
    
    -- Process all blocks
    local main_blocks, float_blocks, float_counts = process_blocks(doc.blocks, float_types)
    
    -- Build final document
    local final_blocks = main_blocks
    
    -- Add float sections in order
    for _, ft in ipairs(float_types) do
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
    
    return pandoc.Pandoc(final_blocks, doc.meta)
end
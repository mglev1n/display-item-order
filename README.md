# display-item-order

A Quarto extension that collects and organizes figures, tables, and other cross-referenced items at the end of your document. This extension was designed with academic writing in mind, where display items are frequently organized at the end of a document. Future versions may include more customization options for ordering, styling, and ignoring certain cross-referenced items.

## Installing

```bash
quarto add mglev1n/display-item-order
```

This will install the extension under the `_extensions` subdirectory.

## Using

> [!IMPORTANT]  
> Make sure to list the filters in the correct order: 'quarto' must come before 'display-item-order' in your YAML configuration.

### Basic Usage: Moving Selected Display Items

By default, all cross-referenced items remain in their original positions in the document. You can specify which items to move to the end using the `display-item-order` option:

````qmd
---
title: "My Document"
filters:
  - quarto
  - display-item-order
display-item-order:
  - fig    # Move figures to the end
---
## Introduction
Here's a reference to our figure (@fig-example) and table (@tbl-data).

```{r}
#| label: fig-example
#| fig-cap: "An example figure"
plot(cars)
```

```{r}
#| label: tbl-data
#| tbl-cap: "An example table"
pressure
```

## Results
More text here...
````

In this example, only figures will be moved to the end of the document under a "Figures" section. Tables will remain in their original positions.

### Organizing Multiple Section Types

You can specify multiple types of items to move and control their order:

```yaml
---
title: "My Document"
filters:
  - quarto
  - display-item-order
display-item-order:
  - tbl    # Move tables to end first
  - fig    # Move figures to end second
---
```

Any cross-referenced items not listed in `display-item-order` will remain in their original positions in the document.

### Advanced: Custom Cross-references

For more complex documents, you can define custom cross-reference types and control their organization:

````qmd
---
title: "My Document"
filters:
  - quarto
  - display-item-order
crossref:
  fig-prefix: Figure            # Regular figures
  custom:
    - kind: float
      key: suppfig             # Key for ordering
      reference-prefix: "Supplementary Figure"
    - kind: float
      key: etbl               # Key for ordering
      reference-prefix: "Extended Table"
    - kind: float
      key: efig               # Key for ordering
      reference-prefix: "Extended Figure"
display-item-order:
  - fig      # Move regular figures to end
  - suppfig  # Move supplementary figures after regular figures
---

## Introduction
This paper includes regular figures (@fig-main), extended tables (@etbl-data), 
supplementary figures (@suppfig-additional), and extended figures (@efig-extra).

```{r}
#| label: fig-main
#| fig-cap: "Main analysis"
plot(cars)
```

::: {#suppfig-additional}
```{r}
#| fig-cap: "Supplementary analysis"
plot(pressure)
```
:::

::: {#etbl-data}
```{r}
#| tbl-cap: "Extended data table"
pressure
```
:::

::: {#efig-extra}
```{r}
#| fig-cap: "Extended figure"
plot(cars)
```
:::
````

In this example:
- Regular figures and supplementary figures will be moved to the end
- Extended tables and extended figures will remain in their original positions
- The moved items will be organized in the specified order (regular figures, then supplementary figures)

## Validation

The extension includes validation to ensure:
1. All keys in `display-item-order` correspond to defined cross-reference types
2. No duplicate keys exist in `display-item-order`

For example, this configuration would generate an error:
```yaml
display-item-order:
  - fig
  - unknown-type  # Error: key not found in crossref configuration
  - fig           # Error: duplicate key
```

## How It Works

The extension:

1. Processes your document after rendering (post-render)
2. Identifies cross-referenced items based on their prefixes
3. For items specified in `display-item-order`:
   - Collects these items while preserving their order within sections
   - Creates sections at the end of your document
   - Places items in their respective sections according to the specified order
4. All other cross-referenced items remain in their original positions

## Use Cases

This extension is particularly useful for:

- Academic papers requiring specific figures at the end while keeping other display items in-line
- Documents with supplementary materials that need specific organization
- Any document where you want to control which display items appear at the end versus in-line with the text

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
# display-item-order

A Quarto extension that collects and organizes figures, tables, and other cross-referenced items at the end of your document. This extension was designed with academic writing in mind, where these display items are frequently organized at the end of a document. Future versions may include more customization options for ordering, styling, and ignoring certain cross-referenced items.

## Installing

```bash
quarto add username/display-item-order
```

This will install the extension under the `_extensions` subdirectory.

## Using

> [!IMPORTANT]
> Make sure to list the filters in the correct order: 'quarto' must come before 'display-item-order' in your YAML configuration.

### Basic Usage: Collecting Figures and Tables

By default, this extension will collect all figures and tables with cross-references (prefixed with `fig-` and `tbl-`) and place them at the end of your document in sections titled "Figures" and "Tables".

````qmd
---
title: "My Document"
filters:
  - quarto
  - display-item-order
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

The output will automatically move the figure and table to the end of the document under their respective sections, while maintaining all cross-references.

### Customizing Section Order

You can control the order of sections using the `display-item-order` option:

```yaml
---
title: "My Document"
filters:
  - quarto
  - display-item-order
display-item-order:
  - tbl    # Tables first
  - fig    # Figures second
---
```

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
display-item-order:
  - fig      # Regular figures first
  - etbl     # Extended tables second
  - suppfig  # Supplementary figures last
---

## Introduction

This paper includes regular figures (@fig-main), extended tables (@etbl-data), 
and supplementary figures (@suppfig-additional).

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
````

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
3. Collects these items while preserving their order within sections
4. Creates sections at the end of your document
5. Places items in their respective sections according to `display-item-order` (if specified). If a key is not explicitly specified in `display-item-order`, it will be placed at the end.

## Use Cases

This extension is particularly useful for:

- Academic papers requiring figures and tables at the end
- Documents with supplementary materials that need specific organization
- Any document where you want to separate content from supporting visuals

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

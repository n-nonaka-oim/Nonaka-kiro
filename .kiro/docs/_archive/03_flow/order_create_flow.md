# Order Create Flow - /Material/Orders/Create

## Overview
Raw material order entry with suggest search, temporary entry table, and batch submission.

## Flow Diagram

```
[User] -> Input item code/name
    |
    v
[Suggest Search] (300ms debounce, top 20, code/name/short_name match)
    |
    v
[Select Item] -> Auto-fill: content_qty, package_type, delivery_days,
                             default_order_qty, supplier, warehouse
    |
    v
[Modify if needed] -> qty, delivery_date, supplier, warehouse, remarks
    |
    v
[Entry Add] -> t_order_entries (per-user temporary table)
    |           If qty != default_order_qty -> confirm dialog
    |           If confirmed -> update m_items.default_order_qty
    |
    v
[Entry List] -> Checkbox selection, sort by date/delivery
    |
    v
[Submit Selected] -> t_order_entries -> t_orders (status: Pending)
                     t_order_entries.is_submitted = true
```

## Page: /Material/Orders/Create

### Input Form
| Field | Type | Source | Required |
|---|---|---|---|
| Item Code | Text + Suggest | m_items (SearchSuggest) | Yes |
| Quantity | Number | m_items.default_order_qty (auto) | Yes |
| Delivery Date | Date | today + default_delivery_days (auto) | No |
| Supplier | Dropdown | m_suppliers (FactoryDb) | No |
| Warehouse | Dropdown | m_warehouses (FactoryDb) | No |
| Remarks | Text | User input | No |

### Auto-fill on Item Select
| Display | Source |
|---|---|
| Content Qty + Unit | m_items.content_qty + content_unit |
| Package Type | m_package_types.package_type_name |
| Default Delivery Days | m_items.default_delivery_days |
| Qty x Content = Total | JavaScript calculation |

### Entry List
| Column | Source | Feature |
|---|---|---|
| Checkbox | - | Select for submission |
| No | Sequential | - |
| Date | t_order_entries.created_at | Sortable |
| Item Code | t_order_entries.item_code | - |
| Item Name | t_order_entries.item_name | - |
| Quantity | t_order_entries.order_qty | F2 format |
| Delivery | t_order_entries.delivery_date | Sortable |
| Supplier | t_order_entries.supplier_name | - |
| Remarks | t_order_entries.remarks | - |
| Delete | Button | Remove entry |

### Actions
| Button | Handler | Description |
|---|---|---|
| Entry Add | OnPostAddAsync | Save to t_order_entries |
| Submit Selected | OnPostSubmitAsync | Move selected to t_orders |
| Delete | OnPostRemoveAsync | Remove from t_order_entries |
| Select All | JavaScript | Toggle all checkboxes |

### Default Qty Update
- On entry add, if qty differs from default_order_qty
- Browser confirm dialog: "qty / defQty - Update default?"
- If confirmed: m_items.default_order_qty updated via IMasterService.UpdateDefaultOrderQtyAsync

## Technical Details

### Services Used
| Service | Method | Purpose |
|---|---|---|
| IOrderEntryService | AddEntryAsync | Add to temp table |
| IOrderEntryService | GetEntriesAsync | List user entries |
| IOrderEntryService | RemoveEntryAsync | Delete entry |
| IOrderEntryService | SubmitEntriesAsync | Batch submit to t_orders |
| IMasterService | SearchItemsAsync | Suggest search |
| IMasterService | GetItemDetailAsync | Item detail for auto-fill |
| IMasterService | UpdateDefaultOrderQtyAsync | Update default qty |
| IMasterService | GetActiveSuppliersAsync | Supplier dropdown |
| IMasterService | GetActiveWarehousesAsync | Warehouse dropdown |

### JavaScript Features
- Debounce (300ms) for suggest search
- Keyboard navigation (Arrow Up/Down, Enter, Escape)
- Qty x Content calculation display
- Select all checkbox
- Selected IDs injection on submit
- Confirm dialog for default qty update

### URL Handling
- Fetch URLs use `@Url.Page()` for dynamic path base (/AuthTest)
- Named handlers: SearchSuggest, ItemDetail

### Files
- `MaterialModule/Areas/Material/Pages/Orders/Create.cshtml`
- `MaterialModule/Areas/Material/Pages/Orders/Create.cshtml.cs`
- `MaterialModule/Services/IOrderEntryService.cs`
- `MaterialModule/Services/OrderEntryService.cs`
- `MaterialModule/Services/IMasterService.cs`
- `MaterialModule/Services/MasterService.cs`
- `MaterialModule/Data/Entities/TOrderEntry.cs`

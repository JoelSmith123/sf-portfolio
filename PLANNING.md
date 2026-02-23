# PLANNING.md — Life Sciences Portfolio Project

## Architecture Decisions

### Shared Data Model
All three portfolio pieces share `Drug_Product__c` — a pharma-appropriate custom object with 17 fields tracking pharmaceutical products through their FDA regulatory lifecycle. This makes the project feel like a coherent vertical slice rather than three disconnected demos.

### Portfolio Piece 1: OpenFDA REST API Integration
- **API choice:** OpenFDA Drug Labeling API (free, no auth, real pharmaceutical data)
- **Pattern:** Service class (`OpenFDAService`) with clean separation — HTTP callout, JSON parsing, and record mapping in separate private methods
- **Error handling:** Custom exception (`OpenFDAException`) for all failure modes — 404 (not found), 429 (rate limit), server errors, timeouts, malformed JSON, missing sub-objects
- **Enrichment logic:** Brand name search first, falls back to generic name. Identity fields preserved if already populated; data fields always updated from FDA as authoritative source
- **Test strategy:** `HttpCalloutMock` with realistic JSON payloads, multi-callout mock for fallback scenario, 14 test methods

### Portfolio Piece 2: Custom LWC Data Table
- **Architecture:** Wire adapter (`cacheable=true`) for reactive data fetching, imperative call for DML save
- **Search:** 300ms debounced input filtering across 5 fields server-side via SOQL LIKE
- **Sorting:** Client-side sort on frozen wire data (shallow copy pattern)
- **Inline editing:** Text fields only (Product Name, Generic Name, Strength, Manufacturer) — picklist fields are read-only due to platform `lightning-datatable` limitation
- **Apex controller:** Separate from service classes, top-level `classes/` directory

### Portfolio Piece 3: Mini Rules Engine
- **Metadata-driven:** `Validation_Rule__mdt` custom metadata type with 8 fields including conditional dependency pattern
- **Dependency pattern:** `Dependent_Field__c` / `Dependent_Value__c` enables rules like "when Status = Approved, then FDA Date must not be blank" — no hardcoded logic
- **Engine design:** Generic `evaluate()` method works against any SObject; `validateAndAddErrors()` convenience method for trigger context
- **Trigger:** Intentionally thin dispatch layer — zero business logic in the trigger itself
- **Operators:** equals, not_equals, is_blank, is_not_blank, greater_than, less_than, contains

## File Organization
```
force-app/main/default/
  classes/
    apiintegration/          # OpenFDA service, result wrapper, exception, test
    rulesengine/             # Validation engine, result wrapper, test
    DrugProductController    # LWC Apex controller + test
  lwc/
    drugProductDataTable/    # Data table LWC (html, js, css, meta)
  objects/
    Drug_Product__c/         # Custom object + 17 fields + compact layout + list view
    Validation_Rule__mdt/    # Custom metadata type + 8 fields
  customMetadata/            # 3 validation rule records
  triggers/                  # DrugProductTrigger
  remoteSiteSettings/        # OpenFDA API endpoint
  permissionsets/            # Drug_Product_Access
  tabs/                      # Drug_Product__c tab
```

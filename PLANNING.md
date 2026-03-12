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

## Feature Expansion: Interactive LWC + Admin Rules Console + Flows

### Overview
Phase 1–6 expansion weaves the three portfolio features into a coherent interactive application.
All three features now share a connected story: edit a record → see validation feedback → fetch from FDA → watch badges update → admins can tweak rules without deploying.

### Phase 1: Data Foundation (✅ Complete)
**Architecture decisions:**
- `Rule_Override__c` custom object stores runtime rule overrides (admin-writable at runtime, as opposed to `Validation_Rule__mdt` which requires deployment to change)
- Three override actions: `Suppress` (skip rule), `Override_Message` (custom error text), `Downgrade_To_Warning` (non-blocking UI warning)
- `cachedPermSetNames` static variable in `ValidationRuleEngine` prevents repeated SOQL in bulk trigger context
- `@TestVisible` cache injection pattern for isolated unit testing of override behavior
- `Drug_Product_Admin` permission set intentionally omits FLS for required fields (Salesforce won't allow deploying FLS on `required=true` fields)

**Known Apex gotcha: `override` is a reserved keyword** — variable renamed to `ruleOverride` throughout.

**Known metadata gotcha: `enableBulkApi`, `enableSharing`, `enableStreamingApi` must all be set consistently** (all true) on `Rule_Override__c`.

### Phase 2: Apex Service Layer (✅ Complete)
**New classes:**
- `ValidationRuleDefinition` (rulesengine/) — wire-serializable wrapper for `Validation_Rule__mdt` + per-user override context (isSuppressedForUser, isDowngradedToWarning, overrideMessage)
- `DrugProductValidationWrapper` (rulesengine/) — wraps Drug_Product__c + bulk validation results for health badge column
- `DrugProductEnrichmentController` (apiintegration/) — 4 methods: `getActiveRulesForCurrentUser`, `previewFDAEnrichment` (read-only, no DML), `evaluateRecord`, `enrichAndSave`
- `DrugProductAdminController` (rulesengine/) — CRUD on Rule_Override__c gated by `Manage_Validation_Rules` custom permission; uses `@TestVisible skipPermissionCheckForTest` flag
- `DrugProductFlowController` (apiintegration/) — `@InvocableMethod createDrugProduct` for Screen Flow
- `DrugProductFDAFlowAction` (apiintegration/) — `@InvocableMethod searchFDAForFlow` (read-only FDA preview)
- `DrugProductValidationFlowAction` (rulesengine/) — `@InvocableMethod runValidationCheck` for Record-Triggered Flow
- Updated `DrugProductController` — added `getDrugProductsWithValidation()` returning `List<DrugProductValidationWrapper>`

**Design decisions:**
- One `@InvocableMethod` per class (Salesforce hard limit regardless of API version)
- `evaluateRecord()` uses `JSON.serialize/deserialize` to convert `Map<String, Object>` → `Drug_Product__c` — handles date string coercion automatically
- `previewFDAEnrichment()` deliberately has no DML — safe to call from LWC without triggering the trigger; DML enrichment is a separate `enrichAndSave()` method
- `AuraHandledException.getMessage()` always returns "Script-thrown exception" in Apex test context — tests for permission-gated paths verify exception type thrown, not message content

**Test coverage: 88/88 passing (100%)**

### Phase 3: drugProductWorkbench + validationBadgeList LWCs (✅ Complete)
**New components:**
- `validationBadgeList` (lwc/) — reusable child component; `@api errors` array; renders error badges (red left border) and warning badges (amber left border) from `ValidationResult` objects; shows green "All validation rules pass" when array is empty; `isExposed: false` (internal child only)
- `drugProductWorkbench` (lwc/) — centerpiece record-page component with two-panel layout (8/12 form + 4/12 validation panel)

**drugProductWorkbench UX loop:**
1. View mode shows `lightning-record-view-form` with all 17 fields
2. "Edit" → enters edit mode; live validation panel appears; all fields are editable inputs
3. Any field change triggers `_evaluateRulesClientSide()` — pure JS operator evaluation (no Apex round-trip) using rules loaded once by `@wire(getActiveRulesForCurrentUser)`
4. "Fetch from FDA" → calls `previewFDAEnrichment()` → FDA diff table appears with Current / Proposed / Accept columns; user checks individual fields
5. "Apply Selected Changes" → accepted proposals merge into `editState`; validation re-runs
6. "Save" → calls `evaluateRecord()` as server-side gate; if clean, `updateRecord()` via LDS; `getRecordNotifyChange()` to refresh

**Key JS design decisions:**
- `_evaluateOperator()` mirrors Apex `evaluateOperator()` exactly: `null → ''` (blank), `false → 'false'` (not blank), string whitespace → blank; `contains` uses `toLowerCase` to match `containsIgnoreCase`
- `editState` is always reassigned (spread operator) to trigger LWC reactivity without `@track`
- `_fdaAcceptedFields` stored as `{ fieldName: boolean }` plain object (not `Set`) — reassigned on toggle so `fdaProposalRows` getter recomputes
- `Last_FDA_Sync__c` excluded from `evaluateRecord` and `updateRecord` payloads (read-only DateTime field — Apex `JSON.deserialize` would reject empty strings)
- `wiredRecord` skips `editState` update when `isEditing=true` to avoid clobbering user in-progress edits
- `handleFieldChange` uses `data-type="checkbox"` attribute to distinguish `event.detail.checked` from `event.detail.value` across all input types

**Flexipage note:** `Drug_Product_Record_Page.flexipage-meta.xml` is present in source but excluded from the initial deploy — the Developer Edition org doesn't have the `flexipage:recordHomeFlexibleTemplate` template. The `drugProductWorkbench` component appears in Lightning App Builder (isExposed=true, target=RecordPage, object=Drug_Product__c) and can be added to the Drug Product record page manually. File is committed for documentation and future org migration.

**Test coverage: 88/88 Apex tests passing (100%). LWC components have no server-side Apex to test.**

### Phase 4: ruleAdminConsole + ruleMetadataTable + ruleOverrideEditor LWCs (✅ Complete)
**New components:**
- `ruleAdminConsole` — permission-gated admin shell; uses `@salesforce/customPermission/Manage_Validation_Rules` (evaluated once at load, no wire needed); `isExposed: true`, target `lightning__AppPage`; shows amber info banner + two child cards; shows Access Denied illustration for non-admins
- `ruleMetadataTable` — stateless read-only table; `@api rules = []`; `processedRules` getter maps CMT records to template objects with `key`, `label`, `fieldName`, `operator`, `value`, `errorMessage`, `condition`, `isActive`; 7 SLDS columns with horizontal scroll; monospace operator badge
- `ruleOverrideEditor` — full CRUD for `Rule_Override__c`; wires `getAllOverrides` (cacheable=false) + `getPermissionSetNames`; `refreshApex` after every save/delete; SLDS modal form; `blankDraft()` factory for clean state resets; `ACTION_HELP` map for contextual help text per Override_Action__c value; param `override` (renamed from `ruleOverride` due to Apex reserved word)

**Flexipage:**
- `Drug_Product_Admin_Page.flexipage-meta.xml` — uses `flexipage:defaultAppHomeTemplate` (confirmed available in Developer Edition); deploys cleanly

**Test coverage: 88/88 Apex tests passing (100%)**

### Phase 5: Enhanced drugProductDataTable (✅ Complete)
**Changes to existing component:**
- Switched `@wire` from `getDrugProducts` to `getDrugProductsWithValidation` (cacheable=false); maps each `DrugProductValidationWrapper` to a flat record object with computed `validationStatusLabel` and `validationStatusIcon` fields for the Health column
- Added Health column: `cellAttributes.iconName: { fieldName: 'validationStatusIcon' }` + text label; shows utility:check/warning/error icons per validation status
- Added `Patent_Expiry_Alert__c` boolean column
- Added row-level "Fetch FDA Data" action: calls `enrichAndSave({ recordId })` then `refreshApex`
- Added "New Drug Product" button in card header using `NavigationMixin.Navigate` → `standard__objectPage` new action
- Extended class declaration: `NavigationMixin(LightningElement)`

### Phase 6: Two Salesforce Flows (✅ Complete)
**New flows:**

`New_Drug_Product_Wizard.flow-meta.xml` (Screen Flow, `processType: Flow`)
- 4 screens: Basic Info → (optional) FDA Preview → Regulatory Details → Review
- 2 Apex actions: `DrugProductFDAFlowAction.searchFDAForFlow` + `DrugProductFlowController.createDrugProduct`
- 2 decisions: FDA Found? / Create Success?
- 3 formula defaults: pre-fill Manufacturer/NDC/Active Ingredients from FDA if accepted
- FDA acceptance checkboxes (Screen_FDAPreview) feed formulas used as `defaultValue` on Screen_RegulatoryDetails
- On success: displays Record ID; on error: displays exception message with Back to retry
- Launch: add as a Quick Action or utility bar item on the Drug Product object

`Drug_Product_Patent_Expiry_Flag.flow-meta.xml` (Record-Triggered, After Save, `processType: AutoLaunchedFlow`)
- Entry conditions: Patent_Expiration__c not null AND Regulatory_Status__c != Discontinued AND Patent_Expiry_Alert__c = false (prevents re-trigger loop)
- Flow body: Decision (≤ 548 days?) → Update_PatentAlert (set flag) → Action_RunValidation (rules engine) → Decision (has violations?) → Create_ChatterPost (FeedItem on record)
- Demonstrates `DrugProductValidationFlowAction` as a composable invocable service (not just a trigger helper)

**Critical Flow XML gotchas discovered:**
1. Elements must be grouped by type in the XML — all `<decisions>` together, all `<screens>` together, etc. The XSD uses a strict sequence: `actionCalls`, `choices`, `decisions`, `formulas`, `recordCreates`, `recordUpdates`, `screens`, `variables`. Interspersing types causes "Element X is duplicated at this location" errors.
2. Boolean `InputField` screen components must NOT have `<isRequired>false</isRequired>` — the platform throws "isRequired can't be set to false for screen input fields of type boolean."
3. A screen cannot have both `allowBack=false` AND `allowFinish=false` simultaneously.
4. Standard screen input fields (`InputField`, `DropdownBox`) do NOT use `<outputParameters>` for variable binding — "Outputs aren't supported for fieldType InputField." Screen field values are automatically accessible by their `{!FieldName}` reference in subsequent flow elements. Only Apex action outputs need explicit `<outputParameters>`.

---

## File Organization
```
force-app/main/default/
  classes/
    apiintegration/          # OpenFDA service, enrichment controller, flow actions, tests
    rulesengine/             # Validation engine, admin controller, flow action, wrappers, tests
    DrugProductController    # LWC Apex controller + test (includes getDrugProductsWithValidation)
  lwc/
    drugProductDataTable/    # Data table LWC — enhanced Phase 5 (NavigationMixin, health column, FDA row action)
    drugProductWorkbench/    # Centerpiece workbench LWC — Phase 3
    validationBadgeList/     # Reusable validation badge child LWC — Phase 3
    ruleAdminConsole/        # Permission-gated admin shell — Phase 4
    ruleMetadataTable/       # Read-only CMT display table — Phase 4
    ruleOverrideEditor/      # Full CRUD override editor + modal — Phase 4
  flows/
    New_Drug_Product_Wizard.flow-meta.xml          # Screen Flow — Phase 6
    Drug_Product_Patent_Expiry_Flag.flow-meta.xml  # Record-Triggered Flow — Phase 6
  flexipages/
    Drug_Product_Manager.flexipage-meta.xml         # App page hosting the data table (existing)
    Drug_Product_Admin_Page.flexipage-meta.xml      # Admin app page with ruleAdminConsole — Phase 4
    Drug_Product_Record_Page.flexipage-meta.xml     # Record page with workbench (manual activation required in Dev org)
  objects/
    Drug_Product__c/         # Custom object + 18 fields (incl. Patent_Expiry_Alert__c)
    Rule_Override__c/        # Runtime rule override object + 7 fields
    Validation_Rule__mdt/    # Custom metadata type + 8 fields
  customMetadata/            # 3 validation rule records
  customPermissions/         # Manage_Validation_Rules
  triggers/                  # DrugProductTrigger
  remoteSiteSettings/        # OpenFDA API endpoint
  permissionsets/            # Drug_Product_Access, Drug_Product_Admin
  tabs/                      # Drug_Product__c tab
```

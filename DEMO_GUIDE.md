# Demo Guide — Life Sciences Salesforce Portfolio

This project is a portfolio demonstration of full-stack Salesforce development for the life sciences and pharma CRM space. It contains three interconnected features built on a shared `Drug_Product__c` custom object that tracks pharmaceutical products through their FDA regulatory lifecycle.

The org is pre-loaded with 22 demo records — a mix of real FDA-listed drugs (Humira, Keytruda, Ozempic, etc.) and fictional pipeline compounds — covering all therapeutic areas, regulatory statuses, and dosage forms.

---

## 1. LWC Data Table

**What it demonstrates:** A custom Lightning Web Component with reactive search, column sorting, and inline editing — built on a pharma-appropriate data model rather than generic contacts.

### How to demo

1. Open the **App Launcher** (grid icon, top-left) and search for **Drug Products**
2. The Drug Product Data Table component displays all 22 records

**Search:**
- Type "Oncology" in the search bar — filters to 2 records (Keytruda, Velosinib)
- Type "Pfizer" — filters to 2 records (Lipitor, Zoloft)
- Type "0074" — finds Humira by NDC code
- Clear the search to see all records again

**Sort:**
- Click any column header to sort ascending/descending
- Try sorting by Regulatory Status or Therapeutic Area to group related records

**Inline Edit:**
- Double-click a Manufacturer or Strength cell to edit it
- Make a change, then click **Save** — the record updates in Salesforce and the table refreshes
- Try editing Product Name or Generic Name as well

**Architecture highlights:**
- Data fetching uses a reactive `@wire` adapter with Lightning Data Service caching
- Search is debounced (300ms) to avoid excessive server calls while typing
- Sorting happens client-side for instant response
- Save uses an imperative Apex call with `refreshApex` to bust the cache

---

## 2. OpenFDA API Integration

**What it demonstrates:** An Apex service that calls a real FDA API to enrich Drug Product records with official label data — indications, warnings, manufacturer info, and active ingredients.

### How to demo

Two records are specifically set up for this — **Symbicort** and **Dupixent** — they have basic info but no FDA enrichment yet (`Last FDA Sync` is blank).

1. Open the **Developer Console** (gear icon → Developer Console)
2. Go to **Debug → Open Execute Anonymous Window**
3. First, get the record Id for Symbicort:
   ```apex
   Drug_Product__c p = [SELECT Id FROM Drug_Product__c WHERE Product_Name__c = 'Symbicort' LIMIT 1];
   System.debug(p.Id);
   ```
4. Copy the Id from the debug log, then run the enrichment:
   ```apex
   Drug_Product__c result = OpenFDAService.enrichDrugProduct('PASTE_ID_HERE');
   System.debug('Manufacturer: ' + result.Manufacturer__c);
   System.debug('Last Sync: ' + result.Last_FDA_Sync__c);
   ```
5. Go back to the Drug Product record and refresh — you should see:
   - **Indications** populated with FDA-approved usage text
   - **Warnings** populated with safety warnings from the FDA label
   - **Active Ingredients** populated
   - **Manufacturer** updated to the official FDA-listed manufacturer
   - **Last FDA Sync** set to the current timestamp

### Error handling you can test

- Search for a non-existent drug: `OpenFDAService.searchByBrandName('FakeDrug12345')` — returns `null`
- The service handles HTTP 404 (not found), 429 (rate limit), server errors, timeouts, and malformed JSON responses, all wrapped in a custom `OpenFDAException`

### How it works

- `OpenFDAService.enrichDrugProduct(Id)` searches the OpenFDA Drug Labeling API by brand name first, then falls back to generic name
- Response JSON is parsed and mapped to Drug_Product__c fields
- Identity fields (Product Name, Generic Name, NDC Code) are only populated if currently blank — user data takes precedence
- Data fields (Indications, Warnings, Manufacturer, Active Ingredients) are always updated from the FDA as the authoritative source

---

## 3. Mini Rules Engine

**What it demonstrates:** A configurable, data-driven validation framework — rules are defined in Custom Metadata (not hardcoded in Apex), evaluated by a generic engine, and enforced via a trigger. This is the architecture pattern used in enterprise pharma CRM systems.

### Active rules

| Rule | When... | Then... |
|------|---------|---------|
| Approved Requires FDA Date | Regulatory Status = "Approved" | FDA Approval Date must not be blank |
| Launched Requires Launch Date | Regulatory Status = "Launched" | Launch Date must not be blank |
| Controlled Substance Requires Warnings | Drug Classification = "Controlled Substance" | Warnings must not be blank |

### How to demo each rule

**Rule 1 — "Approved requires FDA Approval Date":**
1. Open the **Gutanavir** record (currently Phase 3, no FDA date)
2. Click **Edit**, change Regulatory Status to **Approved**
3. Click **Save** — you'll see the error: *"Regulatory Status cannot be 'Approved' without an FDA Approval Date."*
4. Fill in an FDA Approval Date → Save → succeeds

**Rule 2 — "Launched requires Launch Date":**
1. Open the **Glucaferrin** record (currently Approved, has FDA date but no Launch Date)
2. Click **Edit**, change Regulatory Status to **Launched**
3. Click **Save** — error: *"Regulatory Status cannot be 'Launched' without a Launch Date."*
4. Fill in a Launch Date → Save → succeeds

**Rule 3 — "Controlled Substance requires Warnings":**
1. Open the **Cardilozine** record (currently Phase 1, Rx, no Warnings)
2. Click **Edit**, change Drug Classification to **Controlled Substance**
3. Click **Save** — error: *"Controlled Substance classification requires the Warnings field to be populated."*
4. Add a Warnings value → Save → succeeds

### How it works (architecture)

The rules engine has zero hardcoded business logic:

1. **Custom Metadata Type** (`Validation_Rule__mdt`) — Each rule is a metadata record with fields for: target object, field to check, operator, expected value, error message, and an optional dependency condition (Dependent Field / Dependent Value)
2. **Engine class** (`ValidationRuleEngine`) — Queries active rules for the object, evaluates each rule's dependency condition, then applies the operator against the field value. Supports 7 operators: `equals`, `not_equals`, `is_blank`, `is_not_blank`, `greater_than`, `less_than`, `contains`
3. **Trigger** (`DrugProductTrigger`) — A single-line dispatch that calls `ValidationRuleEngine.validateAndAddErrors()` on before insert and before update. The trigger contains no business logic.

To add a new rule, you just create a new `Validation_Rule__mdt` record in Setup — no code changes needed. To deactivate a rule, uncheck `Is Active`. This is the same pattern used in enterprise validation frameworks at scale.

### Where to see the metadata

In Setup, search for **Custom Metadata Types** → click **Validation Rule** → **Manage Records** — you'll see the three rule definitions with their field mappings and dependency conditions.

---

## Architecture Summary

All three features share the `Drug_Product__c` object, which makes this a coherent vertical slice rather than three disconnected demos:

- The **data model** tracks a pharmaceutical product from discovery through commercialization
- The **API integration** enriches records with real FDA data
- The **LWC data table** provides a management interface for the portfolio
- The **rules engine** enforces business rules that govern the data lifecycle

The story: "Here's a mini life sciences data model, an integration that enriches it with real FDA data, a UI for managing it, and a rules engine that governs it."

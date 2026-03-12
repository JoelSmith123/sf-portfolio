# Life Sciences Salesforce Portfolio

A Salesforce DX portfolio project demonstrating full-stack development for the life sciences and pharma CRM space. Built on a shared `Drug_Product__c` custom object that tracks pharmaceutical products through their FDA regulatory lifecycle.

## What's Inside

| Feature | What It Demonstrates |
|---------|---------------------|
| **OpenFDA API Integration** | Apex HTTP callout to the FDA Drug Labeling API with JSON parsing, error handling, and record enrichment — including a row-level "Fetch FDA Data" action from the data table |
| **Custom LWC Data Table** | Lightning Web Component with reactive search, column sorting, inline editing, validation health badges, patent alert indicators, and FDA enrichment row actions |
| **Mini Rules Engine** | Data-driven validation framework using Custom Metadata — no hardcoded business logic; permission-set-aware rule overrides at runtime |
| **Drug Product Workbench LWC** | Centerpiece record-page component: editable field panel with real-time client-side validation badge list, FDA diff preview, and server-side save gate |
| **Admin Rule Override Console LWC** | Admin-only Lightning app page for managing `Rule_Override__c` records — suppress, downgrade, or replace rule messages per permission set without deployment |
| **Salesforce Flows** | `New_Drug_Product_Wizard` screen flow (multi-step record creation with live FDA preview) and `Drug_Product_Patent_Expiry_Flag` record-triggered flow (auto-flags expiring patents and posts Chatter alerts when validation violations exist) |

All features share the same custom object and work together as a coherent vertical slice.

## Prerequisites

- [Salesforce CLI](https://developer.salesforce.com/tools/sfdxcli) (`sf` command)
- A Salesforce Developer Edition org (free at [developer.salesforce.com](https://developer.salesforce.com/signup))
- Git

## Setup — From Clone to Demo-Ready

### 1. Clone the repo

```bash
git clone https://github.com/YOUR_USERNAME/sf-portfolio.git
cd sf-portfolio
```

### 2. Authorize your org

```bash
sf org login web --alias portfolio-dev --set-default
```

This opens a browser window — log in to your Developer Edition org.

### 3. Deploy all metadata

```bash
sf project deploy start --target-org portfolio-dev
```

This deploys the custom objects, fields, permission sets, custom permissions, tab, Apex classes, trigger, LWC components, flows, remote site setting, and custom metadata — everything in one shot.

### 4. Assign permission sets

For standard user access (data table, workbench, wizard flow):

```bash
sf org assign permset --name Drug_Product_Access --target-org portfolio-dev
```

To also access the admin rule override console (required to create/edit/delete `Rule_Override__c` records):

```bash
sf org assign permset --name Drug_Product_Admin --target-org portfolio-dev
```

### 5. Run all tests

```bash
sf apex run test --synchronous --code-coverage --result-format human --target-org portfolio-dev
```

You should see 88 tests passing with 95%+ org-wide coverage.

### 6. Load demo data

```bash
sf apex run --file scripts/apex/create-demo-data.apex --target-org portfolio-dev
```

This inserts 22 pharmaceutical product records — a mix of real FDA-listed drugs (Humira, Keytruda, Ozempic, etc.) and fictional pipeline compounds covering all therapeutic areas, regulatory statuses, and dosage forms.

The script is idempotent — it deletes existing Drug Product records first, so it's safe to re-run anytime to reset the demo.

### 7. Add the Drug Products tab to your app

1. Open your org in the browser: `sf org open --target-org portfolio-dev`
2. Navigate to any Lightning app (e.g., Sales)
3. Click the **pencil icon** in the navigation bar
4. Click **Add More Items**, find **Drug Products**, add it, and save

### 8. You're demo-ready

Open the **Drug Products** tab to see the data table with all 22 records. See [DEMO_GUIDE.md](DEMO_GUIDE.md) for a step-by-step walkthrough of all features.

## Key Demo Paths

**Data Table → FDA Row Action**
Click the row action menu on any record and select **Fetch FDA Data** to enrich the record from the OpenFDA API. The health badge column updates to reflect new validation status after enrichment.

**New Drug Product Wizard**
Click **New Drug Product** in the data table toolbar (or use the Quick Action on any record page) to launch the multi-step screen flow. After entering a product name, the wizard calls OpenFDA, previews the returned data with accept/reject checkboxes, and creates the record.

**Drug Product Workbench (Record Page)**
Open any `Drug_Product__c` record. The Workbench component shows all fields as an editable form with a live validation badge list on the right. Changing a field value (e.g., setting Regulatory Status to "Approved" without an FDA Approval Date) instantly shows a red badge — no save required. Click **Fetch from FDA** to preview a diff of proposed changes before accepting them.

**Admin Rule Override Console**
If assigned `Drug_Product_Admin`, navigate to the **Drug Product Admin** Lightning app page. The console shows all Custom Metadata validation rules (read-only, deployment-controlled) and the runtime `Rule_Override__c` records below. Create an override to suppress or downgrade a rule for a specific permission set — the change takes effect immediately for any user with that permission set.

**Patent Expiry Record-Triggered Flow**
Set `Patent_Expiration__c` on any non-discontinued record to a date within the next 18 months. On save, the flow automatically sets `Patent_Expiry_Alert__c = true` and — if the rules engine finds blocking violations — posts a Chatter message to the record feed with the violation summary.

## Project Structure

```
force-app/main/default/
  classes/
    apiintegration/
      DrugProductEnrichmentController.cls  # Apex controller: FDA preview, enrichAndSave, validation gate
      DrugProductFDAFlowAction.cls         # Invocable action: read-only FDA lookup for Screen Flow
      DrugProductFlowController.cls        # Invocable action: creates Drug_Product__c from Flow
      OpenFDADrugResult.cls                # Parsed FDA result wrapper
      OpenFDAException.cls                 # Custom exception
      OpenFDAService.cls                   # HTTP callout service
      *Test.cls                            # Test class for each above
    rulesengine/
      DrugProductAdminController.cls       # Apex controller: rule + override CRUD for admin LWC
      DrugProductValidationFlowAction.cls  # Invocable action: runs rules engine for Record-Triggered Flow
      ValidationResult.cls                 # Result wrapper (errorMessage, isBlockingError)
      ValidationRuleDefinition.cls         # AuraEnabled wrapper for wire serialisation
      ValidationRuleEngine.cls             # Core engine: evaluates CMT rules, applies overrides
      *Test.cls                            # Test class for each above
    DrugProductController.cls              # LWC Apex controller (data table + validation wrapper)
    DrugProductControllerTest.cls
  lwc/
    drugProductDataTable/      # Data table: search, sort, inline edit, health badge, FDA row action
    drugProductWorkbench/      # Centerpiece record-page workbench: live validation + FDA diff panel
    validationBadgeList/       # Reusable child: renders one badge per validation rule
    ruleAdminConsole/          # Admin-only: rule + override management UI
    ruleMetadataTable/         # Read-only CMT rule display (child of ruleAdminConsole)
    ruleOverrideEditor/        # Override CRUD table + modal (child of ruleAdminConsole)
  flows/
    New_Drug_Product_Wizard.flow-meta.xml           # Screen Flow: multi-step wizard with FDA preview
    Drug_Product_Patent_Expiry_Flag.flow-meta.xml   # Record-Triggered Flow: patent alert + Chatter post
  objects/
    Drug_Product__c/           # Custom object + 18 fields (incl. Patent_Expiry_Alert__c)
    Rule_Override__c/          # Runtime rule overrides by permission set
    Validation_Rule__mdt/      # Custom metadata type + 8 fields
  customMetadata/              # 3 validation rule records
  customPermissions/           # Manage_Validation_Rules
  flexipages/
    Drug_Product_Record_Page.flexipage-meta.xml  # Two-column record page with Workbench
    Drug_Product_Admin_Page.flexipage-meta.xml   # Admin Lightning app page
  triggers/                    # DrugProductTrigger
  remoteSiteSettings/          # OpenFDA API endpoint
  permissionsets/
    Drug_Product_Access.permissionset-meta.xml   # Standard user access
    Drug_Product_Admin.permissionset-meta.xml    # Admin: adds Rule_Override__c CRUD + custom perm
  tabs/                        # Drug_Product__c tab
scripts/
  apex/
    create-demo-data.apex      # Demo data loader (22 records)
```

## Tech Stack

- **Apex** — Service classes, controllers, invocable actions, trigger, validation engine, permission-set-aware rule overrides
- **Lightning Web Components** — Data table, record workbench, reusable badge list, admin console (wire adapters, imperative calls, NavigationMixin)
- **Custom Metadata Types** — Data-driven rule definitions; no hardcoded validation logic
- **Custom Objects** — `Rule_Override__c` for runtime rule configuration without deployment
- **Custom Permissions** — `Manage_Validation_Rules` permission gates admin write operations in both Apex and LWC
- **Salesforce Flows** — Screen Flow with multi-step UX and invocable Apex; Record-Triggered After-Save Flow with invocable rules engine and Chatter integration
- **OpenFDA API** — Real-world REST integration (no auth required)
- **Salesforce DX** — Source-driven development, API v66.0

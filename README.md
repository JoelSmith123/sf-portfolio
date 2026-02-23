# Life Sciences Salesforce Portfolio

A Salesforce DX portfolio project demonstrating full-stack development for the life sciences and pharma CRM space. Built on a shared `Drug_Product__c` custom object that tracks pharmaceutical products through their FDA regulatory lifecycle.

## What's Inside

| Feature | What It Demonstrates |
|---------|---------------------|
| **OpenFDA API Integration** | Apex HTTP callout to the FDA Drug Labeling API with JSON parsing, error handling, and record enrichment |
| **Custom LWC Data Table** | Lightning Web Component with reactive search, column sorting, and inline editing |
| **Mini Rules Engine** | Data-driven validation framework using Custom Metadata — no hardcoded business logic |

All three features share the same custom object and work together as a coherent vertical slice.

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

This deploys the custom object, fields, permission set, tab, Apex classes, trigger, LWC, remote site setting, and custom metadata — everything in one shot.

### 4. Assign the permission set

```bash
sf org assign permset --name Drug_Product_Access --target-org portfolio-dev
```

This grants your user access to the Drug Product object, all fields, and the tab.

### 5. Run all tests

```bash
sf apex run test --synchronous --code-coverage --result-format human --target-org portfolio-dev
```

You should see 44 tests passing with 95%+ org-wide coverage.

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

Open the **Drug Products** tab to see the data table with all 22 records. See [DEMO_GUIDE.md](DEMO_GUIDE.md) for a step-by-step walkthrough of all three features.

## Project Structure

```
force-app/main/default/
  classes/
    apiintegration/            # OpenFDA service, result wrapper, exception, test
    rulesengine/               # Validation engine, result wrapper, test
    DrugProductController.cls  # LWC Apex controller + test
  lwc/
    drugProductDataTable/      # Data table LWC (html, js, css, meta)
  objects/
    Drug_Product__c/           # Custom object + 17 fields
    Validation_Rule__mdt/      # Custom metadata type + 8 fields
  customMetadata/              # 3 validation rule records
  triggers/                    # DrugProductTrigger
  remoteSiteSettings/          # OpenFDA API endpoint
  permissionsets/              # Drug_Product_Access
  tabs/                        # Drug_Product__c tab
scripts/
  apex/
    create-demo-data.apex      # Demo data loader (22 records)
```

## Tech Stack

- **Apex** — Service classes, controller, trigger, validation engine
- **Lightning Web Components** — Data table with wire adapters, imperative calls
- **Custom Metadata Types** — Data-driven rule definitions
- **OpenFDA API** — Real-world REST integration (no auth required)
- **Salesforce DX** — Source-driven development, API v66.0

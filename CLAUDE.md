# CLAUDE.md — Salesforce Portfolio Project

## Project Purpose

This is a Salesforce DX portfolio project demonstrating full-stack Salesforce development skills for freelance/consulting clients. It contains three self-contained portfolio pieces within a single deployable project:

1. **REST API Integration** — Apex callout to a public API with proper error handling
2. **Custom LWC Data Table** — Lightning Web Component with filtering and inline editing
3. **Mini Rules Engine** — Apex-based validation/rules framework

---

## Org & Project Setup

- **Salesforce API Version:** 66.0 (Spring '26)
- **Default package directory:** `force-app/main/default/`
- **Org alias:** `portfolio-dev` (Developer Edition org — does not expire)
- **Deployment:** Use `sf project deploy start` to push to org

To authorize the org if needed:
```bash
sf org login web --alias portfolio-dev
```

---

## Folder Structure Conventions

Keep each portfolio piece's code organized under its own subfolder:

```
force-app/main/default/
  classes/
    apiintegration/       # REST API callout feature
    rulesengine/          # Rules engine / validation framework
  lwc/
    customDataTable/      # LWC data table component
  permissionsets/
  staticresources/
```

Do not mix classes from different features into the same folder without good reason.

---

## Coding Conventions

- **Apex:** Follow standard Salesforce Apex style. Use meaningful variable and method names. Add ApexDoc comments to all public methods.
- **LWC:** Use camelCase for component names and properties. Keep business logic out of JS controllers — delegate to Apex where possible.
- **Error handling:** All Apex callouts must handle exceptions explicitly. Never let an unhandled exception surface to the UI without a user-friendly message.
- **Test classes:** Every Apex class must have a corresponding test class written at the same time. Test classes go in the same `apiintegration/` or `rulesengine/` subfolder as the class they test. Minimum 85% code coverage is required; aim for 95%+.

---

## Rules Claude Must Follow

- **Always write Apex test classes** when creating or modifying Apex classes. Do not suggest deploying Apex without a corresponding test class.
- **Always run tests before suggesting a deploy.** Use `sf apex run test` or equivalent and confirm passing before recommending a `project deploy start`.
- **Do not modify `package.xml` manually.** Let the SFDX tooling manage the manifest, or flag it explicitly if a manual change is truly necessary and explain why.
- **Do not modify `.gitignore` manually.** Flag it explicitly if a manual change is truly necessary and explain why.
- **Commit after each meaningful unit of work.** Do not bundle unrelated changes into a single commit. Use descriptive, freeform commit messages that explain *what* changed and *why* — not just "updated file."
- **Always write plans and key decisions to `PLANNING.md`** before starting work. Do not begin coding until the plan is added to that file. `PLANNING.md` should be continuously updated throughout broader project work, to enable tracking progress and design consistency. This could include removing outdated material in the file if a new plan has been chosen, editing existing material in the file to clarify revisions, and incorporating information about new changes in with the existing content to maintain an organized plan file.  
- **Update the `README.md` if any changes are made that affect demo set-up or that majorly change org functionality.**

---

## Git & Version Control

- One GitHub repo for the entire project.
- Commit frequently and at logical boundaries (e.g., after a class + its test are both written, after a working LWC milestone, etc.).
- Commit message format: descriptive freeform. Examples:
  - `Add WeatherService Apex class with HTTP callout and error handling`
  - `Add test class for WeatherService covering success and timeout scenarios`
  - `Build initial customDataTable LWC with column sorting`
- Do not commit broken or incomplete code without a note in the commit message indicating it is a WIP.
- Do not commit test results or test logs.

---

## Deployment Checklist (before every deploy)

1. Run all tests: `sf apex run test --synchronous`
2. Confirm all tests pass with no failures
3. Deploy: `sf project deploy start --target-org portfolio-dev`
4. Verify deployment success in org

---

## Notes

This project is intentionally kept simple and clean — it is a portfolio demonstration, not a production application. Prioritize clarity, readability, and best-practice patterns over cleverness or over-engineering.

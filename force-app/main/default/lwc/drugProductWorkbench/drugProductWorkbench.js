/**
 * @description Centerpiece interactive LWC for Drug_Product__c record pages.
 *
 *              UX loop:
 *                1. User clicks Edit — all fields become editable; validation panel
 *                   on the right immediately shows live rule results.
 *                2. Any field change re-evaluates all rules client-side (no round-trip)
 *                   using the same operator logic as the Apex ValidationRuleEngine.
 *                3. "Fetch from FDA" previews proposed field values from OpenFDA without
 *                   DML; a diff table lets the user accept individual fields.
 *                4. Accepted FDA values merge into the form state; validation re-runs.
 *                5. Save calls evaluateRecord() as a server-side gate, then updateRecord()
 *                   via LDS. On success the panel returns to view mode.
 *
 *              Placed on the Drug_Product__c record page via Drug_Product_Record_Page
 *              flexipage (Phase 3 deliverable).
 */
import { LightningElement, api, wire } from 'lwc';
import {
    getRecord,
    getFieldValue,
    updateRecord,
    getRecordNotifyChange
} from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getActiveRulesForCurrentUser
    from '@salesforce/apex/DrugProductEnrichmentController.getActiveRulesForCurrentUser';
import previewFDAEnrichment
    from '@salesforce/apex/DrugProductEnrichmentController.previewFDAEnrichment';
import evaluateRecord
    from '@salesforce/apex/DrugProductEnrichmentController.evaluateRecord';

// ── Schema field references ─────────────────────────────────────────────────
import PRODUCT_NAME_FIELD    from '@salesforce/schema/Drug_Product__c.Product_Name__c';
import GENERIC_NAME_FIELD    from '@salesforce/schema/Drug_Product__c.Generic_Name__c';
import NDC_CODE_FIELD        from '@salesforce/schema/Drug_Product__c.NDC_Code__c';
import THERAPEUTIC_AREA_FIELD from '@salesforce/schema/Drug_Product__c.Therapeutic_Area__c';
import DRUG_CLASS_FIELD      from '@salesforce/schema/Drug_Product__c.Drug_Classification__c';
import DOSAGE_FORM_FIELD     from '@salesforce/schema/Drug_Product__c.Dosage_Form__c';
import STRENGTH_FIELD        from '@salesforce/schema/Drug_Product__c.Strength__c';
import MANUFACTURER_FIELD    from '@salesforce/schema/Drug_Product__c.Manufacturer__c';
import FDA_DATE_FIELD        from '@salesforce/schema/Drug_Product__c.FDA_Approval_Date__c';
import LAUNCH_DATE_FIELD     from '@salesforce/schema/Drug_Product__c.Launch_Date__c';
import PATENT_EXP_FIELD      from '@salesforce/schema/Drug_Product__c.Patent_Expiration__c';
import REG_STATUS_FIELD      from '@salesforce/schema/Drug_Product__c.Regulatory_Status__c';
import ACTIVE_ING_FIELD      from '@salesforce/schema/Drug_Product__c.Active_Ingredients__c';
import INDICATIONS_FIELD     from '@salesforce/schema/Drug_Product__c.Indications__c';
import WARNINGS_FIELD        from '@salesforce/schema/Drug_Product__c.Warnings__c';
import ORPHAN_DRUG_FIELD     from '@salesforce/schema/Drug_Product__c.Orphan_Drug_Status__c';
import LAST_FDA_SYNC_FIELD   from '@salesforce/schema/Drug_Product__c.Last_FDA_Sync__c';

const FIELDS = [
    PRODUCT_NAME_FIELD, GENERIC_NAME_FIELD, NDC_CODE_FIELD, THERAPEUTIC_AREA_FIELD,
    DRUG_CLASS_FIELD, DOSAGE_FORM_FIELD, STRENGTH_FIELD, MANUFACTURER_FIELD,
    FDA_DATE_FIELD, LAUNCH_DATE_FIELD, PATENT_EXP_FIELD, REG_STATUS_FIELD,
    ACTIVE_ING_FIELD, INDICATIONS_FIELD, WARNINGS_FIELD, ORPHAN_DRUG_FIELD,
    LAST_FDA_SYNC_FIELD
];

// ── Picklist option constants ───────────────────────────────────────────────
const REGULATORY_STATUS_OPTIONS = [
    { label: '-- None --',      value: '' },
    { label: 'In Discovery',    value: 'In Discovery'    },
    { label: 'IND Pending',     value: 'IND Pending'     },
    { label: 'Phase 1',         value: 'Phase 1'         },
    { label: 'Phase 2',         value: 'Phase 2'         },
    { label: 'Phase 3',         value: 'Phase 3'         },
    { label: 'NDA Submitted',   value: 'NDA Submitted'   },
    { label: 'Under FDA Review',value: 'Under FDA Review'},
    { label: 'Approved',        value: 'Approved'        },
    { label: 'Launched',        value: 'Launched'        },
    { label: 'Post-Marketing',  value: 'Post-Marketing'  },
    { label: 'Discontinued',    value: 'Discontinued'    }
];

const DRUG_CLASSIFICATION_OPTIONS = [
    { label: '-- None --',          value: '' },
    { label: 'Rx',                  value: 'Rx'                  },
    { label: 'OTC',                 value: 'OTC'                 },
    { label: 'Controlled Substance',value: 'Controlled Substance'}
];

const DOSAGE_FORM_OPTIONS = [
    { label: '-- None --',    value: '' },
    { label: 'Tablet',        value: 'Tablet'       },
    { label: 'Capsule',       value: 'Capsule'      },
    { label: 'Injectable',    value: 'Injectable'   },
    { label: 'Infusion',      value: 'Infusion'     },
    { label: 'Topical',       value: 'Topical'      },
    { label: 'Oral Solution', value: 'Oral Solution'},
    { label: 'Patch',         value: 'Patch'        },
    { label: 'Inhaler',       value: 'Inhaler'      }
];

/** Human-readable labels for the FDA diff table column */
const FDA_FIELD_LABELS = {
    NDC_Code__c:           'NDC Code',
    Manufacturer__c:       'Manufacturer',
    Active_Ingredients__c: 'Active Ingredients',
    Indications__c:        'Indications',
    Warnings__c:           'Warnings'
};

export default class DrugProductWorkbench extends LightningElement {
    /** Provided by the lightning__RecordPage flexipage context */
    @api recordId;

    // ── UI state ──────────────────────────────────────────────────────────
    isEditing  = false;
    isSaving   = false;
    isFetching = false;

    /** Current form-field values; initialized from getRecord wire on load */
    editState = {};

    /** Validation errors passed to c-validation-badge-list child component */
    liveValidationErrors = [];

    // ── Private state ─────────────────────────────────────────────────────
    _originalState     = {};   // Snapshot taken at record load; used by Cancel
    _rulesCache        = [];   // ValidationRuleDefinition[] from wire
    _fdaProposals      = {};   // { fieldName: proposedValue } from previewFDAEnrichment
    _fdaAcceptedFields = {};   // { fieldName: boolean } checkbox state in diff table
    _isRecordLoaded    = false;
    _loadError         = null;

    // ── Wire: record data ────────────────────────────────────────────────
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            const freshState = this._buildEditState(data);
            this._originalState = { ...freshState };
            // Only overwrite edit state when not actively editing (avoid clobbering user input)
            if (!this.isEditing) {
                this.editState = { ...freshState };
            }
            this._isRecordLoaded = true;
            this._loadError = null;
        } else if (error) {
            this._loadError = error;
            this._isRecordLoaded = true;
        }
    }

    // ── Wire: validation rule definitions ────────────────────────────────
    /**
     * Loads active rules once at mount (cacheable=true). Each rule carries
     * per-user override context (isSuppressedForUser, isDowngradedToWarning,
     * overrideMessage) so client-side evaluation can respect them without
     * an extra round-trip.
     */
    @wire(getActiveRulesForCurrentUser, { objectApiName: 'Drug_Product__c' })
    wiredRules({ error, data }) {
        if (data) {
            this._rulesCache = data;
            if (this.isEditing) {
                this._evaluateRulesClientSide();
            }
        } else if (error) {
            // Non-fatal: validation panel will be empty until rules load
            console.error('[DrugProductWorkbench] Failed to load validation rules', error);
        }
    }

    // ── Computed getters ──────────────────────────────────────────────────
    get isLoading()        { return !this._isRecordLoaded; }
    get hasLoadError()     { return !!this._loadError; }
    get isBusy()           { return this.isSaving || this.isFetching; }
    get hasFDAProposal()   { return Object.keys(this._fdaProposals).length > 0; }

    get loadErrorMessage() {
        if (!this._loadError) return '';
        return (this._loadError.body && this._loadError.body.message)
            ? this._loadError.body.message
            : 'Failed to load record.';
    }

    /** Maps _fdaProposals to template-friendly rows including the accept checkbox state */
    get fdaProposalRows() {
        return Object.entries(this._fdaProposals).map(([field, proposed]) => ({
            field,
            label:    FDA_FIELD_LABELS[field] || field,
            current:  this.editState[field] != null ? String(this.editState[field]) : '',
            proposed,
            accepted: !!this._fdaAcceptedFields[field]
        }));
    }

    // Expose picklist option constants to the template
    get regulatoryStatusOptions()    { return REGULATORY_STATUS_OPTIONS;    }
    get drugClassificationOptions()  { return DRUG_CLASSIFICATION_OPTIONS;  }
    get dosageFormOptions()          { return DOSAGE_FORM_OPTIONS;           }

    // ── Edit mode handlers ────────────────────────────────────────────────
    handleEdit() {
        this.isEditing = true;
        this._evaluateRulesClientSide();
    }

    handleCancel() {
        this.editState            = { ...this._originalState };
        this.isEditing            = false;
        this._fdaProposals        = {};
        this._fdaAcceptedFields   = {};
        this.liveValidationErrors = [];
    }

    // ── Field change handler ──────────────────────────────────────────────
    /**
     * Shared handler for lightning-input (text, date) and lightning-combobox.
     * Uses data-field to identify which field changed.
     * Uses data-type="checkbox" on checkbox inputs to read event.detail.checked.
     */
    handleFieldChange(event) {
        const field      = event.target.dataset.field;
        const isCheckbox = event.target.dataset.type === 'checkbox';
        const value      = isCheckbox ? event.detail.checked : event.detail.value;
        this.editState   = { ...this.editState, [field]: value };
        this._evaluateRulesClientSide();
    }

    // ── Save ──────────────────────────────────────────────────────────────
    async handleSave() {
        this.isSaving = true;
        try {
            // Build the evaluation payload: exclude Last_FDA_Sync__c (read-only datetime)
            // and convert empty strings to null so Apex JSON.deserialize handles typed fields.
            const evalPayload = { Id: this.recordId };
            for (const [key, val] of Object.entries(this.editState)) {
                if (key === 'Last_FDA_Sync__c') continue;
                evalPayload[key] = (val === '' || val === undefined) ? null : val;
            }

            const allErrors = await evaluateRecord({
                fieldValues:    evalPayload,
                objectApiName:  'Drug_Product__c'
            });

            const blocking = (allErrors || []).filter(e => e.isBlockingError);
            if (blocking.length > 0) {
                // Surface the full error list (blocking + warnings) in the validation panel
                this.liveValidationErrors = allErrors;
                this._showToast(
                    'Validation Failed',
                    `${blocking.length} blocking error${blocking.length > 1 ? 's' : ''} must be resolved before saving.`,
                    'error'
                );
                return;
            }

            // Build the LDS updateRecord payload (null out cleared fields)
            const fields = { Id: this.recordId };
            for (const [key, val] of Object.entries(this.editState)) {
                if (key === 'Last_FDA_Sync__c') continue;
                fields[key] = (val === '' || val === undefined) ? null : val;
            }

            await updateRecord({ fields });
            getRecordNotifyChange([{ recordId: this.recordId }]);
            this._showToast('Saved', 'Drug product updated successfully.', 'success');

            this.isEditing            = false;
            this._fdaProposals        = {};
            this._fdaAcceptedFields   = {};
            this.liveValidationErrors = [];
        } catch (error) {
            this._showToast('Save Error', this._extractMessage(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    // ── FDA integration ───────────────────────────────────────────────────
    async handleFetchFDA() {
        this.isFetching = true;
        try {
            const proposed = await previewFDAEnrichment({ recordId: this.recordId });
            if (!proposed || Object.keys(proposed).length === 0) {
                this._showToast('FDA Lookup', 'No FDA match found for this drug product.', 'info');
                return;
            }
            // Populate diff panel (all unchecked by default)
            this._fdaProposals      = { ...proposed };
            this._fdaAcceptedFields = {};
        } catch (error) {
            this._showToast('FDA Error', this._extractMessage(error), 'error');
        } finally {
            this.isFetching = false;
        }
    }

    /** Toggle a single row's accept checkbox in the FDA diff table */
    handleFDAAcceptToggle(event) {
        const field = event.target.dataset.field;
        const checked = event.detail.checked;
        // Spread to new reference so fdaProposalRows getter re-evaluates
        this._fdaAcceptedFields = { ...this._fdaAcceptedFields, [field]: checked };
    }

    /** Merge all accepted FDA proposals into editState and close the diff panel */
    handleApplyFDA() {
        const newState = { ...this.editState };
        for (const [field, isAccepted] of Object.entries(this._fdaAcceptedFields)) {
            if (isAccepted
                    && Object.prototype.hasOwnProperty.call(this._fdaProposals, field)) {
                newState[field] = this._fdaProposals[field];
            }
        }
        this.editState          = newState;
        this._fdaProposals      = {};
        this._fdaAcceptedFields = {};
        this._evaluateRulesClientSide();
        this._showToast('Applied', 'FDA proposed changes applied to the form.', 'success');
    }

    handleDismissFDA() {
        this._fdaProposals      = {};
        this._fdaAcceptedFields = {};
    }

    // ── Client-side rule evaluation ───────────────────────────────────────
    /**
     * Mirrors ValidationRuleEngine.evaluate() in JavaScript. Runs on every
     * field change so the validation panel updates in real time without an
     * Apex round-trip. Uses the rule definitions (with per-user override context)
     * loaded once by the getActiveRulesForCurrentUser wire.
     */
    _evaluateRulesClientSide() {
        if (!this._rulesCache || this._rulesCache.length === 0) {
            this.liveValidationErrors = [];
            return;
        }

        const errors = [];
        for (const rule of this._rulesCache) {
            // Suppressed rules are invisible to this user
            if (rule.isSuppressedForUser) continue;

            // Dependent field gate: rule only fires when depField === depValue
            if (rule.dependentField && rule.dependentValue) {
                const depFieldVal = String(this.editState[rule.dependentField] ?? '');
                if (depFieldVal !== rule.dependentValue) continue;
            }

            const fieldVal = this.editState[rule.fieldName];
            const passes   = this._evaluateOperator(fieldVal, rule.operator, rule.value);

            if (!passes) {
                errors.push({
                    ruleName:       rule.ruleName,
                    fieldName:      rule.fieldName,
                    errorMessage:   rule.overrideMessage || rule.errorMessage,
                    isBlockingError: !rule.isDowngradedToWarning
                });
            }
        }
        this.liveValidationErrors = errors;
    }

    /**
     * Single-operator evaluator matching Apex ValidationRuleEngine.evaluateOperator().
     * Returns true when the field value satisfies the rule (no violation).
     *
     * Matches Apex's String.valueOf() behaviour:
     *   null   → ''      (isBlank = true)
     *   false  → 'false' (isBlank = false)
     *   true   → 'true'  (isBlank = false)
     */
    _evaluateOperator(fieldVal, operator, ruleVal) {
        const strVal  = (fieldVal == null) ? '' : String(fieldVal);
        const isBlank = strVal.trim() === '';

        switch (operator) {
            case 'is_blank':     return isBlank;
            case 'is_not_blank': return !isBlank;
            case 'equals':       return strVal === (ruleVal ?? '');
            case 'not_equals':   return strVal !== (ruleVal ?? '');
            case 'contains':
                return !isBlank
                    && strVal.toLowerCase().includes((ruleVal ?? '').toLowerCase());
            case 'greater_than':
                if (isBlank || !ruleVal) return false;
                return Number(strVal) > Number(ruleVal);
            case 'less_than':
                if (isBlank || !ruleVal) return false;
                return Number(strVal) < Number(ruleVal);
            default:
                return true; // Unknown operator: pass by default (mirrors Apex)
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────
    /** Extracts typed field values from a getRecord data payload */
    _buildEditState(data) {
        return {
            Product_Name__c:        getFieldValue(data, PRODUCT_NAME_FIELD)     ?? '',
            Generic_Name__c:        getFieldValue(data, GENERIC_NAME_FIELD)     ?? '',
            NDC_Code__c:            getFieldValue(data, NDC_CODE_FIELD)         ?? '',
            Therapeutic_Area__c:    getFieldValue(data, THERAPEUTIC_AREA_FIELD) ?? '',
            Drug_Classification__c: getFieldValue(data, DRUG_CLASS_FIELD)       ?? '',
            Dosage_Form__c:         getFieldValue(data, DOSAGE_FORM_FIELD)      ?? '',
            Strength__c:            getFieldValue(data, STRENGTH_FIELD)         ?? '',
            Manufacturer__c:        getFieldValue(data, MANUFACTURER_FIELD)     ?? '',
            FDA_Approval_Date__c:   getFieldValue(data, FDA_DATE_FIELD)         ?? '',
            Launch_Date__c:         getFieldValue(data, LAUNCH_DATE_FIELD)      ?? '',
            Patent_Expiration__c:   getFieldValue(data, PATENT_EXP_FIELD)       ?? '',
            Regulatory_Status__c:   getFieldValue(data, REG_STATUS_FIELD)       ?? '',
            Active_Ingredients__c:  getFieldValue(data, ACTIVE_ING_FIELD)       ?? '',
            Indications__c:         getFieldValue(data, INDICATIONS_FIELD)      ?? '',
            Warnings__c:            getFieldValue(data, WARNINGS_FIELD)         ?? '',
            Orphan_Drug_Status__c:  getFieldValue(data, ORPHAN_DRUG_FIELD)      ?? false,
            Last_FDA_Sync__c:       getFieldValue(data, LAST_FDA_SYNC_FIELD)    ?? ''
        };
    }

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _extractMessage(error) {
        if (!error)                              return 'An unexpected error occurred.';
        if (error.body && error.body.message)    return error.body.message;
        if (error.message)                       return error.message;
        return 'An unexpected error occurred.';
    }
}

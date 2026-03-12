/**
 * @description CRUD editor for Rule_Override__c records. Displays a datatable of
 *              existing overrides with row-level Edit and Delete actions, plus a
 *              "New Override" button that opens a modal form.
 *
 *              Wires:
 *                - getAllOverrides()     → overrides datatable data
 *                - getPermissionSetNames() → populates the Permission Set dropdown
 *
 *              @api rules — Validation_Rule__mdt list from ruleAdminConsole (populates
 *              the Validation Rule dropdown in the modal).
 *
 *              DML methods write through DrugProductAdminController which gates all
 *              writes behind the Manage_Validation_Rules custom permission.
 */
import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getAllOverrides
    from '@salesforce/apex/DrugProductAdminController.getAllOverrides';
import getPermissionSetNames
    from '@salesforce/apex/DrugProductAdminController.getPermissionSetNames';
import saveOverride
    from '@salesforce/apex/DrugProductAdminController.saveOverride';
import deleteOverride
    from '@salesforce/apex/DrugProductAdminController.deleteOverride';

// ── Column definitions ──────────────────────────────────────────────────────
const COLUMNS = [
    {
        label: 'Validation Rule',
        fieldName: 'Validation_Rule_Name__c',
        type: 'text',
        sortable: true
    },
    {
        label: 'Permission Set',
        fieldName: 'Permission_Set_Name__c',
        type: 'text',
        sortable: true
    },
    {
        label: 'Action',
        fieldName: 'Override_Action__c',
        type: 'text',
        sortable: true,
        cellAttributes: { class: { fieldName: 'actionCssClass' } }
    },
    {
        label: 'Override Message',
        fieldName: 'Override_Message__c',
        type: 'text',
        wrapText: true
    },
    {
        label: 'Active',
        fieldName: 'Is_Active__c',
        type: 'boolean',
        cellAttributes: { alignment: 'center' }
    },
    {
        label: 'Expires On',
        fieldName: 'Expires_On__c',
        type: 'date',
        typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit' }
    },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Edit',   name: 'edit'   },
                { label: 'Delete', name: 'delete' }
            ]
        }
    }
];

const ACTION_OPTIONS = [
    { label: '-- Select --',             value: ''                     },
    { label: 'Suppress',                 value: 'Suppress'             },
    { label: 'Override Message',         value: 'Override_Message'     },
    { label: 'Downgrade to Warning',     value: 'Downgrade_To_Warning' }
];

const ACTION_HELP = {
    'Suppress':             'The rule is completely hidden for users in the selected permission set. No error or warning is shown.',
    'Override_Message':     'The rule still fires, but shows your custom message instead of the rule\'s default error text.',
    'Downgrade_To_Warning': 'The rule still fires, but the error is shown as a non-blocking amber warning. Save is still allowed.',
    '':                     ''
};

/** Build a blank draft for the "New Override" form */
const blankDraft = () => ({
    Id:                       null,
    Validation_Rule_Name__c:  '',
    Permission_Set_Name__c:   '',
    Override_Action__c:       '',
    Override_Message__c:      '',
    Is_Active__c:             true,
    Expires_On__c:            '',
    Notes__c:                 ''
});

export default class RuleOverrideEditor extends LightningElement {
    /** Validation_Rule__mdt list — used to populate the rule dropdown in the modal */
    @api rules = [];

    columns   = COLUMNS;
    overrides = [];
    permSets  = [];
    showModal = false;
    isSaving  = false;
    draftOverride = blankDraft();

    _isEditing           = false;
    _wiredOverridesResult = null;

    // ── Wire handlers ─────────────────────────────────────────────────────
    @wire(getAllOverrides)
    wiredOverrides(result) {
        this._wiredOverridesResult = result;
        if (result.data) {
            this.overrides = result.data;
        } else if (result.error) {
            console.error('[RuleOverrideEditor] Failed to load overrides', result.error);
        }
    }

    @wire(getPermissionSetNames)
    wiredPermSets({ error, data }) {
        if (data) {
            this.permSets = data;
        } else if (error) {
            console.error('[RuleOverrideEditor] Failed to load permission set names', error);
        }
    }

    // ── Getters ───────────────────────────────────────────────────────────
    get hasOverrides()        { return this.overrides.length > 0; }
    get overrideCount()       { return this.overrides.length; }
    get overrideCountSuffix() { return this.overrides.length === 1 ? '' : 's'; }
    get modalTitle()          { return this._isEditing ? 'Edit Override' : 'New Override'; }

    get showMessageField() {
        return this.draftOverride.Override_Action__c === 'Override_Message';
    }

    get actionHelpText() {
        return ACTION_HELP[this.draftOverride.Override_Action__c] || '';
    }

    get ruleOptions() {
        const opts = [{ label: '-- Select Rule --', value: '' }];
        (this.rules || []).forEach(r =>
            opts.push({ label: r.MasterLabel || r.DeveloperName, value: r.DeveloperName })
        );
        return opts;
    }

    get permSetOptions() {
        const opts = [{ label: '-- Select Permission Set --', value: '' }];
        (this.permSets || []).forEach(ps => opts.push({ label: ps, value: ps }));
        return opts;
    }

    get actionOptions() { return ACTION_OPTIONS; }

    // ── Modal open / close ────────────────────────────────────────────────
    handleNewOverride() {
        this._isEditing   = false;
        this.draftOverride = blankDraft();
        this.showModal    = true;
    }

    handleCloseModal() {
        this.showModal = false;
    }

    // ── Row actions ───────────────────────────────────────────────────────
    handleRowAction(event) {
        const { action, row } = event.detail;
        if (action.name === 'edit') {
            this._isEditing    = true;
            this.draftOverride = {
                Id:                      row.Id,
                Validation_Rule_Name__c: row.Validation_Rule_Name__c || '',
                Permission_Set_Name__c:  row.Permission_Set_Name__c  || '',
                Override_Action__c:      row.Override_Action__c      || '',
                Override_Message__c:     row.Override_Message__c     || '',
                Is_Active__c:            row.Is_Active__c            ?? true,
                Expires_On__c:           row.Expires_On__c           || '',
                Notes__c:                row.Notes__c                || ''
            };
            this.showModal = true;
        } else if (action.name === 'delete') {
            this._doDelete(row.Id);
        }
    }

    // ── Draft form changes ────────────────────────────────────────────────
    handleDraftChange(event) {
        const field      = event.target.dataset.field;
        const isCheckbox = event.target.dataset.type === 'checkbox';
        const value      = isCheckbox ? event.detail.checked : event.detail.value;
        this.draftOverride = { ...this.draftOverride, [field]: value };
    }

    // ── Save ──────────────────────────────────────────────────────────────
    async handleSaveOverride() {
        const { Validation_Rule_Name__c, Permission_Set_Name__c, Override_Action__c }
            = this.draftOverride;

        if (!Validation_Rule_Name__c || !Permission_Set_Name__c || !Override_Action__c) {
            this._showToast(
                'Required Fields Missing',
                'Validation Rule, Permission Set, and Override Action are required.',
                'error'
            );
            return;
        }

        this.isSaving = true;
        try {
            // Build the Rule_Override__c payload — convert empty strings to null
            const record = {
                Validation_Rule_Name__c:  this.draftOverride.Validation_Rule_Name__c,
                Permission_Set_Name__c:   this.draftOverride.Permission_Set_Name__c,
                Override_Action__c:       this.draftOverride.Override_Action__c,
                Override_Message__c:      this.draftOverride.Override_Message__c  || null,
                Is_Active__c:             this.draftOverride.Is_Active__c         ?? true,
                Expires_On__c:            this.draftOverride.Expires_On__c        || null,
                Notes__c:                 this.draftOverride.Notes__c             || null
            };
            if (this.draftOverride.Id) {
                record.Id = this.draftOverride.Id;
            }

            await saveOverride({ override: record });
            this._showToast('Saved', 'Override saved successfully.', 'success');
            this.showModal = false;
            await refreshApex(this._wiredOverridesResult);
        } catch (error) {
            this._showToast('Save Error', this._extractMessage(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    // ── Delete ────────────────────────────────────────────────────────────
    async _doDelete(overrideId) {
        try {
            await deleteOverride({ overrideId });
            this._showToast('Deleted', 'Override deleted successfully.', 'success');
            await refreshApex(this._wiredOverridesResult);
        } catch (error) {
            this._showToast('Delete Error', this._extractMessage(error), 'error');
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────
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

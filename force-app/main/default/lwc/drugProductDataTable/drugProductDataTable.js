import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDrugProductsWithValidation from '@salesforce/apex/DrugProductController.getDrugProductsWithValidation';
import saveDrugProducts from '@salesforce/apex/DrugProductController.saveDrugProducts';
import enrichAndSave from '@salesforce/apex/DrugProductEnrichmentController.enrichAndSave';

// Maps wrapper.validationStatus to human-readable label and SLDS icon name
const VALIDATION_STATUS_LABELS = {
    valid:   'Valid',
    warning: 'Warning',
    invalid: 'Invalid'
};

const VALIDATION_STATUS_ICONS = {
    valid:   'utility:check',
    warning: 'utility:warning',
    invalid: 'utility:error'
};

const ROW_ACTIONS = [
    { label: 'Fetch FDA Data', name: 'fda_enrich' }
];

const COLUMNS = [
    { label: 'Drug Product #',    fieldName: 'Name',                  type: 'text',    sortable: true },
    { label: 'Product Name',      fieldName: 'Product_Name__c',       type: 'text',    sortable: true, editable: true },
    { label: 'Generic Name',      fieldName: 'Generic_Name__c',       type: 'text',    sortable: true, editable: true },
    { label: 'NDC Code',          fieldName: 'NDC_Code__c',           type: 'text',    sortable: true },
    { label: 'Therapeutic Area',  fieldName: 'Therapeutic_Area__c',   type: 'text',    sortable: true },
    { label: 'Dosage Form',       fieldName: 'Dosage_Form__c',        type: 'text',    sortable: true },
    { label: 'Strength',          fieldName: 'Strength__c',           type: 'text',    sortable: true, editable: true },
    { label: 'Classification',    fieldName: 'Drug_Classification__c',type: 'text',    sortable: true },
    { label: 'Regulatory Status', fieldName: 'Regulatory_Status__c',  type: 'text',    sortable: true },
    { label: 'Manufacturer',      fieldName: 'Manufacturer__c',       type: 'text',    sortable: true, editable: true },
    { label: 'FDA Approval',      fieldName: 'FDA_Approval_Date__c',  type: 'date',    sortable: true },
    { label: 'Orphan Drug',       fieldName: 'Orphan_Drug_Status__c', type: 'boolean', sortable: true },
    {
        label: 'Health',
        fieldName: 'validationStatusLabel',
        type: 'text',
        sortable: true,
        cellAttributes: {
            iconName:            { fieldName: 'validationStatusIcon' },
            iconPosition:        'left',
            iconAlternativeText: 'Validation status'
        }
    },
    { label: 'Patent Alert', fieldName: 'Patent_Expiry_Alert__c', type: 'boolean', sortable: true },
    { type: 'action', typeAttributes: { rowActions: ROW_ACTIONS } }
];

const DEBOUNCE_DELAY = 300;

export default class DrugProductDataTable extends NavigationMixin(LightningElement) {
    columns = COLUMNS;
    sortedBy;
    sortedDirection = 'asc';
    searchTerm = '';
    draftValues = [];
    errors = {};
    isLoading = false;

    _wiredResult;
    _rawData = [];
    _debounceTimer;

    /**
     * @description Wire handler for getDrugProductsWithValidation (cacheable=true).
     * Maps each DrugProductValidationWrapper to a flat record object suitable for
     * lightning-datatable, injecting computed validationStatusLabel and
     * validationStatusIcon properties for the Health column.
     */
    @wire(getDrugProductsWithValidation, { searchTerm: '$searchTerm' })
    wiredDrugProducts(result) {
        this._wiredResult = result;
        if (result.data) {
            this._rawData = result.data.map(wrapper => ({
                ...wrapper.record,
                validationStatus:      wrapper.validationStatus,
                validationStatusLabel: VALIDATION_STATUS_LABELS[wrapper.validationStatus] || wrapper.validationStatus,
                validationStatusIcon:  VALIDATION_STATUS_ICONS[wrapper.validationStatus]  || 'utility:info'
            }));
            this._applySorting();
        } else if (result.error) {
            this._rawData = [];
        }
    }

    get sortedData() {
        return this._rawData;
    }

    get recordCount() {
        return this._rawData.length;
    }

    get hasData() {
        return this._rawData.length > 0 && !this.isLoading;
    }

    get hasNoData() {
        return this._rawData.length === 0 && !this.isLoading && !this.hasError;
    }

    get hasError() {
        return this._wiredResult && this._wiredResult.error;
    }

    get errorMessage() {
        if (this._wiredResult && this._wiredResult.error) {
            return this._wiredResult.error.body
                ? this._wiredResult.error.body.message
                : 'An unexpected error occurred.';
        }
        return '';
    }

    handleSearchChange(event) {
        clearTimeout(this._debounceTimer);
        const value = event.target.value;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._debounceTimer = setTimeout(() => {
            this.searchTerm = value;
        }, DEBOUNCE_DELAY);
    }

    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;
        this._applySorting();
    }

    /**
     * @description Handles inline-edit saves for editable text columns.
     */
    async handleSave(event) {
        this.isLoading = true;
        const updatedFields = event.detail.draftValues;

        try {
            await saveDrugProducts({ records: updatedFields });
            this.draftValues = [];
            await refreshApex(this._wiredResult);
            this.dispatchEvent(
                new ShowToastEvent({
                    title:   'Success',
                    message: 'Drug product records updated successfully.',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title:   'Error Saving Records',
                    message: error.body ? error.body.message : 'An error occurred while saving.',
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * @description Handles row-level actions. Currently supports 'fda_enrich' which calls
     * enrichAndSave to fetch data from the OpenFDA API and update the record in place.
     */
    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'fda_enrich') {
            this.isLoading = true;
            try {
                await enrichAndSave({ recordId: row.Id });
                await refreshApex(this._wiredResult);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title:   'FDA Enrichment Complete',
                        message: `${row.Product_Name__c || row.Name} updated from FDA data.`,
                        variant: 'success'
                    })
                );
            } catch (error) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title:   'FDA Enrichment Failed',
                        message: error.body ? error.body.message : 'An error occurred during FDA enrichment.',
                        variant: 'error'
                    })
                );
            } finally {
                this.isLoading = false;
            }
        }
    }

    /**
     * @description Navigates to the standard new-record modal for Drug_Product__c.
     */
    handleNewRecord() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Drug_Product__c',
                actionName:    'new'
            }
        });
    }

    _applySorting() {
        if (!this.sortedBy) {
            return;
        }

        const fieldName = this.sortedBy;
        const isReverse = this.sortedDirection === 'desc' ? -1 : 1;

        this._rawData = [...this._rawData].sort((a, b) => {
            const valA = a[fieldName] ?? '';
            const valB = b[fieldName] ?? '';

            if (typeof valA === 'boolean') {
                return isReverse * ((valA === valB) ? 0 : valA ? -1 : 1);
            }

            if (typeof valA === 'number') {
                return isReverse * (valA - valB);
            }

            return isReverse * String(valA).localeCompare(String(valB));
        });
    }
}

/**
 * @description Child component that renders ValidationResult objects as colour-coded
 *              badges. Blocking errors render in error-red; downgraded warnings render
 *              in warning-amber. Shows a green "all pass" message when errors is empty.
 *
 *              Usage:
 *                <c-validation-badge-list errors={liveValidationErrors}>
 *                </c-validation-badge-list>
 */
import { LightningElement, api } from 'lwc';

export default class ValidationBadgeList extends LightningElement {
    /** @type {Array<{ruleName, fieldName, errorMessage, isBlockingError}>} */
    @api errors = [];

    get hasErrors() {
        return Array.isArray(this.errors) && this.errors.length > 0;
    }

    /**
     * Maps raw ValidationResult objects to template-friendly objects with
     * pre-computed CSS classes and icon names.
     */
    get processedErrors() {
        if (!this.errors) return [];
        return this.errors.map((e, idx) => ({
            key: e.ruleName || e.fieldName || String(idx),
            ruleName: e.ruleName,
            fieldName: e.fieldName,
            errorMessage: e.errorMessage,
            isBlockingError: e.isBlockingError,
            rowClass: e.isBlockingError
                ? 'badge-item badge-item_error'
                : 'badge-item badge-item_warning',
            iconName: e.isBlockingError ? 'utility:error' : 'utility:warning'
        }));
    }
}

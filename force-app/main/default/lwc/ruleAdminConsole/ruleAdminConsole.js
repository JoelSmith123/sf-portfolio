/**
 * @description Top-level admin console for viewing Validation_Rule__mdt records and
 *              managing runtime Rule_Override__c records. Access-gated by the
 *              Manage_Validation_Rules custom permission — renders an "Access Denied"
 *              message for users without the permission.
 *
 *              Architecture:
 *                - Wires getAllValidationRules() once and distributes rules to both
 *                  child components (read-only table + override editor).
 *                - Custom permission check uses the @salesforce/customPermission
 *                  module, which evaluates at component load time.
 *
 *              Placed on the Drug_Product_Admin_Page lightning__AppPage flexipage.
 */
import { LightningElement, wire } from 'lwc';
import hasManageValidationRules
    from '@salesforce/customPermission/Manage_Validation_Rules';
import getAllValidationRules
    from '@salesforce/apex/DrugProductAdminController.getAllValidationRules';

export default class RuleAdminConsole extends LightningElement {
    /** Validation_Rule__mdt records shared by both child components */
    rules = [];

    /** True when the running user holds the Manage_Validation_Rules custom permission */
    get hasPermission() {
        return hasManageValidationRules;
    }

    get ruleCount() {
        return this.rules.length;
    }

    @wire(getAllValidationRules)
    wiredRules({ error, data }) {
        if (data) {
            this.rules = data;
        } else if (error) {
            console.error('[RuleAdminConsole] Failed to load validation rules', error);
        }
    }
}

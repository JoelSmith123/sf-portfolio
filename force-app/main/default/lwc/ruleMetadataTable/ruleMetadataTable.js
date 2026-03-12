/**
 * @description Read-only display of all deployed Validation_Rule__mdt records.
 *              Stateless child component — receives rules as an @api prop from
 *              ruleAdminConsole and renders them in a fixed-layout table.
 *
 *              Columns: Rule Name · Field · Operator · Value · Error Message
 *                       · Condition (dependent field/value) · Active
 */
import { LightningElement, api } from 'lwc';

export default class RuleMetadataTable extends LightningElement {
    /** @type {Array<Validation_Rule__mdt>} */
    @api rules = [];

    get hasRules() {
        return Array.isArray(this.rules) && this.rules.length > 0;
    }

    /** Maps raw CMT records to template-friendly display objects */
    get processedRules() {
        return (this.rules || []).map(r => ({
            key:          r.DeveloperName,
            label:        r.MasterLabel,
            fieldName:    r.Field_Name__c   || '—',
            operator:     r.Operator__c     || '—',
            value:        r.Value__c        || '—',
            errorMessage: r.Error_Message__c || '—',
            condition:    r.Dependent_Field__c
                ? `${r.Dependent_Field__c} = "${r.Dependent_Value__c}"`
                : '—',
            isActive:     r.Is_Active__c
        }));
    }
}

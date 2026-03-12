/**
 * @description Wire-serializable wrapper for a Validation_Rule__mdt record,
 *              enriched with override context for the running user's permission sets.
 *              Returned by DrugProductEnrichmentController.getActiveRulesForCurrentUser()
 *              and used in the drugProductWorkbench LWC for client-side rule evaluation.
 */
public class ValidationRuleDefinition {

    /** @description Developer name of the Validation_Rule__mdt record */
    @AuraEnabled public String ruleName;

    /** @description API name of the object this rule applies to */
    @AuraEnabled public String objectName;

    /** @description API name of the field being validated */
    @AuraEnabled public String fieldName;

    /** @description Comparison operator (equals, not_equals, is_blank, is_not_blank,
     *               greater_than, less_than, contains) */
    @AuraEnabled public String operator;

    /** @description Expected value for the comparison (null for blank/not_blank operators) */
    @AuraEnabled public String value;

    /** @description User-facing error message shown when the rule fails */
    @AuraEnabled public String errorMessage;

    /** @description API name of the field that gates this rule (null if unconditional) */
    @AuraEnabled public String dependentField;

    /** @description Value the dependent field must equal for this rule to fire */
    @AuraEnabled public String dependentValue;

    /**
     * @description True if this rule is suppressed for the running user via a
     *              Rule_Override__c record with Override_Action__c = 'Suppress'.
     *              When true, the workbench skips this rule in client-side evaluation.
     */
    @AuraEnabled public Boolean isSuppressedForUser;

    /**
     * @description True if a Downgrade_To_Warning override is active for this rule.
     *              When true, failure shows a warning badge rather than a blocking error.
     */
    @AuraEnabled public Boolean isDowngradedToWarning;

    /**
     * @description Custom replacement error message when Override_Action__c = 'Override_Message'.
     *              Null if the rule uses its default Error_Message__c text.
     */
    @AuraEnabled public String overrideMessage;
}

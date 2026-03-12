/**
 * @description Wrapper class representing the result of a single validation rule evaluation.
 *              Contains the field that was evaluated, the outcome, and the associated
 *              error message if the rule failed.
 */
public class ValidationResult {

    /** @description API name of the field that was evaluated */
    @AuraEnabled public String fieldName;

    /** @description User-facing error message (populated on failure) */
    @AuraEnabled public String errorMessage;

    /** @description Whether the rule passed (true) or failed (false) */
    @AuraEnabled public Boolean passed;

    /** @description Developer name of the Validation_Rule__mdt record */
    @AuraEnabled public String ruleName;

    /**
     * @description When false, the failure is a UI-only warning and does not block save.
     *              Set by the Downgrade_To_Warning Rule_Override__c action. Defaults to true.
     */
    @AuraEnabled public Boolean isBlockingError;

    /**
     * @description Constructs a failed validation result that blocks save.
     * @param fieldName The field that failed validation.
     * @param errorMessage The error message to display.
     */
    public ValidationResult(String fieldName, String errorMessage) {
        this.fieldName = fieldName;
        this.errorMessage = errorMessage;
        this.passed = false;
        this.isBlockingError = true;
    }

    /**
     * @description Constructs a validation result with explicit pass/fail status.
     * @param fieldName The field that was evaluated.
     * @param ruleName The developer name of the rule.
     * @param passed Whether the rule passed.
     */
    public ValidationResult(String fieldName, String ruleName, Boolean passed) {
        this.fieldName = fieldName;
        this.ruleName = ruleName;
        this.passed = passed;
        this.errorMessage = null;
        this.isBlockingError = true;
    }
}

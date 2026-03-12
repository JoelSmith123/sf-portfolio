/**
 * @description Wrapper combining a Drug_Product__c record with the results of running
 *              all active validation rules against it. Returned in bulk by
 *              DrugProductController.getDrugProductsWithValidation() for use in the
 *              drugProductDataTable health badge column.
 */
public class DrugProductValidationWrapper {

    /** @description The Drug_Product__c record including all displayed and validated fields */
    @AuraEnabled public Drug_Product__c record;

    /**
     * @description All validation failures for this record. Includes both blocking errors
     *              (isBlockingError = true) and non-blocking warnings (isBlockingError = false).
     *              Empty list if the record passes every rule.
     */
    @AuraEnabled public List<ValidationResult> validationErrors;

    /**
     * @description Summary status derived from validationErrors:
     *              'valid'   — no failures
     *              'warning' — only non-blocking (downgraded) failures
     *              'invalid' — at least one blocking failure
     */
    @AuraEnabled public String validationStatus;
}

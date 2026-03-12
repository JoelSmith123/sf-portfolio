/**
 * @description Invocable Apex action for the Drug_Product_Patent_Expiry_Flag
 *              Record-Triggered Flow. Evaluates all active validation rules against a
 *              Drug_Product__c record and returns whether blocking violations exist, along
 *              with a joined summary string for use in Chatter post content.
 *
 *              Demonstrates that the rules engine is an invocable service, not just
 *              a trigger helper.
 */
public with sharing class DrugProductValidationFlowAction {

    /**
     * @description Input for the runValidationCheck invocable method.
     */
    public class ValidationFlagInput {
        @InvocableVariable(required=true label='Record Id')
        public Id recordId;
    }

    /**
     * @description Output returned by the runValidationCheck invocable method.
     */
    public class ValidationFlagOutput {
        @InvocableVariable(label='Has Violations')
        public Boolean hasViolations;

        @InvocableVariable(label='Violation Summary')
        public String violationSummary;
    }

    /**
     * @description Evaluates all active validation rules for the given Drug_Product__c record.
     *              Only blocking errors (isBlockingError = true) are counted as violations.
     *              Non-blocking warnings are excluded from the summary.
     * @param inputs List of ValidationFlagInput records.
     * @return List of ValidationFlagOutput with violation flag and semicolon-separated summary.
     */
    @InvocableMethod(
        label='Run Drug Product Validation Check'
        description='Evaluates all validation rules against a Drug_Product__c record and returns violation details for Flow conditions and Chatter posts.'
    )
    public static List<ValidationFlagOutput> runValidationCheck(List<ValidationFlagInput> inputs) {
        List<ValidationFlagOutput> outputs = new List<ValidationFlagOutput>();
        for (ValidationFlagInput input : inputs) {
            ValidationFlagOutput output = new ValidationFlagOutput();
            try {
                Drug_Product__c record = [
                    SELECT Id, Product_Name__c, Generic_Name__c, NDC_Code__c,
                           Regulatory_Status__c, Therapeutic_Area__c, Drug_Classification__c,
                           Dosage_Form__c, Strength__c, Manufacturer__c,
                           FDA_Approval_Date__c, Launch_Date__c, Patent_Expiration__c,
                           Orphan_Drug_Status__c
                    FROM Drug_Product__c
                    WHERE Id = :input.recordId
                    LIMIT 1
                ];

                Map<Integer, List<ValidationResult>> resultMap =
                    ValidationRuleEngine.evaluate('Drug_Product__c', new List<SObject>{ record });

                if (resultMap.isEmpty()) {
                    output.hasViolations   = false;
                    output.violationSummary = '';
                } else {
                    List<String> messages = new List<String>();
                    for (ValidationResult vr : resultMap.get(0)) {
                        if (vr.isBlockingError) {
                            messages.add(vr.errorMessage);
                        }
                    }
                    output.hasViolations    = !messages.isEmpty();
                    output.violationSummary = String.join(messages, '; ');
                }
            } catch (Exception e) {
                output.hasViolations    = false;
                output.violationSummary = '';
            }
            outputs.add(output);
        }
        return outputs;
    }
}

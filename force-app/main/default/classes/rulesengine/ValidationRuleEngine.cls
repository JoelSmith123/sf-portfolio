/**
 * @description Generic, data-driven validation engine that evaluates Validation_Rule__mdt
 *              custom metadata records against SObject records. No business logic is
 *              hardcoded — all rules come from metadata configuration.
 *
 *              Supports conditional rules via Dependent_Field__c / Dependent_Value__c:
 *              a rule only fires when the dependent field matches the dependent value.
 *
 *              Supported operators: equals, not_equals, is_blank, is_not_blank,
 *              greater_than, less_than, contains.
 */
public class ValidationRuleEngine {

    /**
     * @description Evaluates all active validation rules for the given object
     *              against a list of SObject records.
     * @param objectApiName The API name of the object (e.g., 'Drug_Product__c').
     * @param records The list of SObject records to validate.
     * @return A map of record index to list of ValidationResult failures.
     *         Only records with at least one failure appear in the map.
     */
    public static Map<Integer, List<ValidationResult>> evaluate(
        String objectApiName,
        List<SObject> records
    ) {
        List<Validation_Rule__mdt> activeRules = [
            SELECT DeveloperName, Field_Name__c, Operator__c, Value__c,
                   Error_Message__c, Dependent_Field__c, Dependent_Value__c
            FROM Validation_Rule__mdt
            WHERE Object_Name__c = :objectApiName
              AND Is_Active__c = true
        ];

        Map<Integer, List<ValidationResult>> resultMap = new Map<Integer, List<ValidationResult>>();

        for (Integer i = 0; i < records.size(); i++) {
            SObject record = records[i];

            for (Validation_Rule__mdt rule : activeRules) {
                // Check dependency condition
                if (String.isNotBlank(rule.Dependent_Field__c)) {
                    Object depValue = record.get(rule.Dependent_Field__c);
                    String depValueStr = (depValue != null) ? String.valueOf(depValue) : '';
                    if (depValueStr != rule.Dependent_Value__c) {
                        continue; // Rule does not apply to this record's current state
                    }
                }

                // Evaluate the target field
                Object fieldValue = record.get(rule.Field_Name__c);
                Boolean passes = evaluateOperator(rule.Operator__c, fieldValue, rule.Value__c);

                if (!passes) {
                    if (!resultMap.containsKey(i)) {
                        resultMap.put(i, new List<ValidationResult>());
                    }
                    resultMap.get(i).add(new ValidationResult(
                        rule.Field_Name__c,
                        rule.Error_Message__c
                    ));
                }
            }
        }

        return resultMap;
    }

    /**
     * @description Convenience method for trigger context. Evaluates records
     *              and adds errors directly to the SObject records via addError().
     * @param objectApiName The API name of the object.
     * @param records The Trigger.new list.
     */
    public static void validateAndAddErrors(String objectApiName, List<SObject> records) {
        Map<Integer, List<ValidationResult>> results = evaluate(objectApiName, records);

        for (Integer i : results.keySet()) {
            for (ValidationResult vr : results.get(i)) {
                records[i].addError(vr.fieldName, vr.errorMessage);
            }
        }
    }

    /**
     * @description Evaluates a single operator against a field value.
     * @param operator The operator string (e.g., 'equals', 'is_not_blank').
     * @param fieldValue The actual field value from the record.
     * @param expectedValue The expected value from the rule definition.
     * @return True if the field value passes the operator check; false otherwise.
     */
    @TestVisible
    private static Boolean evaluateOperator(String operator, Object fieldValue, String expectedValue) {
        String stringValue = (fieldValue != null) ? String.valueOf(fieldValue) : '';
        Boolean isBlank = String.isBlank(stringValue);

        switch on operator {
            when 'is_blank' {
                return isBlank;
            }
            when 'is_not_blank' {
                return !isBlank;
            }
            when 'equals' {
                return stringValue == expectedValue;
            }
            when 'not_equals' {
                return stringValue != expectedValue;
            }
            when 'contains' {
                return !isBlank && stringValue.containsIgnoreCase(expectedValue);
            }
            when 'greater_than' {
                if (isBlank || String.isBlank(expectedValue)) {
                    return false;
                }
                return Decimal.valueOf(stringValue) > Decimal.valueOf(expectedValue);
            }
            when 'less_than' {
                if (isBlank || String.isBlank(expectedValue)) {
                    return false;
                }
                return Decimal.valueOf(stringValue) < Decimal.valueOf(expectedValue);
            }
            when else {
                return true; // Unknown operators pass by default
            }
        }
    }
}

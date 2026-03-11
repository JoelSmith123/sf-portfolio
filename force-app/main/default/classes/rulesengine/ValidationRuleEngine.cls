/**
 * @description Generic, data-driven validation engine that evaluates Validation_Rule__mdt
 *              custom metadata records against SObject records. No business logic is
 *              hardcoded — all rules come from metadata configuration.
 *
 *              Supports conditional rules via Dependent_Field__c / Dependent_Value__c:
 *              a rule only fires when the dependent field matches the dependent value.
 *
 *              Supports runtime rule overrides via Rule_Override__c custom object:
 *              admins can suppress, rephrase, or downgrade rules per permission set
 *              without deploying new metadata.
 *
 *              Supported operators: equals, not_equals, is_blank, is_not_blank,
 *              greater_than, less_than, contains.
 */
public class ValidationRuleEngine {

    // Cached per-transaction to avoid repeated SOQL in bulk trigger context
    @TestVisible
    private static Set<String> cachedPermSetNames;

    /**
     * @description Evaluates all active validation rules for the given object
     *              against a list of SObject records. Applies any active Rule_Override__c
     *              records that match the running user's permission sets.
     * @param objectApiName The API name of the object (e.g., 'Drug_Product__c').
     * @param records The list of SObject records to validate.
     * @return A map of record index to list of ValidationResult failures.
     *         Only records with at least one failure appear in the map.
     *         Non-blocking warnings (Downgrade_To_Warning) are included with isBlockingError = false.
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

        // Load overrides scoped to the running user's permission sets
        Set<String> userPermSetNames = getUserPermissionSetNames();
        Map<String, Rule_Override__c> overridesByRuleName = getActiveOverrides(userPermSetNames);

        Map<Integer, List<ValidationResult>> resultMap = new Map<Integer, List<ValidationResult>>();

        for (Integer i = 0; i < records.size(); i++) {
            SObject record = records[i];

            for (Validation_Rule__mdt rule : activeRules) {
                // Check for a runtime override for this rule
                Rule_Override__c ruleOverride = overridesByRuleName.get(rule.DeveloperName);

                // Suppress: skip the rule entirely for this user's permission set
                if (ruleOverride != null && ruleOverride.Override_Action__c == 'Suppress') {
                    continue;
                }

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

                    // Override_Message substitutes a custom error message
                    String errorMessage = (ruleOverride != null
                        && ruleOverride.Override_Action__c == 'Override_Message'
                        && String.isNotBlank(ruleOverride.Override_Message__c))
                        ? ruleOverride.Override_Message__c
                        : rule.Error_Message__c;

                    // Downgrade_To_Warning makes the failure non-blocking (UI warning only)
                    Boolean isBlocking = !(ruleOverride != null
                        && ruleOverride.Override_Action__c == 'Downgrade_To_Warning');

                    ValidationResult vr = new ValidationResult(rule.Field_Name__c, errorMessage);
                    vr.ruleName = rule.DeveloperName;
                    vr.isBlockingError = isBlocking;
                    resultMap.get(i).add(vr);
                }
            }
        }

        return resultMap;
    }

    /**
     * @description Convenience method for trigger context. Evaluates records
     *              and adds errors directly to the SObject records via addError().
     *              Only blocking errors (isBlockingError = true) trigger addError;
     *              downgraded warnings do not block save.
     * @param objectApiName The API name of the object.
     * @param records The Trigger.new list.
     */
    public static void validateAndAddErrors(String objectApiName, List<SObject> records) {
        Map<Integer, List<ValidationResult>> results = evaluate(objectApiName, records);

        for (Integer i : results.keySet()) {
            for (ValidationResult vr : results.get(i)) {
                if (vr.isBlockingError) {
                    records[i].addError(vr.fieldName, vr.errorMessage);
                }
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

    /**
     * @description Returns the set of permission set names assigned to the running user.
     *              Excludes profile-based permission sets (IsOwnedByProfile = true) since
     *              those represent the user's profile, not explicit permission set assignments.
     *              Result is cached in a static variable to avoid repeated SOQL within
     *              a single transaction (e.g., bulk trigger context).
     * @return Set of permission set Name values (API names).
     */
    @TestVisible
    private static Set<String> getUserPermissionSetNames() {
        if (cachedPermSetNames != null) {
            return cachedPermSetNames;
        }
        cachedPermSetNames = new Set<String>();
        for (PermissionSetAssignment psa : [
            SELECT PermissionSet.Name
            FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
              AND PermissionSet.IsOwnedByProfile = false
        ]) {
            cachedPermSetNames.add(psa.PermissionSet.Name);
        }
        return cachedPermSetNames;
    }

    /**
     * @description Loads active, non-expired Rule_Override__c records for the given
     *              permission set names, keyed by Validation_Rule_Name__c.
     *              When multiple overrides target the same rule, the most recently
     *              created record wins (ORDER BY CreatedDate ASC so last write prevails).
     * @param permSetNames The set of permission set names to scope the query.
     * @return Map of validation rule developer name to its active override.
     */
    @TestVisible
    private static Map<String, Rule_Override__c> getActiveOverrides(Set<String> permSetNames) {
        Map<String, Rule_Override__c> overrideMap = new Map<String, Rule_Override__c>();
        if (permSetNames.isEmpty()) {
            return overrideMap;
        }
        for (Rule_Override__c ro : [
            SELECT Validation_Rule_Name__c, Override_Action__c, Override_Message__c
            FROM Rule_Override__c
            WHERE Permission_Set_Name__c IN :permSetNames
              AND Is_Active__c = true
              AND (Expires_On__c = null OR Expires_On__c >= TODAY)
            ORDER BY CreatedDate ASC
        ]) {
            overrideMap.put(ro.Validation_Rule_Name__c, ro);
        }
        return overrideMap;
    }
}

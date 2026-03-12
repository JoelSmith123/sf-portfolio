/**
 * @description Apex controller for the drugProductWorkbench LWC. Provides FDA data preview
 *              (read-only), active rule definitions enriched with per-user override context,
 *              server-side record evaluation, and the enrichAndSave row action.
 */
public with sharing class DrugProductEnrichmentController {

    /**
     * @description Returns all active validation rules for the specified object, enriched
     *              with override context for the running user's permission sets. Cacheable
     *              so the workbench LWC can wire this once at mount and evaluate rules
     *              client-side on every keystroke without additional Apex round-trips.
     * @param objectApiName The API name of the object (e.g., 'Drug_Product__c').
     * @return List of ValidationRuleDefinition wrappers with per-user override info.
     */
    @AuraEnabled(cacheable=true)
    public static List<ValidationRuleDefinition> getActiveRulesForCurrentUser(String objectApiName) {
        List<Validation_Rule__mdt> rules = [
            SELECT DeveloperName, Object_Name__c, Field_Name__c, Operator__c, Value__c,
                   Error_Message__c, Dependent_Field__c, Dependent_Value__c
            FROM Validation_Rule__mdt
            WHERE Object_Name__c = :objectApiName
              AND Is_Active__c = true
        ];

        Set<String> userPermSetNames = getUserPermissionSetNames();
        Map<String, Rule_Override__c> overridesByRuleName = getActiveOverrides(userPermSetNames);

        List<ValidationRuleDefinition> definitions = new List<ValidationRuleDefinition>();
        for (Validation_Rule__mdt rule : rules) {
            ValidationRuleDefinition def = new ValidationRuleDefinition();
            def.ruleName       = rule.DeveloperName;
            def.objectName     = rule.Object_Name__c;
            def.fieldName      = rule.Field_Name__c;
            def.operator       = rule.Operator__c;
            def.value          = rule.Value__c;
            def.errorMessage   = rule.Error_Message__c;
            def.dependentField = rule.Dependent_Field__c;
            def.dependentValue = rule.Dependent_Value__c;

            Rule_Override__c ruleOverride = overridesByRuleName.get(rule.DeveloperName);
            def.isSuppressedForUser    = (ruleOverride != null && ruleOverride.Override_Action__c == 'Suppress');
            def.isDowngradedToWarning  = (ruleOverride != null && ruleOverride.Override_Action__c == 'Downgrade_To_Warning');
            def.overrideMessage        = (ruleOverride != null
                && ruleOverride.Override_Action__c == 'Override_Message'
                && String.isNotBlank(ruleOverride.Override_Message__c))
                ? ruleOverride.Override_Message__c
                : null;
            definitions.add(def);
        }
        return definitions;
    }

    /**
     * @description Fetches proposed field values from OpenFDA for the given record without
     *              performing any DML. Used by the workbench to display a diff panel before
     *              the user decides to accept the proposed changes.
     * @param recordId The Id of the Drug_Product__c record to preview.
     * @return Map of field API name to proposed value. Empty map if no FDA match is found.
     * @throws AuraHandledException on API errors other than a 404 no-match.
     */
    @AuraEnabled
    public static Map<String, String> previewFDAEnrichment(Id recordId) {
        try {
            Drug_Product__c product = [
                SELECT Id, Product_Name__c, Generic_Name__c
                FROM Drug_Product__c
                WHERE Id = :recordId
                LIMIT 1
            ];

            OpenFDADrugResult fdaData;
            if (String.isNotBlank(product.Product_Name__c)) {
                fdaData = OpenFDAService.searchByBrandName(product.Product_Name__c);
            }
            if (fdaData == null && String.isNotBlank(product.Generic_Name__c)) {
                fdaData = OpenFDAService.searchByGenericName(product.Generic_Name__c);
            }
            if (fdaData == null) {
                return new Map<String, String>();
            }

            Map<String, String> proposed = new Map<String, String>();
            if (String.isNotBlank(fdaData.ndcCode)) {
                proposed.put('NDC_Code__c', fdaData.ndcCode);
            }
            if (String.isNotBlank(fdaData.manufacturerName)) {
                proposed.put('Manufacturer__c', fdaData.manufacturerName);
            }
            if (String.isNotBlank(fdaData.activeIngredients)) {
                proposed.put('Active_Ingredients__c', fdaData.activeIngredients);
            }
            if (String.isNotBlank(fdaData.indicationsAndUsage)) {
                proposed.put('Indications__c', fdaData.indicationsAndUsage);
            }
            if (String.isNotBlank(fdaData.warnings)) {
                proposed.put('Warnings__c', fdaData.warnings);
            }
            return proposed;
        } catch (OpenFDAException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Failed to fetch FDA data: ' + e.getMessage());
        }
    }

    /**
     * @description Server-side validation gate called before saving from the workbench.
     *              Constructs a Drug_Product__c from the LWC edit-state field values and runs
     *              ValidationRuleEngine against it. JSON deserialization handles type coercion
     *              for date and other field types sent as strings from JavaScript.
     * @param fieldValues Map of field API name to proposed value from the LWC edit state.
     * @param objectApiName The API name of the object being validated.
     * @return All ValidationResult failures, including non-blocking warnings. Empty if clean.
     * @throws AuraHandledException if evaluation fails unexpectedly.
     */
    @AuraEnabled
    public static List<ValidationResult> evaluateRecord(
        Map<String, Object> fieldValues,
        String objectApiName
    ) {
        try {
            String jsonStr = JSON.serialize(fieldValues);
            Drug_Product__c record = (Drug_Product__c) JSON.deserialize(jsonStr, Drug_Product__c.class);
            Map<Integer, List<ValidationResult>> resultMap =
                ValidationRuleEngine.evaluate(objectApiName, new List<SObject>{ record });
            return resultMap.containsKey(0) ? resultMap.get(0) : new List<ValidationResult>();
        } catch (Exception e) {
            throw new AuraHandledException('Validation evaluation failed: ' + e.getMessage());
        }
    }

    /**
     * @description Enriches a Drug_Product__c record with OpenFDA data and saves it.
     *              Delegates to OpenFDAService.enrichDrugProduct(), which performs the DML.
     *              Used by the row-level "Fetch FDA Data" action in the data table.
     * @param recordId The Id of the Drug_Product__c record to enrich.
     * @return The updated Drug_Product__c record.
     * @throws AuraHandledException if no FDA data is found or the API call fails.
     */
    @AuraEnabled
    public static Drug_Product__c enrichAndSave(Id recordId) {
        try {
            return OpenFDAService.enrichDrugProduct(recordId);
        } catch (OpenFDAException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Failed to enrich record: ' + e.getMessage());
        }
    }

    /**
     * @description Returns the permission set names assigned to the running user,
     *              excluding profile-based permission sets.
     * @return Set of permission set API names.
     */
    private static Set<String> getUserPermissionSetNames() {
        Set<String> permSetNames = new Set<String>();
        for (PermissionSetAssignment psa : [
            SELECT PermissionSet.Name
            FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
              AND PermissionSet.IsOwnedByProfile = false
        ]) {
            permSetNames.add(psa.PermissionSet.Name);
        }
        return permSetNames;
    }

    /**
     * @description Loads active, non-expired Rule_Override__c records for the given
     *              permission set names, keyed by Validation_Rule_Name__c.
     * @param permSetNames The set of permission set names to scope the query.
     * @return Map of validation rule developer name to its most recent active override.
     */
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

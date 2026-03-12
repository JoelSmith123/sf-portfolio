/**
 * @description Apex controller for the ruleAdminConsole LWC. Provides read-only access to
 *              Validation_Rule__mdt metadata and full CRUD on Rule_Override__c records.
 *              All write operations require the Manage_Validation_Rules custom permission.
 */
public with sharing class DrugProductAdminController {

    /**
     * @description Allows test classes to bypass FeatureManagement.checkPermission() without
     *              creating users with custom permission assignments in test context.
     *              Never set to true in production code.
     */
    @TestVisible
    private static Boolean skipPermissionCheckForTest = false;

    /**
     * @description Returns all Validation_Rule__mdt records for display in the admin console.
     *              These are deployment-controlled and shown as read-only in the UI.
     * @return All Validation_Rule__mdt records ordered by object name then label.
     */
    @AuraEnabled(cacheable=true)
    public static List<Validation_Rule__mdt> getAllValidationRules() {
        return [
            SELECT DeveloperName, MasterLabel, Object_Name__c, Field_Name__c,
                   Operator__c, Value__c, Error_Message__c,
                   Dependent_Field__c, Dependent_Value__c, Is_Active__c
            FROM Validation_Rule__mdt
            ORDER BY Object_Name__c ASC, MasterLabel ASC
        ];
    }

    /**
     * @description Returns all Rule_Override__c records for display in the admin console.
     * @return All Rule_Override__c records ordered by most recently created first.
     */
    @AuraEnabled(cacheable=true)
    public static List<Rule_Override__c> getAllOverrides() {
        return [
            SELECT Id, Name, Validation_Rule_Name__c, Permission_Set_Name__c,
                   Override_Action__c, Override_Message__c, Is_Active__c,
                   Expires_On__c, Notes__c, CreatedDate
            FROM Rule_Override__c
            ORDER BY CreatedDate DESC
        ];
    }

    /**
     * @description Returns permission set API names for the "New Override" modal dropdown.
     *              Excludes profile-based permission sets (IsOwnedByProfile = true).
     * @return List of permission set Name values ordered by label.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getPermissionSetNames() {
        List<String> names = new List<String>();
        for (PermissionSet ps : [
            SELECT Name
            FROM PermissionSet
            WHERE IsOwnedByProfile = false
            ORDER BY Label ASC
            LIMIT 200
        ]) {
            names.add(ps.Name);
        }
        return names;
    }

    /**
     * @description Creates or updates a Rule_Override__c record.
     *              Requires the Manage_Validation_Rules custom permission.
     * @param overrideRecord The Rule_Override__c record to insert or update.
     * @throws AuraHandledException if the user lacks permission or DML fails.
     */
    @AuraEnabled
    public static void saveOverride(Rule_Override__c overrideRecord) {
        checkAdminPermission();
        try {
            upsert overrideRecord;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Deletes a Rule_Override__c record by Id.
     *              Requires the Manage_Validation_Rules custom permission.
     * @param overrideId The Id of the Rule_Override__c record to delete.
     * @throws AuraHandledException if the user lacks permission or DML fails.
     */
    @AuraEnabled
    public static void deleteOverride(Id overrideId) {
        checkAdminPermission();
        try {
            delete [SELECT Id FROM Rule_Override__c WHERE Id = :overrideId LIMIT 1];
        } catch (DmlException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Asserts that the running user has the Manage_Validation_Rules custom
     *              permission. Throws AuraHandledException if the check fails.
     */
    private static void checkAdminPermission() {
        if (!skipPermissionCheckForTest
                && !FeatureManagement.checkPermission('Manage_Validation_Rules')) {
            throw new AuraHandledException(
                'You do not have permission to manage validation rule overrides.'
            );
        }
    }
}

/**
 * @description Test class for DrugProductAdminController. Covers metadata retrieval,
 *              permission set name query, override CRUD with and without the
 *              Manage_Validation_Rules custom permission. Uses @TestVisible bypass flag
 *              for permission-gated write paths.
 *              Target: 95%+ coverage.
 */
@IsTest
private class DrugProductAdminControllerTest {

    // ---------------------------------------------------------------------------
    // getAllValidationRules tests
    // ---------------------------------------------------------------------------

    @IsTest
    static void testGetAllValidationRules_ReturnsDrugProductRules() {
        Test.startTest();
        List<Validation_Rule__mdt> rules = DrugProductAdminController.getAllValidationRules();
        Test.stopTest();

        System.assert(!rules.isEmpty(), 'Should return at least one deployed validation rule');
        for (Validation_Rule__mdt rule : rules) {
            System.assertNotEquals(null, rule.DeveloperName, 'DeveloperName should not be null');
            System.assertNotEquals(null, rule.MasterLabel, 'MasterLabel should not be null');
        }
    }

    // ---------------------------------------------------------------------------
    // getAllOverrides tests
    // ---------------------------------------------------------------------------

    @IsTest
    static void testGetAllOverrides_EmptyInitially() {
        Test.startTest();
        List<Rule_Override__c> overrides = DrugProductAdminController.getAllOverrides();
        Test.stopTest();

        System.assertEquals(0, overrides.size(),
            'Should return empty list when no overrides exist in test context');
    }

    @IsTest
    static void testGetAllOverrides_ReturnsInsertedOverride() {
        insert new Rule_Override__c(
            Validation_Rule_Name__c = 'Test_Rule',
            Permission_Set_Name__c  = 'Drug_Product_Admin',
            Override_Action__c      = 'Suppress',
            Is_Active__c            = true
        );

        Test.startTest();
        List<Rule_Override__c> overrides = DrugProductAdminController.getAllOverrides();
        Test.stopTest();

        System.assertEquals(1, overrides.size(), 'Should return the inserted override');
        System.assertEquals('Test_Rule', overrides[0].Validation_Rule_Name__c,
            'Rule name should match');
    }

    // ---------------------------------------------------------------------------
    // getPermissionSetNames tests
    // ---------------------------------------------------------------------------

    @IsTest
    static void testGetPermissionSetNames_ReturnsDeployedPermSets() {
        Test.startTest();
        List<String> names = DrugProductAdminController.getPermissionSetNames();
        Test.stopTest();

        System.assertNotEquals(null, names, 'Names list should not be null');
        System.assert(!names.isEmpty(), 'At least one deployed permission set should be returned');
        // Deployed perm sets should be in the list
        System.assert(names.contains('Drug_Product_Access'), 'Drug_Product_Access should be in the list');
        System.assert(names.contains('Drug_Product_Admin'), 'Drug_Product_Admin should be in the list');
    }

    // ---------------------------------------------------------------------------
    // saveOverride tests
    // ---------------------------------------------------------------------------

    @IsTest
    static void testSaveOverride_WithoutPermission_ThrowsException() {
        Rule_Override__c ro = new Rule_Override__c(
            Validation_Rule_Name__c = 'Test_Rule',
            Permission_Set_Name__c  = 'Drug_Product_Admin',
            Override_Action__c      = 'Suppress',
            Is_Active__c            = true
        );

        Test.startTest();
        try {
            DrugProductAdminController.saveOverride(ro);
            System.assert(false, 'Should have thrown AuraHandledException for missing permission');
        } catch (AuraHandledException e) {
            // AuraHandledException.getMessage() returns 'Script-thrown exception' in Apex test
            // context — verifying the exception type was thrown is sufficient.
            System.assertNotEquals(null, e, 'AuraHandledException should have been thrown');
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveOverride_WithBypassedPermission_InsertsRecord() {
        Rule_Override__c ro = new Rule_Override__c(
            Validation_Rule_Name__c = 'Test_Rule',
            Permission_Set_Name__c  = 'Drug_Product_Admin',
            Override_Action__c      = 'Suppress',
            Is_Active__c            = true
        );
        DrugProductAdminController.skipPermissionCheckForTest = true;

        Test.startTest();
        DrugProductAdminController.saveOverride(ro);
        Test.stopTest();

        DrugProductAdminController.skipPermissionCheckForTest = false;
        List<Rule_Override__c> inserted = [
            SELECT Id, Validation_Rule_Name__c FROM Rule_Override__c
        ];
        System.assertEquals(1, inserted.size(), 'One override should be inserted');
        System.assertEquals('Test_Rule', inserted[0].Validation_Rule_Name__c,
            'Rule name should match');
    }

    @IsTest
    static void testSaveOverride_WithBypassedPermission_UpdatesExistingRecord() {
        Rule_Override__c ro = new Rule_Override__c(
            Validation_Rule_Name__c = 'Test_Rule',
            Permission_Set_Name__c  = 'Drug_Product_Admin',
            Override_Action__c      = 'Suppress',
            Is_Active__c            = true
        );
        insert ro;
        ro.Is_Active__c = false;
        DrugProductAdminController.skipPermissionCheckForTest = true;

        Test.startTest();
        DrugProductAdminController.saveOverride(ro);
        Test.stopTest();

        DrugProductAdminController.skipPermissionCheckForTest = false;
        Rule_Override__c updated = [
            SELECT Is_Active__c FROM Rule_Override__c WHERE Id = :ro.Id
        ];
        System.assertEquals(false, updated.Is_Active__c, 'Is_Active__c should be updated to false');
    }

    // ---------------------------------------------------------------------------
    // deleteOverride tests
    // ---------------------------------------------------------------------------

    @IsTest
    static void testDeleteOverride_WithoutPermission_ThrowsException() {
        Rule_Override__c ro = new Rule_Override__c(
            Validation_Rule_Name__c = 'Test_Rule',
            Permission_Set_Name__c  = 'Drug_Product_Admin',
            Override_Action__c      = 'Suppress',
            Is_Active__c            = true
        );
        insert ro;

        Test.startTest();
        try {
            DrugProductAdminController.deleteOverride(ro.Id);
            System.assert(false, 'Should have thrown AuraHandledException for missing permission');
        } catch (AuraHandledException e) {
            // AuraHandledException.getMessage() returns 'Script-thrown exception' in Apex test
            // context — verifying the exception type was thrown is sufficient.
            System.assertNotEquals(null, e, 'AuraHandledException should have been thrown');
        }
        Test.stopTest();
    }

    @IsTest
    static void testDeleteOverride_WithBypassedPermission_DeletesRecord() {
        Rule_Override__c ro = new Rule_Override__c(
            Validation_Rule_Name__c = 'Test_Rule',
            Permission_Set_Name__c  = 'Drug_Product_Admin',
            Override_Action__c      = 'Suppress',
            Is_Active__c            = true
        );
        insert ro;
        DrugProductAdminController.skipPermissionCheckForTest = true;

        Test.startTest();
        DrugProductAdminController.deleteOverride(ro.Id);
        Test.stopTest();

        DrugProductAdminController.skipPermissionCheckForTest = false;
        List<Rule_Override__c> remaining = [
            SELECT Id FROM Rule_Override__c WHERE Id = :ro.Id
        ];
        System.assertEquals(0, remaining.size(), 'Override should be deleted');
    }
}

/**
 * @description Test class for ValidationRuleEngine and DrugProductTrigger.
 *              Validates the data-driven rules engine by testing all three deployed
 *              validation rules through the trigger, plus direct engine evaluation,
 *              bulk operations, and edge cases. Target: 95%+ coverage.
 *
 *              Note: Custom metadata records (Validation_Rule__mdt) deployed to the org
 *              are automatically available in test context without SeeAllData=true.
 */
@IsTest
private class ValidationRuleEngineTest {

    // ---------------------------------------------------------------------------
    // Rule 1: Approved requires FDA Approval Date
    // ---------------------------------------------------------------------------

    @IsTest
    static void testApprovedWithoutFDADate_Fails() {
        Drug_Product__c product = new Drug_Product__c(
            Product_Name__c = 'Test Drug',
            Regulatory_Status__c = 'Approved'
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(product, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Insert should fail: Approved without FDA date');
        System.assert(
            sr.getErrors()[0].getMessage().contains('FDA Approval Date'),
            'Error should mention FDA Approval Date'
        );
    }

    @IsTest
    static void testApprovedWithFDADate_Passes() {
        Drug_Product__c product = new Drug_Product__c(
            Product_Name__c = 'Test Drug',
            Regulatory_Status__c = 'Approved',
            FDA_Approval_Date__c = Date.today()
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(product, false);
        Test.stopTest();

        System.assert(sr.isSuccess(), 'Insert should succeed: Approved with FDA date');
    }

    // ---------------------------------------------------------------------------
    // Rule 2: Launched requires Launch Date
    // ---------------------------------------------------------------------------

    @IsTest
    static void testLaunchedWithoutLaunchDate_Fails() {
        Drug_Product__c product = new Drug_Product__c(
            Product_Name__c = 'Test Drug',
            Regulatory_Status__c = 'Launched'
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(product, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Insert should fail: Launched without Launch Date');
        System.assert(
            sr.getErrors()[0].getMessage().contains('Launch Date'),
            'Error should mention Launch Date'
        );
    }

    @IsTest
    static void testLaunchedWithLaunchDate_Passes() {
        Drug_Product__c product = new Drug_Product__c(
            Product_Name__c = 'Test Drug',
            Regulatory_Status__c = 'Launched',
            Launch_Date__c = Date.today()
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(product, false);
        Test.stopTest();

        System.assert(sr.isSuccess(), 'Insert should succeed: Launched with Launch Date');
    }

    // ---------------------------------------------------------------------------
    // Rule 3: Controlled Substance requires Warnings
    // ---------------------------------------------------------------------------

    @IsTest
    static void testControlledSubstanceWithoutWarnings_Fails() {
        Drug_Product__c product = new Drug_Product__c(
            Product_Name__c = 'Test Drug',
            Drug_Classification__c = 'Controlled Substance'
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(product, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Insert should fail: Controlled Substance without Warnings');
        System.assert(
            sr.getErrors()[0].getMessage().contains('Warnings'),
            'Error should mention Warnings'
        );
    }

    @IsTest
    static void testControlledSubstanceWithWarnings_Passes() {
        Drug_Product__c product = new Drug_Product__c(
            Product_Name__c = 'Test Drug',
            Drug_Classification__c = 'Controlled Substance',
            Warnings__c = 'Contains controlled substance. Risk of dependence.'
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(product, false);
        Test.stopTest();

        System.assert(sr.isSuccess(), 'Insert should succeed: Controlled Substance with Warnings');
    }

    // ---------------------------------------------------------------------------
    // Dependency condition: rules should be skipped when condition doesn't match
    // ---------------------------------------------------------------------------

    @IsTest
    static void testNonApprovedStatus_SkipsApprovedRule() {
        Drug_Product__c product = new Drug_Product__c(
            Product_Name__c = 'Test Drug',
            Regulatory_Status__c = 'In Discovery'
            // No FDA date, but rule shouldn't fire for In Discovery
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(product, false);
        Test.stopTest();

        System.assert(sr.isSuccess(), 'In Discovery should not require FDA Approval Date');
    }

    @IsTest
    static void testRxClassification_SkipsControlledSubstanceRule() {
        Drug_Product__c product = new Drug_Product__c(
            Product_Name__c = 'Test Drug',
            Drug_Classification__c = 'Rx'
            // No Warnings, but rule only applies to Controlled Substance
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(product, false);
        Test.stopTest();

        System.assert(sr.isSuccess(), 'Rx classification should not require Warnings');
    }

    // ---------------------------------------------------------------------------
    // Update triggers validation
    // ---------------------------------------------------------------------------

    @IsTest
    static void testUpdateTriggersValidation() {
        Drug_Product__c product = new Drug_Product__c(
            Product_Name__c = 'Test Drug',
            Regulatory_Status__c = 'Phase 3'
        );
        insert product;

        product.Regulatory_Status__c = 'Approved';
        // FDA_Approval_Date__c is still null

        Test.startTest();
        Database.SaveResult sr = Database.update(product, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Update to Approved without FDA date should fail');
    }

    // ---------------------------------------------------------------------------
    // Multiple rule violations on the same record
    // ---------------------------------------------------------------------------

    @IsTest
    static void testMultipleRuleViolations() {
        Drug_Product__c product = new Drug_Product__c(
            Product_Name__c = 'Test Drug',
            Regulatory_Status__c = 'Approved',
            Drug_Classification__c = 'Controlled Substance'
            // Both FDA_Approval_Date__c and Warnings__c are null
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(product, false);
        Test.stopTest();

        System.assert(!sr.isSuccess(), 'Should fail with multiple violations');
        System.assert(sr.getErrors().size() >= 2,
            'Should have at least 2 errors, got: ' + sr.getErrors().size());
    }

    // ---------------------------------------------------------------------------
    // Bulk operations
    // ---------------------------------------------------------------------------

    @IsTest
    static void testBulkInsert_MixedValidInvalid() {
        List<Drug_Product__c> products = new List<Drug_Product__c>();

        // 100 valid records
        for (Integer i = 0; i < 100; i++) {
            products.add(new Drug_Product__c(
                Product_Name__c = 'Valid Drug ' + i,
                Regulatory_Status__c = 'In Discovery'
            ));
        }
        // 100 invalid records (Approved without FDA date)
        for (Integer i = 0; i < 100; i++) {
            products.add(new Drug_Product__c(
                Product_Name__c = 'Invalid Drug ' + i,
                Regulatory_Status__c = 'Approved'
            ));
        }

        Test.startTest();
        List<Database.SaveResult> results = Database.insert(products, false);
        Test.stopTest();

        Integer successCount = 0;
        Integer failCount = 0;
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                successCount++;
            } else {
                failCount++;
            }
        }
        System.assertEquals(100, successCount, 'First 100 valid records should succeed');
        System.assertEquals(100, failCount, 'Last 100 invalid records should fail');
    }

    // ---------------------------------------------------------------------------
    // Direct engine evaluation (not via trigger)
    // ---------------------------------------------------------------------------

    @IsTest
    static void testEvaluateMethod_DirectCall() {
        Drug_Product__c product = new Drug_Product__c(
            Product_Name__c = 'Direct Test',
            Regulatory_Status__c = 'Approved'
            // No FDA date
        );

        Test.startTest();
        Map<Integer, List<ValidationResult>> results =
            ValidationRuleEngine.evaluate('Drug_Product__c', new List<SObject>{ product });
        Test.stopTest();

        System.assert(results.containsKey(0), 'Should have results for index 0');
        System.assert(!results.get(0).isEmpty(), 'Should have at least one failure');

        ValidationResult vr = results.get(0)[0];
        System.assertEquals('FDA_Approval_Date__c', vr.fieldName, 'Field name should match');
        System.assertEquals(false, vr.passed, 'Result should indicate failure');
        System.assert(vr.errorMessage.contains('FDA Approval Date'), 'Error message should match');
    }

    @IsTest
    static void testEvaluateMethod_NoRulesForObject() {
        // Use a different object name that has no rules configured
        Account acc = new Account(Name = 'Test Account');

        Test.startTest();
        Map<Integer, List<ValidationResult>> results =
            ValidationRuleEngine.evaluate('Account', new List<SObject>{ acc });
        Test.stopTest();

        System.assert(results.isEmpty(), 'Should have no results for object with no rules');
    }

    // ---------------------------------------------------------------------------
    // Operator coverage: equals and not_equals
    // ---------------------------------------------------------------------------

    @IsTest
    static void testEvaluateOperator_Equals() {
        Test.startTest();
        System.assert(
            ValidationRuleEngine.evaluateOperator('equals', 'Approved', 'Approved'),
            'Should pass when values are equal'
        );
        System.assert(
            !ValidationRuleEngine.evaluateOperator('equals', 'Launched', 'Approved'),
            'Should fail when values are not equal'
        );
        Test.stopTest();
    }

    @IsTest
    static void testEvaluateOperator_NotEquals() {
        Test.startTest();
        System.assert(
            ValidationRuleEngine.evaluateOperator('not_equals', 'Launched', 'Approved'),
            'Should pass when values differ'
        );
        System.assert(
            !ValidationRuleEngine.evaluateOperator('not_equals', 'Approved', 'Approved'),
            'Should fail when values are same'
        );
        Test.stopTest();
    }

    @IsTest
    static void testEvaluateOperator_Contains() {
        Test.startTest();
        System.assert(
            ValidationRuleEngine.evaluateOperator('contains', 'Oncology Department', 'Oncology'),
            'Should pass when value contains expected'
        );
        System.assert(
            !ValidationRuleEngine.evaluateOperator('contains', 'Cardiology', 'Oncology'),
            'Should fail when value does not contain expected'
        );
        Test.stopTest();
    }

    @IsTest
    static void testEvaluateOperator_GreaterThanLessThan() {
        Test.startTest();
        System.assert(
            ValidationRuleEngine.evaluateOperator('greater_than', 100, '50'),
            'Should pass when field > expected'
        );
        System.assert(
            !ValidationRuleEngine.evaluateOperator('greater_than', 30, '50'),
            'Should fail when field < expected'
        );
        System.assert(
            ValidationRuleEngine.evaluateOperator('less_than', 30, '50'),
            'Should pass when field < expected'
        );
        System.assert(
            !ValidationRuleEngine.evaluateOperator('less_than', 100, '50'),
            'Should fail when field > expected'
        );
        // Blank values
        System.assert(
            !ValidationRuleEngine.evaluateOperator('greater_than', null, '50'),
            'Should fail when field is null for greater_than'
        );
        System.assert(
            !ValidationRuleEngine.evaluateOperator('less_than', null, '50'),
            'Should fail when field is null for less_than'
        );
        Test.stopTest();
    }

    @IsTest
    static void testEvaluateOperator_UnknownOperator() {
        Test.startTest();
        System.assert(
            ValidationRuleEngine.evaluateOperator('unknown_op', 'value', 'expected'),
            'Unknown operators should pass by default'
        );
        Test.stopTest();
    }
}

/**
 * @description Test class for DrugProductEnrichmentController. Covers active rule loading
 *              with override context, FDA preview (success and no-match), server-side
 *              record evaluation, and enrichAndSave. Uses HttpCalloutMock for all FDA calls.
 *              Target: 95%+ coverage.
 */
@IsTest
private class DrugProductEnrichmentControllerTest {

    // ---------------------------------------------------------------------------
    // Mock implementations
    // ---------------------------------------------------------------------------

    private class OpenFDAMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        OpenFDAMock(Integer statusCode, String responseBody) {
            this.statusCode   = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setBody(this.responseBody);
            return res;
        }
    }

    // ---------------------------------------------------------------------------
    // Mock response payloads
    // ---------------------------------------------------------------------------

    private static final String SUCCESS_RESPONSE = '{'
        + '"meta": {"results": {"skip": 0, "limit": 1, "total": 1}},'
        + '"results": [{'
        + '  "indications_and_usage": ["HUMIRA is indicated for treatment of rheumatoid arthritis."],'
        + '  "warnings_and_cautions": ["SERIOUS INFECTIONS: Patients are at increased risk."],'
        + '  "openfda": {'
        + '    "brand_name": ["HUMIRA"],'
        + '    "generic_name": ["ADALIMUMAB"],'
        + '    "manufacturer_name": ["AbbVie Inc."],'
        + '    "product_ndc": ["0074-3799"],'
        + '    "substance_name": ["ADALIMUMAB"]'
        + '  }'
        + '}]'
        + '}';

    private static final String NOT_FOUND_RESPONSE =
        '{"error":{"code":"NOT_FOUND","message":"No matches found!"}}';

    // ---------------------------------------------------------------------------
    // Test data
    // ---------------------------------------------------------------------------

    @TestSetup
    static void setupTestData() {
        insert new Drug_Product__c(
            Product_Name__c      = 'Humira',
            Generic_Name__c      = 'adalimumab',
            Regulatory_Status__c = 'Approved',
            FDA_Approval_Date__c = Date.newInstance(2002, 12, 31)
        );
    }

    // ---------------------------------------------------------------------------
    // getActiveRulesForCurrentUser tests
    // ---------------------------------------------------------------------------

    @IsTest
    static void testGetActiveRulesForCurrentUser_ReturnsDrugProductRules() {
        Test.startTest();
        List<ValidationRuleDefinition> rules =
            DrugProductEnrichmentController.getActiveRulesForCurrentUser('Drug_Product__c');
        Test.stopTest();

        System.assert(!rules.isEmpty(), 'Should return at least one active rule for Drug_Product__c');
        for (ValidationRuleDefinition def : rules) {
            System.assertEquals('Drug_Product__c', def.objectName, 'Object name should match');
            System.assertNotEquals(null, def.ruleName, 'Rule name should not be null');
            System.assertNotEquals(null, def.fieldName, 'Field name should not be null');
            System.assertNotEquals(null, def.isSuppressedForUser, 'isSuppressedForUser should not be null');
            System.assertNotEquals(null, def.isDowngradedToWarning, 'isDowngradedToWarning should not be null');
        }
    }

    @IsTest
    static void testGetActiveRulesForCurrentUser_NoRulesForOtherObject() {
        Test.startTest();
        List<ValidationRuleDefinition> rules =
            DrugProductEnrichmentController.getActiveRulesForCurrentUser('Contact');
        Test.stopTest();

        System.assertEquals(0, rules.size(), 'Should return no rules for an object with no configured rules');
    }

    @IsTest
    static void testGetActiveRulesForCurrentUser_OverrideNotAppliedWithoutPermSet() {
        // Insert a suppress override for the first active rule
        List<Validation_Rule__mdt> activeRules = [
            SELECT DeveloperName FROM Validation_Rule__mdt
            WHERE Object_Name__c = 'Drug_Product__c' AND Is_Active__c = true
            LIMIT 1
        ];
        System.assert(!activeRules.isEmpty(), 'Prerequisite: at least one active rule must exist');
        String ruleName = activeRules[0].DeveloperName;

        insert new Rule_Override__c(
            Validation_Rule_Name__c = ruleName,
            Permission_Set_Name__c  = 'Drug_Product_Admin',
            Override_Action__c      = 'Suppress',
            Is_Active__c            = true
        );

        // Test user does not have Drug_Product_Admin — suppress should NOT apply
        Test.startTest();
        List<ValidationRuleDefinition> rules =
            DrugProductEnrichmentController.getActiveRulesForCurrentUser('Drug_Product__c');
        Test.stopTest();

        Boolean foundRule = false;
        for (ValidationRuleDefinition def : rules) {
            if (def.ruleName == ruleName) {
                foundRule = true;
                System.assertEquals(false, def.isSuppressedForUser,
                    'Rule should not be suppressed for a user without the target permission set');
            }
        }
        System.assert(foundRule, 'Rule should still appear in the list even when an override exists');
    }

    // ---------------------------------------------------------------------------
    // previewFDAEnrichment tests
    // ---------------------------------------------------------------------------

    @IsTest
    static void testPreviewFDAEnrichment_Success_ReturnsMappedFields() {
        Test.setMock(HttpCalloutMock.class, new OpenFDAMock(200, SUCCESS_RESPONSE));
        Drug_Product__c product = [SELECT Id FROM Drug_Product__c LIMIT 1];

        Test.startTest();
        Map<String, String> proposed =
            DrugProductEnrichmentController.previewFDAEnrichment(product.Id);
        Test.stopTest();

        System.assert(proposed.containsKey('Manufacturer__c'), 'Should have Manufacturer__c');
        System.assertEquals('AbbVie Inc.', proposed.get('Manufacturer__c'), 'Manufacturer should match');
        System.assert(proposed.containsKey('NDC_Code__c'), 'Should have NDC_Code__c');
        System.assertEquals('0074-3799', proposed.get('NDC_Code__c'), 'NDC code should match');
        System.assert(proposed.containsKey('Active_Ingredients__c'), 'Should have Active_Ingredients__c');
        System.assert(proposed.containsKey('Indications__c'), 'Should have Indications__c');
        System.assert(proposed.containsKey('Warnings__c'), 'Should have Warnings__c');
    }

    @IsTest
    static void testPreviewFDAEnrichment_NoMatch_ReturnsEmptyMap() {
        Test.setMock(HttpCalloutMock.class, new OpenFDAMock(404, NOT_FOUND_RESPONSE));
        Drug_Product__c product = [SELECT Id FROM Drug_Product__c LIMIT 1];

        Test.startTest();
        Map<String, String> proposed =
            DrugProductEnrichmentController.previewFDAEnrichment(product.Id);
        Test.stopTest();

        System.assert(proposed.isEmpty(), 'Empty map should be returned when no FDA match found');
    }

    // ---------------------------------------------------------------------------
    // evaluateRecord tests
    // ---------------------------------------------------------------------------

    @IsTest
    static void testEvaluateRecord_Phase3_ReturnsEmpty() {
        // 'Phase 3' has no conditional rule dependencies — should pass all rules
        Map<String, Object> fieldValues = new Map<String, Object>{
            'Regulatory_Status__c' => 'Phase 3'
        };

        Test.startTest();
        List<ValidationResult> results =
            DrugProductEnrichmentController.evaluateRecord(fieldValues, 'Drug_Product__c');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Phase 3 record should pass all validation rules');
    }

    @IsTest
    static void testEvaluateRecord_ApprovedWithoutFDADate_ReturnsFailure() {
        Map<String, Object> fieldValues = new Map<String, Object>{
            'Regulatory_Status__c' => 'Approved'
            // FDA_Approval_Date__c intentionally omitted
        };

        Test.startTest();
        List<ValidationResult> results =
            DrugProductEnrichmentController.evaluateRecord(fieldValues, 'Drug_Product__c');
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Should return at least one failure');
        Boolean foundFDADateError = false;
        for (ValidationResult vr : results) {
            if (vr.errorMessage != null && vr.errorMessage.contains('FDA Approval Date')) {
                foundFDADateError = true;
            }
        }
        System.assert(foundFDADateError, 'Should include FDA Approval Date error');
    }

    @IsTest
    static void testEvaluateRecord_UnknownObject_ReturnsEmpty() {
        Map<String, Object> fieldValues = new Map<String, Object>{ 'Name' => 'Test' };

        Test.startTest();
        List<ValidationResult> results =
            DrugProductEnrichmentController.evaluateRecord(fieldValues, 'Contact');
        Test.stopTest();

        // No rules configured for Contact — should return empty list without error
        System.assertEquals(0, results.size(), 'Unknown object should return empty results');
    }

    // ---------------------------------------------------------------------------
    // enrichAndSave tests
    // ---------------------------------------------------------------------------

    @IsTest
    static void testEnrichAndSave_Success_UpdatesRecord() {
        Test.setMock(HttpCalloutMock.class, new OpenFDAMock(200, SUCCESS_RESPONSE));
        Drug_Product__c product = [SELECT Id FROM Drug_Product__c LIMIT 1];

        Test.startTest();
        Drug_Product__c enriched = DrugProductEnrichmentController.enrichAndSave(product.Id);
        Test.stopTest();

        System.assertNotEquals(null, enriched, 'Should return updated record');
        Drug_Product__c refreshed = [
            SELECT Manufacturer__c FROM Drug_Product__c WHERE Id = :product.Id
        ];
        System.assertEquals('AbbVie Inc.', refreshed.Manufacturer__c,
            'Manufacturer should be updated after enrichment');
    }

    @IsTest
    static void testEnrichAndSave_NoMatch_ThrowsAuraHandledException() {
        Test.setMock(HttpCalloutMock.class, new OpenFDAMock(404, NOT_FOUND_RESPONSE));
        Drug_Product__c product = [SELECT Id FROM Drug_Product__c LIMIT 1];

        Test.startTest();
        try {
            DrugProductEnrichmentController.enrichAndSave(product.Id);
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Error message should not be null');
        }
        Test.stopTest();
    }
}

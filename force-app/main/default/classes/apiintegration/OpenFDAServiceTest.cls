/**
 * @description Test class for OpenFDAService. Uses HttpCalloutMock to simulate
 *              FDA API responses across success, error, timeout, and edge-case scenarios.
 *              Target: 95%+ code coverage.
 */
@IsTest
private class OpenFDAServiceTest {

    // ---------------------------------------------------------------------------
    // Mock implementation
    // ---------------------------------------------------------------------------

    private class OpenFDAMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        OpenFDAMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setBody(this.responseBody);
            return res;
        }
    }

    private class TimeoutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new System.CalloutException('Read timed out');
        }
    }

    // ---------------------------------------------------------------------------
    // Mock response payloads
    // ---------------------------------------------------------------------------

    private static final String SUCCESS_RESPONSE = '{'
        + '"meta": {"results": {"skip": 0, "limit": 1, "total": 1}},'
        + '"results": [{'
        + '  "indications_and_usage": ["HUMIRA is indicated for treatment of rheumatoid arthritis."],'
        + '  "warnings_and_cautions": ["SERIOUS INFECTIONS: Patients treated with HUMIRA are at increased risk for developing serious infections."],'
        + '  "active_ingredient": ["adalimumab 40mg"],'
        + '  "dosage_forms_and_strengths": ["Injection: 40 mg/0.8 mL in a single-dose prefilled syringe"],'
        + '  "openfda": {'
        + '    "brand_name": ["HUMIRA"],'
        + '    "generic_name": ["ADALIMUMAB"],'
        + '    "manufacturer_name": ["AbbVie Inc."],'
        + '    "product_ndc": ["0074-3799"],'
        + '    "substance_name": ["ADALIMUMAB"],'
        + '    "product_type": ["HUMAN PRESCRIPTION DRUG"],'
        + '    "route": ["SUBCUTANEOUS"]'
        + '  }'
        + '}]'
        + '}';

    private static final String OTC_RESPONSE = '{'
        + '"meta": {"results": {"skip": 0, "limit": 1, "total": 1}},'
        + '"results": [{'
        + '  "indications_and_usage": ["Temporarily relieves minor aches and pains."],'
        + '  "warnings": ["Stomach bleeding warning: This product contains an NSAID."],'
        + '  "active_ingredient": ["Ibuprofen 200 mg"],'
        + '  "openfda": {'
        + '    "brand_name": ["ADVIL"],'
        + '    "generic_name": ["IBUPROFEN"],'
        + '    "manufacturer_name": ["Pfizer Consumer Healthcare"],'
        + '    "product_ndc": ["0573-0150"],'
        + '    "product_type": ["HUMAN OTC DRUG"],'
        + '    "route": ["ORAL"]'
        + '  }'
        + '}]'
        + '}';

    private static final String NO_OPENFDA_RESPONSE = '{'
        + '"meta": {"results": {"skip": 0, "limit": 1, "total": 1}},'
        + '"results": [{'
        + '  "indications_and_usage": ["For the treatment of bacterial infections."],'
        + '  "warnings": ["May cause allergic reactions."]'
        + '}]'
        + '}';

    private static final String NOT_FOUND_RESPONSE = '{"error":{"code":"NOT_FOUND","message":"No matches found!"}}';

    private static final String MALFORMED_JSON = '{"results": [{"bad":';

    private static final String EMPTY_RESULTS = '{"meta":{"results":{"total":0}},"results":[]}';

    // ---------------------------------------------------------------------------
    // Test data setup
    // ---------------------------------------------------------------------------

    @TestSetup
    static void setupTestData() {
        Drug_Product__c testProduct = new Drug_Product__c(
            Product_Name__c = 'Humira',
            Generic_Name__c = 'adalimumab',
            Regulatory_Status__c = 'Approved',
            FDA_Approval_Date__c = Date.newInstance(2002, 12, 31)
        );
        insert testProduct;
    }

    // ---------------------------------------------------------------------------
    // searchByBrandName tests
    // ---------------------------------------------------------------------------

    @IsTest
    static void testSearchByBrandName_Success() {
        Test.setMock(HttpCalloutMock.class, new OpenFDAMock(200, SUCCESS_RESPONSE));

        Test.startTest();
        OpenFDADrugResult result = OpenFDAService.searchByBrandName('Humira');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('HUMIRA', result.brandName, 'Brand name should match');
        System.assertEquals('ADALIMUMAB', result.genericName, 'Generic name should match');
        System.assertEquals('AbbVie Inc.', result.manufacturerName, 'Manufacturer should match');
        System.assertEquals('0074-3799', result.ndcCode, 'NDC code should match');
        System.assertEquals('ADALIMUMAB', result.activeIngredients, 'Active ingredients should match');
        System.assert(result.indicationsAndUsage.contains('rheumatoid arthritis'), 'Indications should contain expected text');
        System.assert(result.warnings.contains('SERIOUS INFECTIONS'), 'Warnings should contain expected text');
        System.assertEquals('SUBCUTANEOUS', result.route, 'Route should match');
    }

    @IsTest
    static void testSearchByGenericName_Success() {
        Test.setMock(HttpCalloutMock.class, new OpenFDAMock(200, SUCCESS_RESPONSE));

        Test.startTest();
        OpenFDADrugResult result = OpenFDAService.searchByGenericName('adalimumab');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('ADALIMUMAB', result.genericName, 'Generic name should match');
    }

    @IsTest
    static void testSearchByBrandName_OTC_WarningsFallback() {
        Test.setMock(HttpCalloutMock.class, new OpenFDAMock(200, OTC_RESPONSE));

        Test.startTest();
        OpenFDADrugResult result = OpenFDAService.searchByBrandName('Advil');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.warnings.contains('NSAID'), 'OTC warnings should fall back to warnings field');
        System.assertEquals('ADVIL', result.brandName, 'Brand name should match');
    }

    @IsTest
    static void testSearchByBrandName_NotFound_ReturnsNull() {
        Test.setMock(HttpCalloutMock.class, new OpenFDAMock(404, NOT_FOUND_RESPONSE));

        Test.startTest();
        OpenFDADrugResult result = OpenFDAService.searchByBrandName('NonExistentDrug12345');
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null when drug is not found');
    }

    @IsTest
    static void testSearchByBrandName_EmptyResults_ReturnsNull() {
        Test.setMock(HttpCalloutMock.class, new OpenFDAMock(200, EMPTY_RESULTS));

        Test.startTest();
        OpenFDADrugResult result = OpenFDAService.searchByBrandName('EmptyResultsDrug');
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null when results array is empty');
    }

    @IsTest
    static void testSearchByBrandName_RateLimited_ThrowsException() {
        Test.setMock(HttpCalloutMock.class, new OpenFDAMock(429, ''));

        Test.startTest();
        try {
            OpenFDAService.searchByBrandName('Humira');
            System.assert(false, 'Should have thrown OpenFDAException');
        } catch (OpenFDAException e) {
            System.assert(e.getMessage().contains('rate limit'), 'Error should mention rate limit');
        }
        Test.stopTest();
    }

    @IsTest
    static void testSearchByBrandName_ServerError_ThrowsException() {
        Test.setMock(HttpCalloutMock.class, new OpenFDAMock(500, 'Internal Server Error'));

        Test.startTest();
        try {
            OpenFDAService.searchByBrandName('Humira');
            System.assert(false, 'Should have thrown OpenFDAException');
        } catch (OpenFDAException e) {
            System.assert(e.getMessage().contains('HTTP 500'), 'Error should contain status code');
        }
        Test.stopTest();
    }

    @IsTest
    static void testSearchByBrandName_MalformedJSON_ThrowsException() {
        Test.setMock(HttpCalloutMock.class, new OpenFDAMock(200, MALFORMED_JSON));

        Test.startTest();
        try {
            OpenFDAService.searchByBrandName('Humira');
            System.assert(false, 'Should have thrown OpenFDAException');
        } catch (OpenFDAException e) {
            System.assert(e.getMessage().contains('Failed to parse'), 'Error should mention parse failure');
        }
        Test.stopTest();
    }

    @IsTest
    static void testSearchByBrandName_Timeout_ThrowsException() {
        Test.setMock(HttpCalloutMock.class, new TimeoutMock());

        Test.startTest();
        try {
            OpenFDAService.searchByBrandName('Humira');
            System.assert(false, 'Should have thrown OpenFDAException');
        } catch (OpenFDAException e) {
            System.assert(e.getMessage().contains('timed out'), 'Error should mention timeout');
        }
        Test.stopTest();
    }

    @IsTest
    static void testSearchByBrandName_MissingOpenFDA() {
        Test.setMock(HttpCalloutMock.class, new OpenFDAMock(200, NO_OPENFDA_RESPONSE));

        Test.startTest();
        OpenFDADrugResult result = OpenFDAService.searchByBrandName('SomeDrug');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null even without openfda');
        System.assertEquals(null, result.brandName, 'Brand name should be null without openfda');
        System.assertEquals(null, result.manufacturerName, 'Manufacturer should be null without openfda');
        System.assert(result.indicationsAndUsage.contains('bacterial infections'), 'Indications should still be populated');
        System.assert(result.warnings.contains('allergic reactions'), 'Warnings should still be populated');
    }

    // ---------------------------------------------------------------------------
    // enrichDrugProduct tests
    // ---------------------------------------------------------------------------

    @IsTest
    static void testEnrichDrugProduct_Success() {
        Test.setMock(HttpCalloutMock.class, new OpenFDAMock(200, SUCCESS_RESPONSE));
        Drug_Product__c product = [SELECT Id FROM Drug_Product__c LIMIT 1];

        Test.startTest();
        Drug_Product__c enriched = OpenFDAService.enrichDrugProduct(product.Id);
        Test.stopTest();

        // Re-query to verify persisted values
        Drug_Product__c refreshed = [
            SELECT Manufacturer__c, Active_Ingredients__c, Indications__c,
                   Warnings__c, Last_FDA_Sync__c, Product_Name__c
            FROM Drug_Product__c
            WHERE Id = :product.Id
        ];

        System.assertEquals('AbbVie Inc.', refreshed.Manufacturer__c, 'Manufacturer should be populated');
        System.assertEquals('ADALIMUMAB', refreshed.Active_Ingredients__c, 'Active ingredients should be populated');
        System.assert(refreshed.Indications__c.contains('rheumatoid arthritis'), 'Indications should be populated');
        System.assertNotEquals(null, refreshed.Last_FDA_Sync__c, 'Last FDA Sync should be set');
        // Product_Name__c was already "Humira" — should NOT be overwritten
        System.assertEquals('Humira', refreshed.Product_Name__c, 'Product name should not be overwritten');
    }

    @IsTest
    static void testEnrichDrugProduct_BrandNotFound_FallsBackToGeneric() {
        // We need a multi-callout mock that returns 404 first, then 200
        Test.setMock(HttpCalloutMock.class, new BrandNotFoundGenericFoundMock());
        Drug_Product__c product = [SELECT Id FROM Drug_Product__c LIMIT 1];

        Test.startTest();
        Drug_Product__c enriched = OpenFDAService.enrichDrugProduct(product.Id);
        Test.stopTest();

        Drug_Product__c refreshed = [
            SELECT Manufacturer__c, Last_FDA_Sync__c
            FROM Drug_Product__c
            WHERE Id = :product.Id
        ];
        System.assertEquals('AbbVie Inc.', refreshed.Manufacturer__c, 'Should be enriched via generic name fallback');
        System.assertNotEquals(null, refreshed.Last_FDA_Sync__c, 'Last FDA Sync should be set');
    }

    @IsTest
    static void testEnrichDrugProduct_NoMatchAtAll_ThrowsException() {
        Test.setMock(HttpCalloutMock.class, new OpenFDAMock(404, NOT_FOUND_RESPONSE));
        Drug_Product__c product = [SELECT Id FROM Drug_Product__c LIMIT 1];

        Test.startTest();
        try {
            OpenFDAService.enrichDrugProduct(product.Id);
            System.assert(false, 'Should have thrown OpenFDAException');
        } catch (OpenFDAException e) {
            System.assert(e.getMessage().contains('No FDA label data found'), 'Error should indicate no match');
        }
        Test.stopTest();
    }

    @IsTest
    static void testFieldTruncation() {
        // Build a response with extremely long indications text
        String longText = 'A'.repeat(15000);
        String longResponse = '{'
            + '"meta": {"results": {"skip": 0, "limit": 1, "total": 1}},'
            + '"results": [{'
            + '  "indications_and_usage": ["' + longText + '"],'
            + '  "openfda": {'
            + '    "brand_name": ["TESTDRUG"],'
            + '    "manufacturer_name": ["TestCorp"]'
            + '  }'
            + '}]'
            + '}';

        Test.setMock(HttpCalloutMock.class, new OpenFDAMock(200, longResponse));
        Drug_Product__c product = [SELECT Id FROM Drug_Product__c LIMIT 1];

        Test.startTest();
        Drug_Product__c enriched = OpenFDAService.enrichDrugProduct(product.Id);
        Test.stopTest();

        Drug_Product__c refreshed = [
            SELECT Indications__c FROM Drug_Product__c WHERE Id = :product.Id
        ];
        System.assertEquals(10000, refreshed.Indications__c.length(),
            'Indications should be truncated to 10000 characters');
    }

    // ---------------------------------------------------------------------------
    // Multi-callout mock for brand-not-found fallback scenario
    // ---------------------------------------------------------------------------

    private class BrandNotFoundGenericFoundMock implements HttpCalloutMock {
        private Integer callCount = 0;

        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();

            if (callCount == 1) {
                // First call (brand name search) returns 404
                res.setStatusCode(404);
                res.setBody(NOT_FOUND_RESPONSE);
            } else {
                // Second call (generic name search) returns success
                res.setStatusCode(200);
                res.setBody(SUCCESS_RESPONSE);
            }
            return res;
        }
    }
}

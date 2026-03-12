/**
 * @description Test class for DrugProductFlowController and DrugProductFDAFlowAction.
 *              Covers the createDrugProduct invocable action (success, validation failure,
 *              optional fields) and the searchFDAForFlow invocable action (found, not found).
 *              Target: 95%+ coverage.
 */
@IsTest
private class DrugProductFlowControllerTest {

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

    private static final String SUCCESS_RESPONSE = '{'
        + '"meta": {"results": {"skip": 0, "limit": 1, "total": 1}},'
        + '"results": [{'
        + '  "indications_and_usage": ["HUMIRA is indicated for treatment of rheumatoid arthritis."],'
        + '  "warnings_and_cautions": ["SERIOUS INFECTIONS risk."],'
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
    // createDrugProduct tests
    // ---------------------------------------------------------------------------

    @IsTest
    static void testCreateDrugProduct_ValidInput_Succeeds() {
        DrugProductFlowController.FlowInput input = new DrugProductFlowController.FlowInput();
        input.productName    = 'Test Flow Drug';
        input.genericName    = 'testflowgeneric';
        input.regulatoryStatus = 'Phase 3'; // No conditional rules fire for Phase 3
        input.therapeuticArea  = 'Oncology';

        Test.startTest();
        List<DrugProductFlowController.FlowOutput> outputs =
            DrugProductFlowController.createDrugProduct(
                new List<DrugProductFlowController.FlowInput>{ input }
            );
        Test.stopTest();

        System.assertEquals(1, outputs.size(), 'Should return one output');
        System.assertEquals(true, outputs[0].success, 'Insert should succeed');
        System.assertNotEquals(null, outputs[0].recordId, 'Record Id should be populated');
        System.assertEquals('', outputs[0].errorMessage, 'Error message should be empty on success');
    }

    @IsTest
    static void testCreateDrugProduct_ValidationFailure_ReturnsError() {
        // 'Approved' without FDA_Approval_Date__c triggers a validation rule
        DrugProductFlowController.FlowInput input = new DrugProductFlowController.FlowInput();
        input.productName      = 'Test Failing Drug';
        input.regulatoryStatus = 'Approved';
        // fdaApprovalDate intentionally left null

        Test.startTest();
        List<DrugProductFlowController.FlowOutput> outputs =
            DrugProductFlowController.createDrugProduct(
                new List<DrugProductFlowController.FlowInput>{ input }
            );
        Test.stopTest();

        System.assertEquals(1, outputs.size(), 'Should return one output');
        System.assertEquals(false, outputs[0].success, 'Insert should fail due to validation rule');
        System.assertNotEquals(null, outputs[0].errorMessage, 'Error message should be populated');
        System.assert(
            outputs[0].errorMessage.contains('FDA Approval Date'),
            'Error should mention FDA Approval Date'
        );
    }

    @IsTest
    static void testCreateDrugProduct_OrphanDrugFlag_Persisted() {
        DrugProductFlowController.FlowInput input = new DrugProductFlowController.FlowInput();
        input.productName      = 'Orphan Test Drug';
        input.regulatoryStatus = 'Phase 1';
        input.orphanDrugStatus = true;

        Test.startTest();
        List<DrugProductFlowController.FlowOutput> outputs =
            DrugProductFlowController.createDrugProduct(
                new List<DrugProductFlowController.FlowInput>{ input }
            );
        Test.stopTest();

        System.assertEquals(true, outputs[0].success, 'Insert should succeed');
        Drug_Product__c created = [
            SELECT Orphan_Drug_Status__c FROM Drug_Product__c WHERE Id = :outputs[0].recordId
        ];
        System.assertEquals(true, created.Orphan_Drug_Status__c,
            'Orphan drug flag should be persisted');
    }

    @IsTest
    static void testCreateDrugProduct_AllOptionalFieldsPopulated_Succeeds() {
        DrugProductFlowController.FlowInput input = new DrugProductFlowController.FlowInput();
        input.productName       = 'Full Field Drug';
        input.genericName       = 'fullfieldgeneric';
        input.therapeuticArea   = 'Cardiovascular';
        input.drugClassification = 'Rx';
        input.regulatoryStatus  = 'Approved';
        input.fdaApprovalDate   = Date.today().addDays(-100);
        input.manufacturer      = 'Test Pharma';
        input.ndcCode           = '12345-678-90';
        input.activeIngredients = 'TestIngredient 100mg';
        input.orphanDrugStatus  = false;

        Test.startTest();
        List<DrugProductFlowController.FlowOutput> outputs =
            DrugProductFlowController.createDrugProduct(
                new List<DrugProductFlowController.FlowInput>{ input }
            );
        Test.stopTest();

        System.assertEquals(true, outputs[0].success, 'Full-field insert should succeed');
        Drug_Product__c created = [
            SELECT Product_Name__c, Manufacturer__c, NDC_Code__c, FDA_Approval_Date__c
            FROM Drug_Product__c WHERE Id = :outputs[0].recordId
        ];
        System.assertEquals('Full Field Drug', created.Product_Name__c);
        System.assertEquals('Test Pharma', created.Manufacturer__c);
        System.assertEquals('12345-678-90', created.NDC_Code__c);
    }

    // ---------------------------------------------------------------------------
    // searchFDAForFlow tests (DrugProductFDAFlowAction)
    // ---------------------------------------------------------------------------

    @IsTest
    static void testSearchFDAForFlow_Found_ReturnsData() {
        Test.setMock(HttpCalloutMock.class, new OpenFDAMock(200, SUCCESS_RESPONSE));
        DrugProductFDAFlowAction.FlowSearchInput input = new DrugProductFDAFlowAction.FlowSearchInput();
        input.productName = 'Humira';

        Test.startTest();
        List<DrugProductFDAFlowAction.FDAPreviewOutput> outputs =
            DrugProductFDAFlowAction.searchFDAForFlow(
                new List<DrugProductFDAFlowAction.FlowSearchInput>{ input }
            );
        Test.stopTest();

        System.assertEquals(1, outputs.size(), 'Should return one output');
        System.assertEquals(true, outputs[0].found, 'Should find the drug');
        System.assertEquals('AbbVie Inc.', outputs[0].manufacturer, 'Manufacturer should match');
        System.assertEquals('0074-3799', outputs[0].ndcCode, 'NDC code should match');
        System.assertEquals('ADALIMUMAB', outputs[0].activeIngredients,
            'Active ingredients should match');
        System.assertNotEquals(null, outputs[0].indicationsAndUsage,
            'Indications should be populated');
    }

    @IsTest
    static void testSearchFDAForFlow_NotFound_ReturnsFalse() {
        Test.setMock(HttpCalloutMock.class, new OpenFDAMock(404, NOT_FOUND_RESPONSE));
        DrugProductFDAFlowAction.FlowSearchInput input = new DrugProductFDAFlowAction.FlowSearchInput();
        input.productName = 'NonExistentDrug99999';

        Test.startTest();
        List<DrugProductFDAFlowAction.FDAPreviewOutput> outputs =
            DrugProductFDAFlowAction.searchFDAForFlow(
                new List<DrugProductFDAFlowAction.FlowSearchInput>{ input }
            );
        Test.stopTest();

        System.assertEquals(1, outputs.size(), 'Should return one output');
        System.assertEquals(false, outputs[0].found, 'found should be false for 404 response');
        System.assertEquals(null, outputs[0].manufacturer, 'Manufacturer should be null when not found');
    }

    @IsTest
    static void testSearchFDAForFlow_ApiError_ReturnsFalse() {
        // Rate-limit (429) causes OpenFDAException which is swallowed — should return found=false
        Test.setMock(HttpCalloutMock.class, new OpenFDAMock(429, ''));
        DrugProductFDAFlowAction.FlowSearchInput input = new DrugProductFDAFlowAction.FlowSearchInput();
        input.productName = 'Humira';

        Test.startTest();
        List<DrugProductFDAFlowAction.FDAPreviewOutput> outputs =
            DrugProductFDAFlowAction.searchFDAForFlow(
                new List<DrugProductFDAFlowAction.FlowSearchInput>{ input }
            );
        Test.stopTest();

        System.assertEquals(1, outputs.size(), 'Should return one output');
        System.assertEquals(false, outputs[0].found,
            'found should be false when API throws OpenFDAException');
    }
}

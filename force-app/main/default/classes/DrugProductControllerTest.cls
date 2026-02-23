/**
 * @description Test class for DrugProductController. Covers search with and without
 *              filters, manufacturer/therapeutic area search, empty results, inline
 *              edit save, and DML error handling. Target: 95%+ coverage.
 */
@IsTest
private class DrugProductControllerTest {

    @TestSetup
    static void setupTestData() {
        List<Drug_Product__c> products = new List<Drug_Product__c>();
        products.add(new Drug_Product__c(
            Product_Name__c = 'TestDrug Alpha',
            Generic_Name__c = 'alphageneric',
            NDC_Code__c = '1234-5678-01',
            Manufacturer__c = 'Pharma Corp',
            Therapeutic_Area__c = 'Oncology',
            Regulatory_Status__c = 'Approved',
            Drug_Classification__c = 'Rx',
            Dosage_Form__c = 'Tablet',
            Strength__c = '500mg',
            FDA_Approval_Date__c = Date.today().addDays(-365)
        ));
        products.add(new Drug_Product__c(
            Product_Name__c = 'TestDrug Beta',
            Generic_Name__c = 'betageneric',
            NDC_Code__c = '9876-5432-01',
            Manufacturer__c = 'BioHealth Inc',
            Therapeutic_Area__c = 'Cardiovascular',
            Regulatory_Status__c = 'Launched',
            Drug_Classification__c = 'Rx',
            Dosage_Form__c = 'Injectable',
            Strength__c = '10mg/mL',
            FDA_Approval_Date__c = Date.today().addDays(-730),
            Launch_Date__c = Date.today().addDays(-365)
        ));
        products.add(new Drug_Product__c(
            Product_Name__c = 'TestDrug Gamma',
            Generic_Name__c = 'gammageneric',
            NDC_Code__c = '5555-1111-01',
            Manufacturer__c = 'Pharma Corp',
            Therapeutic_Area__c = 'Oncology',
            Regulatory_Status__c = 'Phase 3',
            Drug_Classification__c = 'Rx',
            Dosage_Form__c = 'Infusion'
        ));
        insert products;
    }

    @IsTest
    static void testGetDrugProducts_NoSearch() {
        Test.startTest();
        List<Drug_Product__c> results = DrugProductController.getDrugProducts(null);
        Test.stopTest();

        System.assertEquals(3, results.size(), 'Should return all 3 test records');
    }

    @IsTest
    static void testGetDrugProducts_BlankSearch() {
        Test.startTest();
        List<Drug_Product__c> results = DrugProductController.getDrugProducts('  ');
        Test.stopTest();

        System.assertEquals(3, results.size(), 'Blank search should return all records');
    }

    @IsTest
    static void testGetDrugProducts_SearchByProductName() {
        Test.startTest();
        List<Drug_Product__c> results = DrugProductController.getDrugProducts('Alpha');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find only TestDrug Alpha');
        System.assertEquals('TestDrug Alpha', results[0].Product_Name__c);
    }

    @IsTest
    static void testGetDrugProducts_SearchByGenericName() {
        Test.startTest();
        List<Drug_Product__c> results = DrugProductController.getDrugProducts('betageneric');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find only TestDrug Beta by generic name');
        System.assertEquals('TestDrug Beta', results[0].Product_Name__c);
    }

    @IsTest
    static void testGetDrugProducts_SearchByManufacturer() {
        Test.startTest();
        List<Drug_Product__c> results = DrugProductController.getDrugProducts('BioHealth');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find only the BioHealth product');
        System.assertEquals('TestDrug Beta', results[0].Product_Name__c);
    }

    @IsTest
    static void testGetDrugProducts_SearchByTherapeuticArea() {
        Test.startTest();
        List<Drug_Product__c> results = DrugProductController.getDrugProducts('Oncology');
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should find both Oncology products');
    }

    @IsTest
    static void testGetDrugProducts_SearchByNDCCode() {
        Test.startTest();
        List<Drug_Product__c> results = DrugProductController.getDrugProducts('1234-5678');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find by NDC code');
        System.assertEquals('TestDrug Alpha', results[0].Product_Name__c);
    }

    @IsTest
    static void testGetDrugProducts_NoResults() {
        Test.startTest();
        List<Drug_Product__c> results = DrugProductController.getDrugProducts('nonexistent12345');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty list for no matches');
    }

    @IsTest
    static void testSaveDrugProducts_Success() {
        Drug_Product__c product = [
            SELECT Id, Manufacturer__c FROM Drug_Product__c
            WHERE Product_Name__c = 'TestDrug Alpha' LIMIT 1
        ];
        product.Manufacturer__c = 'Updated Pharma Corp';

        Test.startTest();
        List<Drug_Product__c> saved = DrugProductController.saveDrugProducts(
            new List<Drug_Product__c>{ product }
        );
        Test.stopTest();

        Drug_Product__c refreshed = [
            SELECT Manufacturer__c FROM Drug_Product__c WHERE Id = :product.Id
        ];
        System.assertEquals('Updated Pharma Corp', refreshed.Manufacturer__c,
            'Manufacturer should be updated');
    }

    @IsTest
    static void testSaveDrugProducts_DmlError() {
        Drug_Product__c product = [
            SELECT Id, Product_Name__c FROM Drug_Product__c
            WHERE Product_Name__c = 'TestDrug Alpha' LIMIT 1
        ];
        // Product_Name__c is required — setting to null should cause DML error
        product.Product_Name__c = null;

        Test.startTest();
        try {
            DrugProductController.saveDrugProducts(new List<Drug_Product__c>{ product });
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Error message should not be null');
        }
        Test.stopTest();
    }
}

/**
 * @description Apex controller for the drugProductDataTable Lightning Web Component.
 *              Provides methods to query, search, update, and validate Drug_Product__c records.
 */
public with sharing class DrugProductController {

    /**
     * @description Retrieves Drug_Product__c records, optionally filtered by a search term.
     *              The search term is matched against Product_Name__c, Generic_Name__c,
     *              NDC_Code__c, Manufacturer__c, and Therapeutic_Area__c using LIKE.
     * @param searchTerm Optional text to filter records. If blank, returns all records.
     * @return List of Drug_Product__c records matching the search criteria.
     */
    @AuraEnabled(cacheable=true)
    public static List<Drug_Product__c> getDrugProducts(String searchTerm) {
        if (String.isNotBlank(searchTerm)) {
            String safeTerm = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
            return [
                SELECT Id, Name, Product_Name__c, Generic_Name__c, NDC_Code__c,
                       Strength__c, Dosage_Form__c, Drug_Classification__c,
                       Therapeutic_Area__c, Regulatory_Status__c, Manufacturer__c,
                       FDA_Approval_Date__c, Orphan_Drug_Status__c
                FROM Drug_Product__c
                WHERE Product_Name__c LIKE :safeTerm
                   OR Generic_Name__c LIKE :safeTerm
                   OR NDC_Code__c LIKE :safeTerm
                   OR Manufacturer__c LIKE :safeTerm
                   OR Therapeutic_Area__c LIKE :safeTerm
                ORDER BY Product_Name__c ASC
                LIMIT 200
            ];
        }

        return [
            SELECT Id, Name, Product_Name__c, Generic_Name__c, NDC_Code__c,
                   Strength__c, Dosage_Form__c, Drug_Classification__c,
                   Therapeutic_Area__c, Regulatory_Status__c, Manufacturer__c,
                   FDA_Approval_Date__c, Orphan_Drug_Status__c
            FROM Drug_Product__c
            ORDER BY Product_Name__c ASC
            LIMIT 200
        ];
    }

    /**
     * @description Retrieves Drug_Product__c records with bulk validation results attached.
     *              Runs ValidationRuleEngine in bulk so validation is O(1) SOQL regardless
     *              of record count. Used by the drugProductDataTable health badge column.
     *              Not cacheable because validation results change when Rule_Override__c
     *              records or field values change outside this transaction.
     * @param searchTerm Optional text filter (same LIKE search as getDrugProducts).
     * @return List of DrugProductValidationWrapper with record + validation status.
     */
    @AuraEnabled(cacheable=true)
    public static List<DrugProductValidationWrapper> getDrugProductsWithValidation(String searchTerm) {
        List<Drug_Product__c> records;
        if (String.isNotBlank(searchTerm)) {
            String safeTerm = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
            records = [
                SELECT Id, Name, Product_Name__c, Generic_Name__c, NDC_Code__c,
                       Strength__c, Dosage_Form__c, Drug_Classification__c,
                       Therapeutic_Area__c, Regulatory_Status__c, Manufacturer__c,
                       FDA_Approval_Date__c, Launch_Date__c, Patent_Expiration__c,
                       Patent_Expiry_Alert__c, Orphan_Drug_Status__c
                FROM Drug_Product__c
                WHERE Product_Name__c LIKE :safeTerm
                   OR Generic_Name__c LIKE :safeTerm
                   OR NDC_Code__c LIKE :safeTerm
                   OR Manufacturer__c LIKE :safeTerm
                   OR Therapeutic_Area__c LIKE :safeTerm
                ORDER BY Product_Name__c ASC
                LIMIT 200
            ];
        } else {
            records = [
                SELECT Id, Name, Product_Name__c, Generic_Name__c, NDC_Code__c,
                       Strength__c, Dosage_Form__c, Drug_Classification__c,
                       Therapeutic_Area__c, Regulatory_Status__c, Manufacturer__c,
                       FDA_Approval_Date__c, Launch_Date__c, Patent_Expiration__c,
                       Patent_Expiry_Alert__c, Orphan_Drug_Status__c
                FROM Drug_Product__c
                ORDER BY Product_Name__c ASC
                LIMIT 200
            ];
        }

        Map<Integer, List<ValidationResult>> validationMap =
            ValidationRuleEngine.evaluate('Drug_Product__c', records);

        List<DrugProductValidationWrapper> wrappers = new List<DrugProductValidationWrapper>();
        for (Integer i = 0; i < records.size(); i++) {
            DrugProductValidationWrapper wrapper = new DrugProductValidationWrapper();
            wrapper.record           = records[i];
            wrapper.validationErrors = validationMap.containsKey(i)
                ? validationMap.get(i)
                : new List<ValidationResult>();

            Boolean hasBlocking = false;
            Boolean hasWarning  = false;
            for (ValidationResult vr : wrapper.validationErrors) {
                if (vr.isBlockingError) {
                    hasBlocking = true;
                } else {
                    hasWarning = true;
                }
            }
            wrapper.validationStatus = hasBlocking ? 'invalid' : (hasWarning ? 'warning' : 'valid');
            wrappers.add(wrapper);
        }
        return wrappers;
    }

    /**
     * @description Saves a list of Drug_Product__c records that were inline-edited.
     * @param records List of Drug_Product__c records with updated field values.
     * @return List of updated Drug_Product__c records after DML.
     * @throws AuraHandledException if DML fails.
     */
    @AuraEnabled
    public static List<Drug_Product__c> saveDrugProducts(List<Drug_Product__c> records) {
        try {
            update records;
            return records;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}

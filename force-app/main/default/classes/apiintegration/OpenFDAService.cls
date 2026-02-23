/**
 * @description Service class for integrating with the OpenFDA Drug Labeling API.
 *              Provides methods to search for drug label data and enrich
 *              Drug_Product__c records with FDA information.
 *
 *              API docs: https://open.fda.gov/apis/drug/label/
 *              No authentication required. Rate limit: 240 requests/minute.
 */
public with sharing class OpenFDAService {

    @TestVisible
    private static final String BASE_URL = 'https://api.fda.gov/drug/label.json';
    private static final Integer TIMEOUT_MS = 10000;
    private static final String SEARCH_BY_BRAND = 'openfda.brand_name:';
    private static final String SEARCH_BY_GENERIC = 'openfda.generic_name:';

    /**
     * @description Searches OpenFDA by brand name and returns parsed label data.
     * @param brandName The brand/trade name to search for (e.g., "Humira").
     * @return OpenFDADrugResult wrapper containing parsed fields, or null if not found.
     * @throws OpenFDAException on HTTP errors, timeouts, or malformed responses.
     */
    public static OpenFDADrugResult searchByBrandName(String brandName) {
        HttpResponse response = executeCallout(SEARCH_BY_BRAND, brandName);
        if (response == null) {
            return null;
        }
        return parseResponse(response.getBody());
    }

    /**
     * @description Searches OpenFDA by generic name and returns parsed label data.
     * @param genericName The generic/chemical name to search for (e.g., "adalimumab").
     * @return OpenFDADrugResult wrapper containing parsed fields, or null if not found.
     * @throws OpenFDAException on HTTP errors, timeouts, or malformed responses.
     */
    public static OpenFDADrugResult searchByGenericName(String genericName) {
        HttpResponse response = executeCallout(SEARCH_BY_GENERIC, genericName);
        if (response == null) {
            return null;
        }
        return parseResponse(response.getBody());
    }

    /**
     * @description Enriches an existing Drug_Product__c record with data from OpenFDA.
     *              Searches by Product_Name__c first, falls back to Generic_Name__c.
     *              Updates the record in-place and performs DML update.
     * @param recordId The Id of the Drug_Product__c record to enrich.
     * @return The updated Drug_Product__c record.
     * @throws OpenFDAException if no match is found or API errors occur.
     */
    public static Drug_Product__c enrichDrugProduct(Id recordId) {
        Drug_Product__c product = [
            SELECT Id, Product_Name__c, Generic_Name__c, NDC_Code__c,
                   Manufacturer__c, Active_Ingredients__c, Indications__c,
                   Warnings__c, Last_FDA_Sync__c
            FROM Drug_Product__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        OpenFDADrugResult fdaData;

        if (String.isNotBlank(product.Product_Name__c)) {
            fdaData = searchByBrandName(product.Product_Name__c);
        }

        if (fdaData == null && String.isNotBlank(product.Generic_Name__c)) {
            fdaData = searchByGenericName(product.Generic_Name__c);
        }

        if (fdaData == null) {
            throw new OpenFDAException(
                'No FDA label data found for this drug product.'
            );
        }

        mapToProduct(product, fdaData);
        update product;
        return product;
    }

    /**
     * @description Executes an HTTP GET callout to the OpenFDA API.
     * @param searchField The API field to search (brand_name or generic_name).
     * @param searchValue The value to search for.
     * @return The HttpResponse, or null if no results found (404).
     * @throws OpenFDAException on rate limiting, server errors, or timeouts.
     */
    @TestVisible
    private static HttpResponse executeCallout(String searchField, String searchValue) {
        String encodedValue = EncodingUtil.urlEncode(searchValue, 'UTF-8');
        String endpoint = BASE_URL + '?search=' + searchField + '"' + encodedValue + '"&limit=1';

        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setTimeout(TIMEOUT_MS);

        HttpResponse response;
        try {
            response = new Http().send(request);
        } catch (System.CalloutException e) {
            throw new OpenFDAException(
                'FDA API request timed out or failed: ' + e.getMessage()
            );
        }

        Integer statusCode = response.getStatusCode();

        if (statusCode == 404) {
            return null;
        }

        if (statusCode == 429) {
            throw new OpenFDAException(
                'FDA API rate limit exceeded. Please try again later.'
            );
        }

        if (statusCode != 200) {
            throw new OpenFDAException(
                'FDA API returned unexpected status: HTTP ' + statusCode
            );
        }

        return response;
    }

    /**
     * @description Parses the JSON response body into an OpenFDADrugResult wrapper.
     * @param responseBody The raw JSON string from the API.
     * @return Parsed OpenFDADrugResult with mapped fields.
     * @throws OpenFDAException if the JSON cannot be parsed or has unexpected structure.
     */
    @TestVisible
    private static OpenFDADrugResult parseResponse(String responseBody) {
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            List<Object> results = (List<Object>) root.get('results');

            if (results == null || results.isEmpty()) {
                return null;
            }

            Map<String, Object> firstResult = (Map<String, Object>) results[0];
            Map<String, Object> openfda = (Map<String, Object>) firstResult.get('openfda');

            OpenFDADrugResult drug = new OpenFDADrugResult();

            // Fields from the openfda sub-object (may be absent)
            if (openfda != null) {
                drug.brandName = getFirstArrayValue(openfda, 'brand_name');
                drug.genericName = getFirstArrayValue(openfda, 'generic_name');
                drug.manufacturerName = getFirstArrayValue(openfda, 'manufacturer_name');
                drug.ndcCode = getFirstArrayValue(openfda, 'product_ndc');
                drug.productType = getFirstArrayValue(openfda, 'product_type');
                drug.route = getFirstArrayValue(openfda, 'route');

                // Active ingredients: prefer substance_name array, join with "; "
                List<Object> substances = (List<Object>) openfda.get('substance_name');
                if (substances != null && !substances.isEmpty()) {
                    List<String> substanceStrings = new List<String>();
                    for (Object s : substances) {
                        substanceStrings.add(String.valueOf(s));
                    }
                    drug.activeIngredients = String.join(substanceStrings, '; ');
                }
            }

            // Top-level label fields
            drug.indicationsAndUsage = getFirstArrayValue(firstResult, 'indications_and_usage');
            drug.dosageFormsAndStrengths = getFirstArrayValue(firstResult, 'dosage_forms_and_strengths');

            // Warnings: prefer warnings_and_cautions (Rx), fall back to warnings (OTC)
            drug.warnings = getFirstArrayValue(firstResult, 'warnings_and_cautions');
            if (String.isBlank(drug.warnings)) {
                drug.warnings = getFirstArrayValue(firstResult, 'warnings');
            }

            // Fall back to openfda active_ingredient if substance_name was empty
            if (String.isBlank(drug.activeIngredients)) {
                drug.activeIngredients = getFirstArrayValue(firstResult, 'active_ingredient');
            }

            return drug;
        } catch (Exception e) {
            throw new OpenFDAException(
                'Failed to parse FDA API response: ' + e.getMessage()
            );
        }
    }

    /**
     * @description Maps an OpenFDADrugResult onto a Drug_Product__c record.
     *              Identity fields (Product_Name, Generic_Name, NDC_Code) are only
     *              populated if currently blank. Data fields are always updated.
     * @param product The Drug_Product__c record to update.
     * @param fdaData The parsed API result.
     */
    @TestVisible
    private static void mapToProduct(Drug_Product__c product, OpenFDADrugResult fdaData) {
        // Identity fields: only fill if blank (user data takes precedence)
        if (String.isBlank(product.Product_Name__c) && String.isNotBlank(fdaData.brandName)) {
            product.Product_Name__c = truncate(fdaData.brandName, 255);
        }
        if (String.isBlank(product.Generic_Name__c) && String.isNotBlank(fdaData.genericName)) {
            product.Generic_Name__c = truncate(fdaData.genericName, 255);
        }
        if (String.isBlank(product.NDC_Code__c) && String.isNotBlank(fdaData.ndcCode)) {
            product.NDC_Code__c = truncate(fdaData.ndcCode, 20);
        }

        // Data fields: always update from FDA (latest authoritative source)
        if (String.isNotBlank(fdaData.manufacturerName)) {
            product.Manufacturer__c = truncate(fdaData.manufacturerName, 255);
        }
        if (String.isNotBlank(fdaData.activeIngredients)) {
            product.Active_Ingredients__c = truncate(fdaData.activeIngredients, 500);
        }
        if (String.isNotBlank(fdaData.indicationsAndUsage)) {
            product.Indications__c = truncate(fdaData.indicationsAndUsage, 10000);
        }
        if (String.isNotBlank(fdaData.warnings)) {
            product.Warnings__c = truncate(fdaData.warnings, 10000);
        }

        product.Last_FDA_Sync__c = DateTime.now();
    }

    /**
     * @description Safely extracts the first string value from a JSON array field.
     * @param container The parent map containing the array field.
     * @param fieldName The key of the array field.
     * @return The first element as a String, or null if absent/empty.
     */
    private static String getFirstArrayValue(Map<String, Object> container, String fieldName) {
        List<Object> arr = (List<Object>) container.get(fieldName);
        if (arr != null && !arr.isEmpty()) {
            return String.valueOf(arr[0]);
        }
        return null;
    }

    /**
     * @description Truncates a string to the specified maximum length.
     * @param value The string to truncate.
     * @param maxLength Maximum allowed length.
     * @return The truncated string.
     */
    private static String truncate(String value, Integer maxLength) {
        if (value != null && value.length() > maxLength) {
            return value.substring(0, maxLength);
        }
        return value;
    }
}

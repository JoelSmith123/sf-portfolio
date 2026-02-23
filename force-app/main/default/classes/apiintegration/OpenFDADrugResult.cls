/**
 * @description Data wrapper for parsed OpenFDA drug label API results.
 *              Holds the fields extracted from the JSON response that map
 *              to Drug_Product__c fields.
 */
public class OpenFDADrugResult {
    /** @description Brand or trade name (e.g., "HUMIRA") */
    public String brandName;

    /** @description Generic or chemical name (e.g., "ADALIMUMAB") */
    public String genericName;

    /** @description Pharmaceutical manufacturer name */
    public String manufacturerName;

    /** @description National Drug Code identifier */
    public String ndcCode;

    /** @description Active pharmaceutical ingredients, semicolon-separated */
    public String activeIngredients;

    /** @description FDA-approved indications and usage text */
    public String indicationsAndUsage;

    /** @description Safety warnings and contraindications text */
    public String warnings;

    /** @description Dosage forms and strengths description */
    public String dosageFormsAndStrengths;

    /** @description Route of administration (e.g., "ORAL", "SUBCUTANEOUS") */
    public String route;

    /** @description Product type (e.g., "HUMAN PRESCRIPTION DRUG") */
    public String productType;
}

/**
 * @description Invocable Apex action for use in the New_Drug_Product_Wizard Screen Flow.
 *              Creates a Drug_Product__c record from Flow variables, handling trigger
 *              validation errors gracefully so the Flow's fault path can display them.
 */
public with sharing class DrugProductFlowController {

    /**
     * @description Input variables supplied by the Flow to create a Drug_Product__c record.
     */
    public class FlowInput {
        @InvocableVariable(required=false label='Product Name')
        public String productName;

        @InvocableVariable(required=false label='Generic Name')
        public String genericName;

        @InvocableVariable(required=false label='Therapeutic Area')
        public String therapeuticArea;

        @InvocableVariable(required=false label='Drug Classification')
        public String drugClassification;

        @InvocableVariable(required=false label='Regulatory Status')
        public String regulatoryStatus;

        @InvocableVariable(required=false label='FDA Approval Date')
        public Date fdaApprovalDate;

        @InvocableVariable(required=false label='Launch Date')
        public Date launchDate;

        @InvocableVariable(required=false label='Orphan Drug Status')
        public Boolean orphanDrugStatus;

        @InvocableVariable(required=false label='Manufacturer')
        public String manufacturer;

        @InvocableVariable(required=false label='NDC Code')
        public String ndcCode;

        @InvocableVariable(required=false label='Active Ingredients')
        public String activeIngredients;
    }

    /**
     * @description Output variables returned to the Flow with the result of the insert.
     */
    public class FlowOutput {
        @InvocableVariable(label='Record Id')
        public String recordId;

        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    /**
     * @description Creates a Drug_Product__c record from the provided Flow variables.
     *              Returns a success/failure output so the Flow can route to a review
     *              screen or a fault-path error screen accordingly.
     * @param inputs List of FlowInput records (Flows always pass a single-element list).
     * @return List of FlowOutput records with success status and recordId or error message.
     */
    @InvocableMethod(
        label='Create Drug Product'
        description='Creates a Drug_Product__c record from Flow variables. Returns success status with recordId, or error message for the fault path screen.'
    )
    public static List<FlowOutput> createDrugProduct(List<FlowInput> inputs) {
        List<FlowOutput> outputs = new List<FlowOutput>();
        for (FlowInput input : inputs) {
            FlowOutput output = new FlowOutput();
            try {
                Drug_Product__c product = new Drug_Product__c(
                    Product_Name__c      = input.productName,
                    Generic_Name__c      = input.genericName,
                    Therapeutic_Area__c  = input.therapeuticArea,
                    Drug_Classification__c = input.drugClassification,
                    Regulatory_Status__c = input.regulatoryStatus,
                    FDA_Approval_Date__c = input.fdaApprovalDate,
                    Launch_Date__c       = input.launchDate,
                    Orphan_Drug_Status__c = (input.orphanDrugStatus == true),
                    Manufacturer__c      = input.manufacturer,
                    NDC_Code__c          = input.ndcCode,
                    Active_Ingredients__c = input.activeIngredients
                );
                insert product;
                output.recordId     = product.Id;
                output.success      = true;
                output.errorMessage = '';
            } catch (DmlException e) {
                output.success      = false;
                output.errorMessage = e.getDmlMessage(0);
            } catch (Exception e) {
                output.success      = false;
                output.errorMessage = e.getMessage();
            }
            outputs.add(output);
        }
        return outputs;
    }
}

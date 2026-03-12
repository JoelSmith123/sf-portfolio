/**
 * @description Invocable Apex action for read-only FDA data lookup in Flows.
 *              Used by the New_Drug_Product_Wizard Screen Flow to preview FDA label data
 *              before the user decides whether to accept it. No DML is performed.
 */
public with sharing class DrugProductFDAFlowAction {

    /**
     * @description Input for the searchFDAForFlow invocable method.
     */
    public class FlowSearchInput {
        @InvocableVariable(required=true label='Product Name')
        public String productName;
    }

    /**
     * @description Output fields returned from the FDA search for display in the flow screen.
     */
    public class FDAPreviewOutput {
        @InvocableVariable(label='FDA Data Found')
        public Boolean found;

        @InvocableVariable(label='Manufacturer')
        public String manufacturer;

        @InvocableVariable(label='NDC Code')
        public String ndcCode;

        @InvocableVariable(label='Active Ingredients')
        public String activeIngredients;

        @InvocableVariable(label='Indications and Usage')
        public String indicationsAndUsage;

        @InvocableVariable(label='Warnings')
        public String warnings;
    }

    /**
     * @description Searches OpenFDA by brand name and returns key label fields for
     *              display in the flow. Returns found = false when no match exists.
     *              OpenFDAException is swallowed so the flow continues rather than faulting —
     *              the flow can then skip the FDA preview screen.
     * @param inputs List of FlowSearchInput (Flows pass a single-element list).
     * @return List of FDAPreviewOutput with found flag and field values.
     */
    @InvocableMethod(
        label='Search FDA for Drug Product'
        description='Searches OpenFDA by brand name and returns drug label data without saving. Used by the New Drug Product wizard flow to preview FDA enrichment.'
    )
    public static List<FDAPreviewOutput> searchFDAForFlow(List<FlowSearchInput> inputs) {
        List<FDAPreviewOutput> outputs = new List<FDAPreviewOutput>();
        for (FlowSearchInput input : inputs) {
            FDAPreviewOutput output = new FDAPreviewOutput();
            try {
                OpenFDADrugResult fdaData = OpenFDAService.searchByBrandName(input.productName);
                if (fdaData != null) {
                    output.found               = true;
                    output.manufacturer        = fdaData.manufacturerName;
                    output.ndcCode             = fdaData.ndcCode;
                    output.activeIngredients   = fdaData.activeIngredients;
                    output.indicationsAndUsage = fdaData.indicationsAndUsage;
                    output.warnings            = fdaData.warnings;
                } else {
                    output.found = false;
                }
            } catch (OpenFDAException e) {
                // Swallow the exception — flow shows a "not found" path instead of faulting
                output.found = false;
            }
            outputs.add(output);
        }
        return outputs;
    }
}

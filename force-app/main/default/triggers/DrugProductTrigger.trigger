/**
 * @description Trigger on Drug_Product__c that invokes the ValidationRuleEngine
 *              for data-driven validation on before insert and before update.
 *              All validation logic lives in the engine — this trigger is
 *              intentionally a thin dispatch layer.
 */
trigger DrugProductTrigger on Drug_Product__c (before insert, before update) {
    ValidationRuleEngine.validateAndAddErrors('Drug_Product__c', Trigger.new);
}

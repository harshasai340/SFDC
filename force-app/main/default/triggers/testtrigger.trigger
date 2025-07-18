trigger testtrigger on TriggerDemo__c (before insert, after insert) {
    for(TriggerDemo__c temp:Trigger.new){
        if(temp.Name=='Harsha')
        {
            if(Trigger.isBefore) 
            	system.debug('the test is success and in before');
            
            if(Trigger.isAfter) 
            	system.debug('the test is success and in After');
        }
    }
}
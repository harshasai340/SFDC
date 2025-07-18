trigger Phone on Contact (before update) {
Map<id,Contact> o =new map<id,Contact>();
    o=trigger.oldMap;
        for(Contact n: Trigger.new )
    {
        Contact old=new Contact();
        old=o.get(n.id);
        if(n.Phone!=old.Phone)
        {
            n.addError('number cannot be changed');
        }
        system.debug('trigger.oldmap');
    }
}
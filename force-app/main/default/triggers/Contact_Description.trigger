trigger Contact_Description on Contact (before insert) {
    for(Contact contact:Trigger.new){
        contact.description='Created by Harsha';
    }
    
    
}
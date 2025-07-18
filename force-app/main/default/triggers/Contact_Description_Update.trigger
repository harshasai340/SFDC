trigger Contact_Description_Update on Contact (before delete)
{
 for(contact C: Trigger.old)
 {
     if(C.accountId == null) 
     {
         C.addError('Hey' +userInfo.getUserName()+ 'You Cannot Delete the Contact');
     }   
 }
}
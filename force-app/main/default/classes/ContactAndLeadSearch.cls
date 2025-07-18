public class ContactAndLeadSearch {
    public static List<List<Sobject>> searchContactsAndLeads(String search){
       List<List<Sobject>> searchList = [Find :search in all fields
                                        Returning 
                                        Contact(FirstName,LastName),
                                        Lead(FirstName,LastName)];
        Contact[] searchContact = (Contact[]) searchList[0];
         Lead[] searchLeads = (Lead[]) searchList[1];
        System.debug('Contacts');
        for (Contact C : searchContact){
            System.debug(C.FirstName + ','+ C.LastName);
        }
         System.debug('Leads');
         for (Lead L : searchLeads){
            System.debug(L.FirstName +','+ L.LastName);
        }
        Return searchList;
    }
}
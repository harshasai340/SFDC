public class contactUtil {

   /* public static list<Contact> getconList(){
        
 	Contact[] conList = [SELECT ID,birthdate,title,FirstName,LastName from contact ];   
        system.debug(conList);
        return conlist;
	} */
    public static void insertcontact(){
        
       Contact Con = new Contact();
         Con.FirstName='Shouvik';
             Con.LastName='Datta';
             Con.AccountId='0012v00002pLmTc';
             Con.Email='souvik@boom.com';
             Con.Phone='9522223333';
        insert Con;
        
        system.debug(con.Title);
        con.Title='CO';
        update con;
        system.debug(con.title);
            }
    
    
    
    
    public static void getAccRecord(){
        Contact con=[select
                    ID,AccountID,Account.Name,Account.type
                    from
                    Contact
                     limit 1];
                     System.debug(' con '+con);
                     System.debug(' con '+con.AccountId);
                      System.debug(' con '+con.FirstName);
                       System.debug(' con '+con.LastName);
                        System.debug(' con '+con.Account.type);          
                    
    }
}
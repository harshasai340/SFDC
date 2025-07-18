@IsTest(seealldata=false)
public class test1 {
    static testMethod void  first(){
       integer result = AddApex.Add(5,0);
        system.assert(result == 5 );
    }
   /* List<Account> accounts=[SELECT Id FROM ACCOUNT LIMIT 10];
    system.debug(accounts);*/
}
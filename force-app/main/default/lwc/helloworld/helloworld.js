import { LightningElement,api} from "lwc";
import ACCOUNT_OBJECT from "@salesforce/schema/Account";
import NAME_FIELD from "@salesforce/schema/Account.Name";
import WEBSITE_FIELD from "@salesforce/schema/Account.Website";
export default class Helloworld extends LightningElement {
accountObjct = ACCOUNT_OBJECT;
myFields = [NAME_FIELD,WEBSITE_FIELD];
@api recordId;
handleAccountCreated(){
}
}
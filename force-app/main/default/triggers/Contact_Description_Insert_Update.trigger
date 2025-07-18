trigger Contact_Description_Insert_Update on Contact (before insert,before Update) 
{
    for(Contact  c:Trigger.New)
    {
        if(trigger.isInsert)
        {
            c.Description= ' Contact created by insert Trigger ';
        }
        else if(trigger.isUpdate)
        {
          c.Description= ' Contact Updated by Update Trigger ';
   
        }
    }
  }
import { LightningElement } from 'lwc';

export default class EventSourceDemo extends LightningElement {
handleChange(event){
    event.preventDefault();
    const name = event.target.value;
    const SelectEvent = new CustomEvent('eventname',{ detail:name});
    this.dispatchEvent(SelectEvent);
   }
}
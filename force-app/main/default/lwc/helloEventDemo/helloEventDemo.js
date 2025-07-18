import { LightningElement, track } from 'lwc';

export default class HelloEventDemo extends LightningElement {
    @track valueInp;
    handleSelect(event){
        const textVale = event.detail;
        this.valueInp = textVale;
    }
}
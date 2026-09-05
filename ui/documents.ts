import {button,column,icon,input,node,pane,row,text,type Data,type Command} from "./view";
import type {UiNode} from "@lunatic/ui";
import {files} from "./files";

export function documentAction(doc:Data,act:string,payload:Data):Command {
  return {kind:"document",document:doc.id,generation:doc.generation,act,payload};
}

export function documents(view:Data):UiNode[] {
  return Object.values(view.documents ?? {}).map((doc:Data)=>{
    const id=`doc/${doc.id}/${doc.generation}`;
    const state=doc.state;
    const active=state.status === undefined || state.status>=2;
    const children:UiNode[]=[row(`${id}/title`,[text(`${id}/name`,doc.title),button(`${id}/close`,"✕",{kind:"close",document:doc.id,generation:doc.generation})])];
    if(state.document==="build") {
      children.push(...state.recipes.map((recipe:Data,index:number)=>row(`${id}/recipe/${index}`,[
        icon(`${id}/recipe/${index}/icon`,recipe.sprite),
        button(`${id}/recipe/${index}/arm`,`${view.state.armed===index?"● ":""}${recipe.label} · have ${recipe.have} · costs ${recipe.cost} · ${recipe.secs}s`,{kind:"arm",document:doc.id,generation:doc.generation,index},recipe.have<recipe.cost),
      ])));
    } else if(state.document==="script") {
      children.push(...dataRows(`${id}/data`,state.data));
      children.push(...state.actions.map((action:Data,index:number)=>action.input?
        row(`${id}/action/${index}`,[text(`${id}/action/${index}/label`,action.id),input(`${id}/action/${index}/value`,"",value=>documentAction(doc,action.id,{value}))]):
        button(`${id}/action/${index}`,action.id,documentAction(doc,action.id,{}),!active)));
    } else {
      if(state.notice)children.push(text(`${id}/notice`,state.notice));
      if(state.gauge!==null && state.gauge!==undefined)children.push(node("progress",`${id}/gauge`,{value:String(state.gauge)}));
      children.push(...(state.readouts??[]).map((reading:Data,index:number)=>row(`${id}/reading/${index}`,[text(`${id}/reading/${index}/label`,`${reading.section?`${reading.section} · `:""}${reading.label}`),text(`${id}/reading/${index}/value`,reading.value)])));
      children.push(...(state.toggles??[]).map((toggle:Data,index:number)=>button(`${id}/toggle/${index}`,`${toggle.label}: ${toggle.on?toggle.on_text:toggle.off_text}`,documentAction(doc,"toggle",{field:toggle.field,...(toggle.option==null?{}:{option:toggle.option})}),!active)));
      children.push(...(state.labels??[]).map((label:Data,index:number)=>{
        const key=`${id}/label/${index}`;
        const labelNode=text(`${key}/title`,label.label);
        if(label.row==="press")return row(key,[labelNode,button(`${key}/button`,label.text,documentAction(doc,"toggle",{field:label.field,...(label.option==null?{}:{option:label.option})}),!active || !label.enabled)]);
        if(label.row==="input")return row(key,[labelNode,input(`${key}/value`,"",value=>documentAction(doc,"action",{action:label.action,value}))]);
        return row(key,[labelNode,text(`${key}/word`,label.text)]);
      }));
      children.push(...(state.setpoints??[]).map((set:Data,index:number)=>row(`${id}/set/${index}`,[text(`${id}/set/${index}/label`,`${set.label} (${set.unit})`),input(`${id}/set/${index}/value`,String(set.value),value=>{
        const number=Number(value);
        return Number.isFinite(number)?documentAction(doc,"set",{field:set.field,value:Math.max(set.min,Math.min(set.max,number))}):undefined;
      })])));
      children.push(...(state.products??[]).map((product:Data,index:number)=>row(`${id}/product/${index}`,[
        icon(`${id}/product/${index}/icon`,product.sprite),
        button(`${id}/product/${index}/vend`,`${product.category?`${product.category} · `:""}${product.label} (${product.stock})`,documentAction(doc,product.act,product.payload),!active || product.stock<=0),
      ])));
      if(state.matter)children.push(...dataRows(`${id}/matter`,state.matter));
      if(state.stores)children.push(...files(id,doc));
    }
    return pane(id,children,{maxHeight:440});
  });
}

function dataRows(id:string,value:Data,depth=0):UiNode[] {
  if(depth>4 || value==null)return [];
  if(typeof value!=="object")return [text(id,value)];
  return Object.entries(value).slice(0,32).flatMap(([key,entry],index)=>{
    const child=`${id}/${index}`;
    if(entry && typeof entry==="object")return [column(child,[text(`${child}/label`,key),...dataRows(`${child}/value`,entry,depth+1)])];
    return [row(child,[text(`${child}/label`,key),text(`${child}/value`,entry)])];
  });
}

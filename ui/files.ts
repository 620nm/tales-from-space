import type {UiNode} from "@lunatic/ui";
import {button,column,input,row,text,type Data} from "./view";
import {documentAction} from "./documents";

interface Buffer {key:number;text:string;revision:number;dirty:boolean;pending?:string}
const buffers=new Map<string,Buffer>();
let nextEditor=0;


export function files(id:string,doc:Data):UiNode[] {
  const state=doc.state;
  const children:UiNode[]=[];
  children.push(...state.stores.map((store:Data,index:number)=>text(`${id}/store/${index}`,`${store.label}: ${store.used}/${store.capacity} bytes · ${store.count}/${store.count_cap} files`)));
  if(state.media_slot==="loaded")children.push(button(`${id}/eject`,"Eject media",documentAction(doc,"toggle",{field:"media_eject"})));
  for(const [index,file] of (state.files ?? []).entries()) {
    const option=`${file.store}:${file.uid}`;
    children.push(row(`${id}/file/${index}`,[
      button(`${id}/file/${index}/open`,`${file.name}.${file.ext} (${file.size} bytes)`,documentAction(doc,"toggle",{field:"file_open",option})),
      ...(state.stores.length>1?[button(`${id}/file/${index}/copy`,"Copy",documentAction(doc,"toggle",{field:"file_copy",option}))]:[]),
      button(`${id}/file/${index}/delete`,"Delete",documentAction(doc,"toggle",{field:"file_delete",option})),
    ]));
  }
  children.push(row(`${id}/create`,(state.create ?? []).map((ext:string,index:number)=>button(`${id}/create/${index}`,`New .${ext}`,documentAction(doc,"toggle",{field:"file_create",option:ext})))));
  const open=state.open;
  if(open){
    const option=`${open.store}:${open.uid}`;
    const key=`${id}/${option}`;
    let buffer=buffers.get(key);
    if(buffer?.pending !== undefined && open.revision !== buffer.revision && open.body === buffer.pending){buffer.dirty=false;buffer.pending=undefined;}
    if(!buffer){buffer={key:nextEditor++,text:open.body,revision:open.revision,dirty:false};buffers.set(key,buffer);}
    if(!buffer.dirty){buffer.text=open.body;buffer.revision=open.revision;}
    const current=buffer;
    const bodyId=`${id}/editor/body/${current.key}`;
    const conflict=current.revision!==open.revision;
    children.push(column(`${id}/editor`,[
      text(`${id}/editor/title`,`${open.name}.${open.ext}${current.dirty?" · modified":""}`),
      ...(conflict?[text(`${id}/editor/conflict`,"This file changed while you were editing. Revert to load the current version.")]:[]),
      row(`${id}/editor/rename`,[
        {...input(`${id}/editor/name`,open.name,()=>undefined),submitOnly:true},
        {...button(`${id}/editor/rename-button`,"Rename",event=>documentAction(doc,"text",{field:"file_rename",option,text:event.value??open.name})),submit:`${id}/editor/name`},
      ]),
      {...input(bodyId,current.text,()=>undefined,true),submitOnly:true,revision:current.revision},
      row(`${id}/editor/buttons`,[
        {...button(`${id}/editor/save`,"Save",event=>{current.text=event.value??current.text;current.revision=event.revision??current.revision;current.dirty=true;current.pending=current.text;return documentAction(doc,"text",{field:"file_save",option,text:current.text,revision:current.revision});},conflict),submit:bodyId},
        button(`${id}/editor/revert`,"Revert",()=>{buffers.delete(key);return undefined;}),
      ]),
    ]));
  }
  for(const key of buffers.keys()) if(key.startsWith(`${id}/`) && !key.endsWith(`/${state.open?.store}:${state.open?.uid}`))buffers.delete(key);
  return children;
}

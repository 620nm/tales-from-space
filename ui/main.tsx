import type {GuestUi,UiNode} from "@lunatic/ui";
import {begin,button,column,event,icon,input,node,pane,row,text,type Data} from "./view";
import {inventory,shortcut} from "./inventory";
import {documents} from "./documents";

const ui: GuestUi = {
  render(raw) {
    const view=raw as Data; begin();
    const children:UiNode[]=[];
    const state=view.state ?? {};
    const jobs=state.jobs?.jobs;
    if(jobs) children.push(pane("lobby",[text("lobby-title","Charter crew manifest — choose a role"),...jobs.map((job:Data)=>button(`job/${job.key}`,`${job.name} · ${job.taken}${job.slots===null?" aboard":`/${job.slots}`}`,{kind:"join",job:job.key},job.slots!==null && job.taken>=job.slots))],{position:"absolute",left:24,top:24,width:360,maxHeight:450}));
    const body=state.bodyStatus;
    if(body && (!body.state.controllable || !body.state.animate)) children.push(pane("body-state",[text("body-label",body.state.label),...(body.can_respawn?[button("respawn","Respawn",{kind:"respawn"})]:[])],{position:"absolute",left:24,top:24,width:360}));
    const tray=inventory(view); if(tray)children.push(tray);
    const chat=(view.log ?? []).slice(-24).map((line:Data,index:number)=>text(`log/${index}`,`${line.channel?`[${line.channel}] `:""}${line.name?`${line.name}: `:""}${line.text}`));
    children.push(pane("chat-pane",[
      column("log",chat,{maxHeight:180,overflow:"auto"}),
      ...(view.body?[input("chat","",value=>value.trim()?{kind:"say",text:value}:undefined)]:[]),
    ],{position:"absolute",left:14,bottom:0,width:390,maxHeight:240}));
    const docs=documents(view);
    if(docs.length)children.push(column("documents",docs,{position:"absolute",right:14,top:14,width:470,maxHeight:512,overflow:"auto",pointerEvents:"auto"}));
    if(state.examine)children.push(pane("examine",[
      row("examine-title",[icon("examine-icon",state.examine.sprite),text("examine-heading",state.examine.title),button("examine-close","Close",{kind:"dismiss",panel:"examine"})]),
      ...state.examine.lines.map((line:Data,index:number)=>text(`examine-line/${index}`,line.spans.map((span:Data)=>span.text).join(""))),
    ],{position:"absolute",left:14,top:14,width:340,maxHeight:320}));
    if(state.context)children.push(pane("context",[
      text("context-title","On this tile"),button("context-close","Close",{kind:"dismiss",panel:"context"}),
      ...state.context.map((target:Data,index:number)=>row(`context/${index}`,[icon(`context/${index}/icon`,target.sprite),button(`context/${index}/use`,target.name,{kind:"context",target:target.target})])),
    ],{position:"absolute",left:14,top:24,width:340,maxHeight:320}));
    if(state.identity?.you != null && state.progress?.length) children.push({
      ...column("progress",state.progress.map((job:Data)=>node("progress",`progress/${job.job}/${job.sequence}`,{value:"0",duration:Math.max(1,Math.min(3600000,job.ms)),expires:Math.max(1,Math.min(3600000,job.ms))})),{width:120,gap:2}),
      anchor:String(state.identity.you),
    });
    for(const speech of state.speech ?? []) children.push({
      ...pane(`speech/${speech.id}/${speech.sequence}`,[text(`speech/${speech.id}/text`,`${speech.channel?`[${speech.channel}] `:""}${speech.text}`)],{width:280,padding:4}),
      anchor:String(speech.id),expires:5000,
    });
    return pane("gameplay",children,{width:"100%",height:"100%",backgroundColor:"transparent",pointerEvents:"none",padding:0,overflow:"hidden"});
  },
  onEvent(e,view) {
    const command=shortcut(e.id,view); if(command)return {action:command};
    return event(e);
  },
};
export default ui;

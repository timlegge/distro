(function(){tinymce.PluginManager.requireLangPack('foswikibuttons');tinymce.create('tinymce.plugins.FoswikiButtons',{formats_lb:null,init:function(ed,url){ed.fw_formats=ed.getParam("foswikibuttons_formats");ed.fw_lb=null;ed.addCommand('foswikibuttonsTT',function(){if(!ed.selection.isCollapsed())
ed.execCommand('mceSetCSSClass',false,"WYSIWYG_TT");});ed.addButton('tt',{title:'foswikibuttons.tt_desc',cmd:'foswikibuttonsTT',image:url+'/img/tt.gif'});ed.addCommand('foswikibuttonsColour',function(){if(ed.selection.isCollapsed())
return;ed.windowManager.open({location:false,menubar:false,toolbar:false,status:false,url:url+'/colours.htm',width:240,height:140,movable:true,popup_css:false,inline:true},{plugin_url:url});});ed.addButton('colour',{title:'foswikibuttons.colour_desc',cmd:'foswikibuttonsColour',image:url+'/img/colour.gif'});ed.addCommand('foswikibuttonsAttach',function(){var htmpath='/attach.htm',htmheight=250;if(null!==FoswikiTiny.foswikiVars.TOPIC.match(/(X{10}|AUTOINC[0-9]+)/)){htmpath='/attach_error_autoinc.htm',htmheight=125;}
ed.windowManager.open({location:false,menubar:false,toolbar:false,status:false,url:url+htmpath,width:350,height:htmheight,movable:true,inline:true},{plugin_url:url});});ed.addButton('attach',{title:'foswikibuttons.attach_desc',cmd:'foswikibuttonsAttach',image:url+'/img/attach.gif'});ed.addCommand('foswikibuttonsHide',function(){if(FoswikiTiny.saveEnabled){if(ed.getParam('fullscreen_is_enabled')){ed.onGetContent.add(function(){tinymce.DOM.win.setTimeout(function(){var e=tinyMCE.activeEditor;tinyMCE.execCommand("mceToggleEditor",true,e.id);FoswikiTiny.switchToRaw(e);},10);});ed.execCommand('mceFullScreen');}
else{tinyMCE.execCommand("mceToggleEditor",true,ed.id);FoswikiTiny.switchToRaw(ed);}}});ed.addButton('hide',{title:'foswikibuttons.hide_desc',cmd:'foswikibuttonsHide',image:url+'/img/hide.gif'});ed.addCommand('foswikibuttonsFormat',function(ui,fn){var format=null;for(var i=0;i<ed.fw_formats.length;i++){if(ed.fw_formats[i].name===fn){format=ed.fw_formats[i];break;}}
if(format.el!==null){ed.execCommand('FormatBlock',false,format.el);}
if(format.style!==null){ed.execCommand('mceSetCSSClass',false,format.style);}
ed.nodeChanged();});ed.onNodeChange.add(this._nodeChange,this);},getInfo:function(){return{longname:'Foswiki Buttons Plugin',author:'Crawford Currie',authorurl:'http://c-dot.co.uk',infourl:'http://c-dot.co.uk',version:2};},createControl:function(n,cm){if(n=='foswikiformat'){var ed=tinyMCE.activeEditor;var m=cm.createListBox(ed.id+'_'+n,{title:'Format',onselect:function(format){ed.execCommand('foswikibuttonsFormat',false,format);}});var formats=ed.getParam("foswikibuttons_formats");for(var i=0;i<formats.length;i++){m.add(formats[i].name,formats[i].name);}
m.selectByIndex(0);ed.fw_lb=m;return m;}
return null;},_nodeChange:function(ed,cm,n,co){if(n==null)
return;if(co){cm.setDisabled('tt',true);cm.setDisabled('colour',true);}else{cm.setDisabled('tt',false);cm.setDisabled('colour',false);}
var elm=ed.dom.getParent(n,'.WYSIWYG_TT');if(elm!=null)
cm.setActive('tt',true);else
cm.setActive('tt',false);elm=ed.dom.getParent(n,'.WYSIWYG_COLOR');if(elm!=null)
cm.setActive('colour',true);else
cm.setActive('colour',false);if(ed.fw_lb){var puck=-1;var nn=n.nodeName.toLowerCase();do{for(var i=0;i<ed.fw_formats.length;i++){if((!ed.fw_formats[i].el||ed.fw_formats[i].el==nn)&&(!ed.fw_formats[i].style||ed.dom.hasClass(ed.fw_formats[i].style))){puck=i;if(puck>0)
break;}}}while(puck<0&&(n=n.parentNode)!=null);if(puck>=0){ed.fw_lb.selectByIndex(puck);}else{ed.fw_lb.selectByIndex(0);}}
return true;}});tinymce.PluginManager.add('foswikibuttons',tinymce.plugins.FoswikiButtons);})();
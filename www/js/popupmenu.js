// $Id$

//
// AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
// CREATED  : 2003/02/18 14:33:14
//
// COPYRIGHT: AFNIC (c) 2003
// CONTACT  : zonecheck@nic.fr
// LICENSE  : GPL v2.0 (or MIT/X11-like after agreement)
//
// $Revision$ 
// $Date$
//
// CONTRIBUTORS: (see also CREDITS file)
//
//

// sanity check
if (zc_publish_path == null)
  alert("ZoneCheck internal error: zc_publish_path not initialized");


/* 
 * ZC_Popup
 */
function ZC_Popup(id, title) {
    this.id    = id;
    this.title = title
    this.menu  = null;
    this.item  = [];
}

ZC_Popup.prototype.create = function() {
  var row, cell, link;
  var self  = this
  var table = document.createElement('TABLE');
  var tbody = document.createElement('TBODY');
  table.appendChild(tbody);
  table.cellSpacing = 1;
  table.className   = "zc-popup";
  table.id          = this.id;  // XXX: not working
  table.style.visibility = 'hidden';
  table.style.position   = "absolute";

  // title bar
  row              = document.createElement('TR');
  row.className    = 'zc-title';


  cell             = document.createElement('TD');
  cell.className   = 'zc-title';
  cell.colSpan     = 7;
  if (this.title) 
    cell.innerHTML = this.title;
  row.appendChild(cell);

  cell             = document.createElement('TD');
  cell.colSpan     = 1;
  cell.align       = 'right';
  link             = document.createElement('A');
  link.href        = '#';
  link.onclick     = function() { self.hide();             return false; };
  link.onmouseover = function() { window.status = "close"; return true;  };
  link.onmouseout  = function() { window.status = "";      return true;  };

  var x = document.createTextNode('x');
  link.appendChild(x);
  cell.appendChild(link);
  row.appendChild(cell);
  tbody.appendChild(row);
  
  // items
  for (var i = 0 ; i < this.item.length ; i++) {
    row            = document.createElement('TR');
    row.className  = "zc-item";
    cell           = document.createElement('TD');
    cell.colSpan   = 8;
    cell.align     = 'left';
    cell.innerHTML = this.item[i][0];
    cell.onclick   = this.item[i][1];
    row.appendChild(cell);
    tbody.appendChild(row);
  }
  
  document["body"].appendChild(table);
  this.menu = table;
}

ZC_Popup.prototype.hide   = function() {
  this.menu.style.visibility = 'hidden';
}

ZC_Popup.prototype.show   = function(x, y) {
  var left = document.body.scrollLeft;
  var top  = document.body.scrollTop;

  if (this.menu.offsetWidth + x > document.body.clientWidth) {
    left += document.body.clientWidth - this.menu.offsetWidth;
  } else {
    left += x;
  }

  if (this.menu.offsetHeight + y > document.body.clientHeight) {
    top += document.body.clientHeight - this.menu.offsetHeight;
  } else {
    top += y;
  }

  this.menu.style.left     = left + "px";
  this.menu.style.top      = top  + "px";
  this.menu.style.visibility = 'visible';
}

ZC_Popup.prototype.add    = function(label, func) {
  this.item.push([label, func])
}


/***********************************************************************/

function zc_contextmenu_setlocale(l10n_testname,   l10n_details,
				  l10n_references, l10n_elements) {
  zc_l10n_testname   = l10n_testname;
  zc_l10n_details    = l10n_details;
  zc_l10n_references = l10n_references;
  zc_l10n_elements   = l10n_elements;
}

function zc_contextmenu_start() {
  var hidefunc = function (className, tagName) {
    var elt = document.getElementsByTagName(tagName);
    for (var i = 0 ; i < elt.length ; i++) {
      if (elt[i].className == className) {
	if (elt[i].style.display == "none") {
	  elt[i].style.display     = elt[i].style.display_old;
	} else {
	  elt[i].style.display_old = elt[i].style.display;
	  elt[i].style.display     = "none";
	}
      }
    }
  };

  var ctx = new ZC_Popup("zc_contextmenu", "+/-");
  ctx.add("<IMG src='"+ zc_publish_path+"/img/gear.png'>"+
	  "&nbsp;"+zc_l10n_testname,
	  function () { hidefunc('zc-name', 'DIV'); });
  ctx.add("<IMG src='"+ zc_publish_path+"/img/details.png'>"+
	  "&nbsp;"+zc_l10n_details,
	  function () { hidefunc('zc-details', 'UL'); });
  ctx.add("<IMG src='"+ zc_publish_path+"/img/ref.png'>"+
	  "&nbsp;"   +zc_l10n_references,
	  function () { hidefunc('zc-ref', 'UL'); });
  ctx.add("<IMG src='"+ zc_publish_path+"/img/element.png'>"+
	  "&nbsp;"+zc_l10n_elements,
	  function () { hidefunc('zc-element', 'UL'); });

  ctx.create();

  document.oncontextmenu = function(event) { 
    if (event == null)       // fucking IE
      event = window.event;  //  ok, it hasn't been standardize
    ctx.show(event.clientX, event.clientY); 
    return false; 
  };
}

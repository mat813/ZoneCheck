// $Id$

//
// AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
// CREATED  : 2003/02/18 14:33:14
//
// COPYRIGHT: AFNIC (c) 2003
// CONTACT  : zonecheck@nic.fr
// LICENSE  : GPL v2.0
//
// $Revision$ 
// $Date$
//
// CONTRIBUTORS:
//
//

function getElementsByClassAndTag(className, tagName) {
  var all      = document.getElementsByTagName(tagName);
  var elements = new Array();
  for (var e = 0; e < all.length; e++)
    if (all[e].className == className)
      elements[elements.length] = all[e];
  return elements;
}

function ZC_Popup_create() {
  var row, cell;
  var self  = this
  var table = document.createElement('TABLE');
  var tbody = document.createElement('TBODY');
  table.appendChild(tbody);
  table.cellSpacing = 1;
  table.className   = "zc_popup";
  table.id          = this.id;  // XXX: not working
  table.style.visibility = 'hidden';
  table.style.position   = "absolute";

    
  // title bar
  row = document.createElement('TR');
  cell = document.createElement('TD');
  cell.colSpan = 8;
  cell.align = 'right';
  cell.className = 'header';
  link             = document.createElement('A');
  link.href        = '#';
  link.onclick     = function() { self.hide();             return false; };
  link.onmouseover = function() { window.status = "close"; return true;  };
  link.onmouseout  = function() { window.status = "";      return true;  };

  link.className = 'menuitem';
  var x = document.createTextNode('x');
  link.appendChild(x);
  cell.appendChild(link);
  row.appendChild(cell);
  tbody.appendChild(row);
  
  for (var i = 0 ; i < this.item.length ; i++) {
    row = document.createElement('TR');
    cell = document.createElement('TD');
    cell.colSpan = 8;
    cell.align = 'left';
    cell.innerHTML = this.item[i][0];
    cell.onclick   = this.item[i][1];
  }
  row.appendChild(cell);
  tbody.appendChild(row);
  
  document["body"].appendChild(table);
  this.menu = table;
}


function ZC_Popup_add() {
}

function ZC_Popup(id) {
    this.id   = id;
    this.menu = null;
    this.item = [];
}

ZC_Popup.prototype.create = ZC_Popup_create;

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

function zc_yo() {
  ctx = new ZC_Popup("contextmenu");
  ctx.add("<IMG src='/zc/img/details.png'> toggle details",
	  function () {
	    var elements = document.getElementsByTagName('UL');
	    for (var i = 0 ; i < elements.length ; i++) {
	      if (elements[i].className == "zc_details") {
		if (elements[i].style.display == "none") {
		  elements[i].style.display = elements[i].style.display_old;
		} else {
		  elements[i].style.display_old = elements[i].style.display;
		  elements[i].style.display = 'none';
		}
	      }
	    }
	  });

  ctx.create();


  document.oncontextmenu = function(event) { 
    if (event == null)       // fucking IE
      event = window.event;  //  ok, it hasn't been standardize
    ctx.show(event.clientX, event.clientY); 
    return false; 
  };
}

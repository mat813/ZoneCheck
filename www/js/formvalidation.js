// $Id$

// 
// CONTACT     : zonecheck@nic.fr
// AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
//
// CREATED     : 2003/02/26 18:38:10
// REVISION    : $Revision$ 
// DATE        : $Date$
//
// CONTRIBUTORS: (see also CREDITS file)
//
//
// LICENSE     : GPL v2 (or MIT/X11-like after agreement)
// COPYRIGHT   : AFNIC (c) 2003
//
// This file is part of ZoneCheck.
//
// ZoneCheck is free software; you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
// 
// ZoneCheck is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with ZoneCheck; if not, write to the Free Software Foundation,
// Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
//

function zc_form_setlocale(emptyzone) {
  zc_form_l_emptyzone = emptyzone;
}

function zc_form_validate(form) {
  var zone = form["zone"].value;
  zone = zone.replace(/^\s+/,'').replace(/\s+$/,'');

  if (zone.length == 0) {
    alert(zc_form_l_emptyzone);
    return false;
  } else {
    return true;
  }
}

function zc_form_clear(form) {
  var i;

  if (form["zone"])
    form["zone"].value = "";
  for (i = 0 ; form["ns"+i] ; i++)
    form["ns" +i].value = "";
  for (i = 0 ; form["ips"+i] ; i++)
    form["ips" +i].value = "";

  return 0;
}

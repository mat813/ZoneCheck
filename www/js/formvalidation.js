// $Id$

//
// AUTHOR   : Stephane D'Alu <sdalu@nic.fr>
// CREATED  : 2003/02/26 18:38:10
//
// COPYRIGHT: AFNIC (c) 2003
// CONTACT  : zonecheck@nic.fr
// LICENSE  : GPL v2 (or MIT/X11-like after agreement)
//
// $Revision$ 
// $Date$
//
// CONTRIBUTORS: (see also CREDITS file)
//
//

function zc_form_setlocale(emptyzone) {
  zc_form_l_emptyzone = emptyzone;
}

function zc_form_valid(form) {
  var zone = form["zone"].value;
  zone = zone.replace(/^\s+/,'').replace(/\s+$/,'');

  if (zone.length == 0) {
    alert(zc_form_l_emptyzone);
    return 0;
  } else {
    return 1;
  }
}

function zc_form_check(form) {
  if (zc_form_valid(form))
    form.submit();
  return 0;
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

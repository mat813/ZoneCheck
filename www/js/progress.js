// $Id$

// 
// AUTHOR : Stephane D'Alu <sdalu@nic.fr>
// CREATED: 2002/10/02 13:58:17
//
// $Revision$ 
// $Date$
//
// CONTRIBUTORS:
//
//

//
function zc_sec_to_timestr(sec) {
  if (sec < 0)
    return "--:--";

  hrs = Math.floor(sec / 3600); sec %= 3600;
  min = Math.floor(sec / 60);   sec %= 60;
  
  if (sec < 10)
    sec = "0" + sec;
   
  if (hrs > 0) {
    if (min < 10)
      min = "0" + min;
    return hrs + ":" + min + ":" + sec;
  } else {
    return min + ":" + sec;
  }
}

//
function zc_speed_tostr(speed) {
  if (speed < 0)
    return "--.--";

  speed = speed * 100;
  cnt = Math.floor(speed) % 100;
  if (cnt < 10)
    cnt = "0" + cnt;
  unt = Math.floor(speed / 100);

  return unt + "." + cnt;
}

// switch off elements
function zc_pgr_off(id) {
  document.getElementById(id).style.display = "none";
}

// remove id (so that it can be reused)
function zc_pgr_clear_id(id) {
  document.getElementById(id).id = "";
}

//
function zc_pgr_locale(tprogress, progress, test, speed, time) {
  zc_pgr_l_title_progress = tprogress;
  zc_pgr_l_progress       = progress;
  zc_pgr_l_test           = test;
  zc_pgr_l_speed          = speed;
  zc_pgr_l_time           = time;
}

// start progress bar
function zc_pgr_start(count) {
  zc_pgr_starttime = (new Date()).getTime();
  zc_pgr_lasttime  = zc_pgr_starttime;
  zc_pgr_processed = 0;
  zc_pgr_totaltime = 0;
  zc_pgr_precision = 1000;
  zc_pgr_totalsize = 0;
  zc_pgr_totalsize = count;

  s  = "";
  if (zc_pgr_l_title_progress != null) {
    s += "<H2  id=\"zc_pgr_title\">" + zc_pgr_l_title_progress + "</H2>";
  }

  s += "<DIV id=\"zc_pgr_pbar\">";
  s += "<TABLE id=\"zc_pgr_pbar_out\"><TR><TD>";
  s += "<TABLE id=\"zc_pgr_pbar_in\" style='border-collapse: collapse;'>";
  s += "<TR>";
  s += "<TD colspan=3>" + zc_pgr_l_progress + "</TD>";
  s += "<TD style='width: 2em;'></TD>"
  s += "<TD style='text-align: center;'>&nbsp;&nbsp;" + zc_pgr_l_test + "&nbsp;&nbsp;</TD>";
  s += "<TD style='text-align: center;'>&nbsp;&nbsp;" + zc_pgr_l_speed + "&nbsp;&nbsp;</TD>";
  s += "<TD style='text-align: center;'>&nbsp;&nbsp;" + zc_pgr_l_time + "&nbsp;&nbsp;</TD>";
  s += "</TR>";
  s += "<TR>";
  s += "<TD id=\"zc_pgr_pct\"   style='text-align: right; width: 4em'></TD>";
  s += "<TD id=\"zc_pgr_pct1\"  style='border: solid; background-color: #123456;'></TD>";
  s += "<TD id=\"zc_pgr_pct2\"  style='border: solid;'></TD>";
  s += "<TD></TD>";
  s += "<TD id=\"zc_pgr_proc\"  style='text-align: center;'></TD>";
  s += "<TD id=\"zc_pgr_speed\" style='text-align: center;'></TD>";
  s += "<TD id=\"zc_pgr_eta\"   style='text-align: center;'></TD>";
  s += "</TR>";
  s += "<TR><TD colspan=7>&nbsp;</TD></TR>";
  s += "<TR>";
  s += "<TD id=\"zc_pgr_desc\" colspan=7></TD>";
  s += "</TR>";
  s += "</TABLE>";
  s += "</TD><TR></TABLE>";
  s += "</DIV>";
  document.write(s);

  zc_pgr_update(0, -1, -1, "...");
}

function zc_pgr_update(pct, speed, eta, desc) {
  // write progress bar
  document.getElementById("zc_pgr_desc" ).innerHTML = desc;
  document.getElementById("zc_pgr_pct"  ).innerHTML = pct + "%&nbsp;";
  document.getElementById("zc_pgr_pct1" ).style.width = 3 * pct;
  document.getElementById("zc_pgr_pct2" ).style.width = 3 * (100-pct);
  document.getElementById("zc_pgr_proc" ).innerHTML = zc_pgr_processed;
  document.getElementById("zc_pgr_speed").innerHTML = zc_speed_tostr(speed);
  document.getElementById("zc_pgr_eta"  ).innerHTML = zc_sec_to_timestr(eta);
}

// process element in progress bar
function zc_pgr_process(desc) {
  // one more
  zc_pgr_processed += 1;

  // percent done
  pct = Math.ceil(100 * zc_pgr_processed / zc_pgr_totalsize);

  // compute spent time
  //  use precision to avoid quick variation in speed and eta
  nowtime   = (new Date()).getTime();
  deltatime = nowtime - zc_pgr_lasttime;
  if (deltatime > zc_pgr_precision) {
    zc_pgr_totaltime = nowtime - zc_pgr_starttime;
    zc_pgr_lasttime  = nowtime;
  }

  // speed
  speed = zc_pgr_totaltime ? (1000 * zc_pgr_processed / zc_pgr_totaltime) : -1.0;

  // estimated time
  eta   = speed < 0 ? -1.0 : Math.ceil((zc_pgr_totalsize - zc_pgr_processed) / speed);

  zc_pgr_update(pct, speed, eta, desc);
}



// finish progress bar
function zc_pgr_finish() {
  if (zc_pgr_l_title_progress != null) {
    zc_pgr_off("zc_pgr_title");
    zc_pgr_clear_id("zc_pgr_title"   );
  }
  zc_pgr_off("zc_pgr_pbar" );
  zc_pgr_clear_id("zc_pgr_pbar"    );
  zc_pgr_clear_id("zc_pgr_pbar_out");
  zc_pgr_clear_id("zc_pgr_pbar_in" );
  zc_pgr_clear_id("zc_pgr_pct"     );
  zc_pgr_clear_id("zc_pgr_pct1"    );
  zc_pgr_clear_id("zc_pgr_pct2"    );
  zc_pgr_clear_id("zc_pgr_proc"    );
  zc_pgr_clear_id("zc_pgr_speed"   );
  zc_pgr_clear_id("zc_pgr_eta"     );
  zc_pgr_clear_id("zc_pgr_desc"    );
}

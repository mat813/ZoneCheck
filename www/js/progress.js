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


zc_pgr_starttime = (new Date()).getTime();
zc_pgr_lasttime  = zc_pgr_starttime;
zc_pgr_processed = 0;
zc_pgr_totaltime = 0;
zc_pgr_precision = 1000;
zc_pgr_totalsize = 0;

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


// start progress bar
function zc_pgr_start(count) {
  zc_pgr_totalsize = count
  document.write("<H2  id=\"zc_pgr_title\">Progress</H2>");
  document.write("<DIV id=\"zc_pgr_pbar\"></DIV>");
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

  // write progress bar

  str = "";
  str += "<TABLE class=\"zc_test\">";
  str += "<TR>";
  str += "<TD colspan=3>Progression</TD>";
  str += "<TD>Tests</TD>";
  str += "<TD>Speed</TD>";
  str += "<TD>Time</TD>";
  str += "</TR>";
  str += "<TR>";
  str += "<TD style='text-align: right; width: 4em'>" + pct + "%&nbsp;</TD>";
  str += "<TD style='border: solid; background-color: #123456; width:" + 3 * pct + "px'></TD>";
  str += "<TD style='border: solid; width:" + 3 * (100 - pct) + "px'></TD>";
  str += "<TD style='text-align: right; witdh: 4ex;'>" + zc_pgr_processed + "</TD>";
  str += "<TD style='text-align: right; width: 6ex;'>" + zc_speed_tostr(speed) + "</TD>";
  str += "<TD style='text-align: right; width: 8ex;'>" + zc_sec_to_timestr(eta) + "</TD>";
  str += "</TR>";
  str += "<TR>";
  str += "<TD colspan=5>" + desc + "</TD>";
  str += "</TR>";
  str += "</TABLE>";
  document.getElementById("zc_pgr_pbar").innerHTML = str;
}

// finish progress bar
function zc_pgr_finish() {
  zc_pgr_off("zc_pgr_title");
  zc_pgr_off("zc_pgr_pbar");
}

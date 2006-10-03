#!/usr/bin/python

from xml.dom.ext.reader import Sax2
from xml.dom.ext import PrettyPrint
from xml import xpath
from xml.dom import getDOMImplementation
import sys
import os
import re

def file2DOM(filename):
    reader = Sax2.Reader()
    doc = reader.fromStream(filename)
    return doc

def usage():
    myself = sys.argv[0]
    return "Usage: %s zonecheck-profile" % myself

def fatal(message):
    sys.stderr.write("%s\n" % message)
    sys.exit(1)

def all_check_messages(dir, lang='en'):
    messages = {}
    for file in os.listdir(dir):
        if not re.search("\.%s$" % lang, file):
            continue
        dom = file2DOM("file:%s/%s" % (dir, file))
        match = xpath.Evaluate("/msgcat/check", dom)
        if match:
            for check in match:
                messages[check.attributes.getNamedItem('name').nodeValue] = \
                                                                          check
    return messages

if __name__ == '__main__':
    if len(sys.argv) != 2:
        fatal (usage())
    profilename = sys.argv[1]
    messages = all_check_messages("%s/AFNIC/zonecheck/locale/test" % \
                                  os.environ['HOME'], "en")
    profile = file2DOM(profilename)
    html_result = getDOMImplementation().createDocument(None, "html", None)
    match = xpath.Evaluate("/config/profile", profile)
    if match:
        profilenode = match[0]
    else:
        raise Exception("No config in the DOM tree <%s>" % \
                        profile.childNodes[0].nodeName)
    #print "%s (%s)" % (profilenode.attributes.getNamedItem('name').nodeValue,
    #                   profilenode.attributes.getNamedItem('longdesc').nodeValue)
    h1 = html_result.documentElement.appendChild(html_result.createElement('h1'))
    h1.appendChild(html_result.createTextNode("%s (%s)" % \
                                     (profilenode.attributes.getNamedItem('name').nodeValue,
                                      profilenode.attributes.getNamedItem('longdesc').nodeValue)))
    match = xpath.Evaluate("rules", profilenode)
    if match:
        rulenodes = match
    else:
        raise Exception("No rules in the DOM tree <%s>" % \
                        profilenode.childNodes[0].nodeName)
    for rule in rulenodes:
         html_rule = html_result.documentElement.appendChild(html_result.createElement("h2"))
         html_rule.appendChild(html_result.createTextNode("%s" % rule.attributes.getNamedItem('class').nodeValue))
         match = xpath.Evaluate("descendant::check", rule)
         if match:
             checknodes = match
         else:
             raise Exception("No checks in the DOM tree <%s>" % \
                        rule.childNodes[0].nodeName)
         for check in checknodes:
             html_check = html_result.documentElement.appendChild(html_result.createElement("h3"))
             html_check.appendChild(html_result.createTextNode("%s" % check.attributes.getNamedItem('name').nodeValue))
             name = check.attributes.getNamedItem('name').nodeValue
             if messages.has_key(name):
                 match = xpath.Evaluate("name/text()", messages[name])
                 if match:
                     longname = match[0].nodeValue
                 else:
                     raise Exception("No long name in the DOM tree <%s>" % \
                                     messages[name].childNodes[0].nodeName)
                 html_check_msg = html_result.documentElement.appendChild(html_result.createElement("p"))
                 html_check_msg.appendChild(html_result.createTextNode("%s" % longname))
                 #print "%s: %s" % (name, longname)
             else:
                 raise Exception("Test %s not found in the message catalogs")
    PrettyPrint(html_result)          

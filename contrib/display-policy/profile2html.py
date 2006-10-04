#!/usr/bin/python

# TODO: recode in ElementTree, more Pythonesque than DOM!
from xml.dom.ext.reader import Sax2
from xml.dom.ext import PrettyPrint
from xml import xpath
from xml.dom import getDOMImplementation
import sys
import os
import re
import string
import getopt

LANG = "en"
stylesheet = None

def file2DOM(filename):
    reader = Sax2.Reader()
    doc = reader.fromStream(filename)
    return doc

def usage():
    myself = sys.argv[0]
    return "Usage: %s [-l language] [-s CSS-stylesheet] zonecheck-profile" % myself

def fatal(message):
    sys.stderr.write("%s\n" % message)
    sys.exit(1)

def all_check_messages(dir, lang='en'):
    messages = {}
    explanations = {}
    for file in os.listdir(dir):
        if not re.search("\.%s$" % lang, file):
            continue
        dom = file2DOM("file:%s/%s" % (dir, file))
        checks = from_xpath("/msgcat/check", dom)
        for check in checks:
            messages[attribute(check, 'name')] = check
        local_explanations = from_xpath("/msgcat/shortcut/explanation", dom, required=False)
        if local_explanations is not None:
            for explanation in local_explanations:
                explanations["shortcut:%s" % attribute(explanation, 'name')] = explanation
    return (messages, explanations)

def from_xpath(expr, dom, required=True, only_one_item=False):
    match = xpath.Evaluate(expr, dom)
    if match:
        if only_one_item:
            if len(match) > 1:
                raise Exception("More than one item (%i) found for \"%s\" in the DOM tree <%s>" % \
                        (len(match), expr, dom.nodeName))
            else:
                return match[0]
        else:
            return match
    else:
        if required:
            raise Exception("No \"%s\" in the DOM tree <%s>" % \
                        (expr, dom.nodeName))
        else:
            return None

def attribute(node, attname):
    return node.attributes.getNamedItem(attname).nodeValue

def explanation_text(node):
    reference = from_xpath("@sameas", node, required=False)
    if reference is not None:
        (category, ref) = string.split(reference[0].nodeValue, ":")
        details = explanations["%s:%s" % (category, ref)]
        message = concat_text_nodes(from_xpath("src/title/text()", details)) + ". " + \
               concat_text_nodes(from_xpath("src/para/text()", details))
    else:
        source = from_xpath("src", node, required=False, only_one_item=True)
        if source is not None:
            message = concat_text_nodes(from_xpath("title/text()", source)) + ". " + \
                   concat_text_nodes(from_xpath("para/text()", source))
        else:
            message = ""
    # TODO: transform the URLs in <a> elements
    return mark_rfc(message)

def mark_rfc(msg):
    """ Finds references to IETF RFCs and turn them into hypertext """
    chunks = re.split ("RFC-? ?([0-9]+)",
                   msg)
    result = html_result.createElement("p")
    for chunk in chunks:
        if re.match ("[0-9]+", chunk):
            link = html_result.createElement("a")
            url = html_result.createAttribute("href")
            url.nodeValue = "http://www.ietf.org/rfc/rfc%i.txt" % int(chunk)
            link.setAttributeNode(url)
            link.appendChild(html_result.createTextNode("RFC %i" % int(chunk)))
            result.appendChild(link)
        else:
            result.appendChild(html_result.createTextNode(chunk))
    return result

def concat_text_nodes(list):
    result = ""
    for text in list:
        result = result + " " + text.nodeValue
    return result

if __name__ == '__main__':
    try:
        optlist, args = getopt.getopt (sys.argv[1:], "hl:s:",
                                       ["help", "version",
                                        "lang=",
                                        "stylesheet="])
        for option, value in optlist:
            if option == "--help" or option == "-h":
                print (usage())
                sys.exit(0)
            elif option == "--version":
                print sys.argv[0] + " (CVS $Revision$)\n" + " Python " + sys.version
                sys.exit(0)
            elif option == "--lang" or option == "-l": LANG = value
            elif option == "--stylesheet" or option == "-s": stylesheet = value
            else: error ("Unknown option " + option)
    except getopt.error, reason:
        fatal (usage() + "\n%s" % reason)
    if len(args) < 1 or len(args) > 1:
        fatal (usage())
    profilename = args[0]
    (messages, explanations) = all_check_messages("%s/AFNIC/zonecheck/locale/test" % \
                                  os.environ['HOME'], LANG)
    profile = file2DOM(profilename)
    html_result = getDOMImplementation().createDocument(
        None,
        "html",
        getDOMImplementation().createDocumentType(
           "html",
           "-//W3C//DTD XHTML 1.0 Strict//EN",
           "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"))
    # TODO: allow to set a CSS stylesheet
    head = html_result.documentElement.appendChild(html_result.createElement('head'))
    body = html_result.documentElement.appendChild(html_result.createElement('body'))
    profilenode = from_xpath("/config/profile", profile, only_one_item=True)
    if LANG == "en":
        blurb = "Tests made by Zonecheck at "
    elif LANG == "fr":
        blurb = "Tests effectues par Zonecheck a "
    else:
        blurb = ""
    title = head.appendChild(html_result.createElement('title'))
    title.appendChild(html_result.createTextNode("%s %s (%s)" % \
                                     (blurb,
                                      attribute (profilenode, 'name'),
                                      attribute (profilenode, 'longdesc'))))
    if stylesheet is not None:
        css = head.appendChild(html_result.createElement('link'))
        css_rel = html_result.createAttribute("rel")
        css_rel.nodeValue = "stylesheet"
        css.setAttributeNode(css_rel)
        css_type = html_result.createAttribute("type")
        css_type.nodeValue = "text/css"
        css.setAttributeNode(css_type)
        css_url = html_result.createAttribute("href")
        css_url.nodeValue = stylesheet
        css.setAttributeNode(css_url)
    h1 = body.appendChild(html_result.createElement('h1'))
    h1.appendChild(html_result.createTextNode("%s %s (%s)" % \
                                     (blurb,
                                      attribute (profilenode, 'name'),
                                      attribute (profilenode, 'longdesc'))))
    rulenodes = from_xpath("rules", profilenode)
    # TODO: add an anchor
    for rule in rulenodes:
         html_rule = body.appendChild(html_result.createElement("h2"))
         if LANG == "en":
             blurb = "Tests of class "
         elif LANG == "fr":
             blurb = "Tests de la classe "
         else:
             blurb = ""
         html_rule.appendChild(html_result.createTextNode("%s \"%s\"" % (blurb,
                                                                     attribute(rule, 'class'))))
         checknodes = from_xpath("descendant::check", rule)
         # TODO: add an anchor
         for check in checknodes:
             name = attribute(check, 'name')
             precondition = from_xpath("../../when", check, required=False)
             is_else = not from_xpath("../@value", check, required=False)
             if precondition:
                 if is_else:
                     # TODO: internationalize
                     condition = "(Only if \"" + \
                             from_xpath("../../@test/text()", check, only_one_item=True).nodeValue + \
                             "\" != \"" + \
                             from_xpath("../../when/@value", check, only_one_item=True).nodeValue + \
                             "\") " 
                 else:
                     condition = "(Only if \"" + \
                             from_xpath("../../@test/text()", check, only_one_item=True).nodeValue + \
                             "\" = \"" + \
                             from_xpath("../@value", check, only_one_item=True).nodeValue + \
                             "\") " 
             else:
                 condition = ""
             html_check = body.appendChild \
                          (html_result.createElement("h3"))
             if LANG == "en":
                 blurb = "Test "
             elif LANG == "fr":
                 blurb = "Test "
             else:
                 blurb = ""
             severity = from_xpath("@severity", check, only_one_item=True).nodeValue
             # TODO: internationalize it
             if severity == "f":
                 severity = " (MANDATORY)"
             elif severity == "w":
                 severity = " (OPTIONAL)"
             else:
                 severity = " (UNKNOWN SEVERITY \"%s\")" % severity
             html_check.appendChild(html_result.createTextNode("%s%s \"%s\" %s" % (condition,
                                                                                   blurb, name,
                                                                                   severity)))
             if messages.has_key(name):
                 # TODO: <zcconst>
                 longname = concat_text_nodes(from_xpath("name/text()",
                                        messages[name],
                                        # Several text nodes can occur, yes
                                        only_one_item=False))
                 html_check_msg = body.appendChild(
                     html_result.createElement("p"))
                 html_check_msg.appendChild(html_result.createTextNode("%s" % \
                                                                       longname.strip().capitalize()))
                 body.appendChild(explanation_text(from_xpath("explanation",
                                                                        messages[name],
                                                                        only_one_item=True)))
             else:
                 raise Exception("Test %s not found in the message catalogs")
    PrettyPrint(html_result)          

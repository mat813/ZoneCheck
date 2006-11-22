#!/usr/bin/python
# -*- coding: ISO-8859-1 -*-

# TODO: recode in ElementTree, more Pythonesque than DOM!
from xml.dom.ext.reader import Sax2
from xml.dom.ext import PrettyPrint
from xml import xpath
from xml.dom import getDOMImplementation
import xml.dom
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
    return "Usage: %s [-p] [-l language] [-s CSS-stylesheet] zonecheck-profile" % myself

def fatal(message):
    sys.stderr.write("%s\n" % message)
    sys.exit(1)

def capitalize(thestring):
    """ Unlike string.capitalize(), we just touch the first letter, never the
        others. """
    if len(thestring) == 0:
        return ""
    elif len(thestring) == 1:
        return string.upper(thestring[0])
    else:
        return (string.upper(thestring[0]) + thestring[1:])
    
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
    att_node = node.attributes.getNamedItem(attname)
    if att_node is not None:
        return att_node.nodeValue
    else:
        return None

def explanation_text(node):
    reference = from_xpath("@sameas", node, required=False)
    if reference is not None:
        (category, ref) = string.split(reference[0].nodeValue, ":")
        details = explanations["%s:%s" % (category, ref)]
        srcs = from_xpath("src", details)
        message = ""
        for src in srcs:
            message = message + concat_text_nodes(from_xpath("title", src)) + \
                      " : " + \
                      concat_text_nodes(from_xpath("para", src))
            message = message + "\n"
    else:
        source = from_xpath("src", node, required=False, only_one_item=True)
        if source is not None:
            message = concat_text_nodes(from_xpath("title", source)) + ". " + \
                   concat_text_nodes(from_xpath("para", source))
        else:
            message = ""
    return mark_specials(message)

def mark_specials(message):
    """ Finds in a message (a paragraph) "special" text such as
    references to RFCs or URLs and turns them into nice hypertext."""
    result = html_result.createElement("p")
    nodes = mark_rfc(message)
    for node in nodes:
        if node.nodeType == xml.dom.Node.TEXT_NODE:
            new_nodes = mark_url(node.nodeValue)
            for new_node in new_nodes:
                result.appendChild(new_node)
        else:
            result.appendChild(node)
    return result

def mark_url(msg):
    """ Finds references to URLs and turn them into hypertext """
    # TODO: may be we whould rely on <uri> elements only but they are not always used.
    url_text = "((?:https?|ftp)://[A-Za-z0-9\.\-]+[^ ]*)"
    url_re = re.compile (url_text, re.IGNORECASE)
    chunks = re.split (url_re, msg)
    result = []
    for chunk in chunks:
        if url_re.match (chunk):
            link = html_result.createElement("a")
            url = html_result.createAttribute("href")
            url.nodeValue = chunk
            link.setAttributeNode(url)
            code = html_result.createElement("code")
            link.appendChild(code)
            code.appendChild(html_result.createTextNode(chunk))
            result.append(link)
        else:
            result.append(html_result.createTextNode(chunk))
    return result

def mark_rfc(msg):
    """ Finds references to IETF RFCs and turn them into hypertext """
    chunks = re.split ("RFC-? ?([0-9]+)",
                   msg)
    result = []
    for chunk in chunks:
        if re.match ("[0-9]+", chunk):
            link = html_result.createElement("a")
            url = html_result.createAttribute("href")
            url.nodeValue = "http://www.ietf.org/rfc/rfc%i.txt" % int(chunk)
            link.setAttributeNode(url)
            link.appendChild(html_result.createTextNode("RFC %i" % int(chunk)))
            result.append(link)
        else:
            result.append(html_result.createTextNode(chunk))
    return result

def concat_text_nodes(list):
    result = ""
    for node in list:
        if node.nodeType == xml.dom.Node.TEXT_NODE:
            result = result + " " + node.nodeValue
        elif node.nodeType == xml.dom.Node.ELEMENT_NODE:
            if node.nodeName == "uri":
                result = result + " " + node.childNodes[0].nodeValue # TODO: transform in
                # <a> instead, it is quite stupid to produce text from XML elements, to
                # turn them in XML <a> afterwards, by a regexp!
            elif node.nodeName == "zcconst":
                constant_name = from_xpath("@name", node, only_one_item=True).nodeValue,
                constant = from_xpath("//const[@name=\"%s\"]" % constant_name,
                                   profile.documentElement, only_one_item=True)
                value = attribute(constant, "value")
                display = from_xpath("@display", node, only_one_item=True, required=False)
                if display is not None:
                    if display.nodeValue == "duration":
                        const_value = value + " s"
                else:
                    const_value = value
                result = result + const_value
            else:
                result = result + concat_text_nodes(node.childNodes)
    return result

if __name__ == '__main__':
    try:
        # Default values
        partial = False
        optlist, args = getopt.getopt (sys.argv[1:], "hl:s:p",
                                       ["help", "version", "partial-html",
                                        "lang=",
                                        "stylesheet="])
        for option, value in optlist:
            if option == "--help" or option == "-h":
                print (usage())
                sys.exit(0)
            elif option == "--version":
                print sys.argv[0] + " (CVS $Revision$)\n" + " Python " + sys.version
                sys.exit(0)
            elif option == "--partial-html" or option == "-p":
                partial = True
            elif option == "--lang" or option == "-l": LANG = value
            elif option == "--stylesheet" or option == "-s": stylesheet = value
            else: fatal ("Unknown option " + option)
    except getopt.error, reason:
        fatal (usage() + "\n%s" % reason)
    if len(args) < 1 or len(args) > 1:
        fatal (usage())
    profilename = args[0]
    (messages, explanations) = all_check_messages("%s/AFNIC/zonecheck/locale/test" % \
                                  os.environ['HOME'], LANG)
    profile = file2DOM(profilename)
    profilenode = from_xpath("/config/profile", profile, only_one_item=True)
    if not partial:
        html_result = getDOMImplementation().createDocument(
            None,
            "html",
            getDOMImplementation().createDocumentType(
            "html",
            "-//W3C//DTD XHTML 1.0 Strict//EN",
            "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"))
        head = html_result.documentElement.appendChild(html_result.createElement('head'))
        body = html_result.documentElement.appendChild(html_result.createElement('body'))
        if LANG == "en":
            blurb = "Tests made by Zonecheck at"
        elif LANG == "fr":
            blurb = u"Tests effectués par Zonecheck à"
        else:
            blurb = ""
        title = head.appendChild(html_result.createElement('title'))
        title.appendChild(html_result.createTextNode("%s %s (%s)" % \
                                                     (blurb,
                                                      string.upper(attribute
                                                                   (profilenode,
                                                                    'name')),
                                                      attribute (profilenode,
                                                                 'longdesc'))))
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
                                                   string.upper(attribute (profilenode, 'name')),
                                                   attribute (profilenode,
                                                              'longdesc'))))
    else: # Partial HTML
        html_result = getDOMImplementation().createDocument(
            None,
            "div",
            None)
        body = html_result.documentElement
    rulenodes = from_xpath("rules", profilenode)
    for rule in rulenodes:
         body.appendChild(html_result.createElement("hr"))
         html_rule = body.appendChild(html_result.createElement("h2"))
         anchor = html_rule.appendChild(html_result.createElement("a"))
         anchor_name = html_result.createAttribute("name")
         anchor_name.nodeValue = attribute(rule, 'class')
         anchor.setAttributeNode(anchor_name)
         if LANG == "en":
             blurb = "Tests of class "
         elif LANG == "fr":
             blurb = u"Tests de la classe "
         else:
             blurb = ""
         html_rule.appendChild(html_result.createTextNode("%s \"%s\"" % (blurb,
                                                                     attribute(rule, 'class'))))
         checknodes = from_xpath("descendant::check", rule)
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
             anchor = html_check.appendChild(html_result.createElement("a"))
             anchor_name = html_result.createAttribute("name")
             anchor_name.nodeValue = name
             anchor.setAttributeNode(anchor_name)             
             if LANG == "en":
                 blurb = "Test "
             elif LANG == "fr":
                 blurb = u"Test "
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
                 longname = concat_text_nodes([from_xpath("name",
                                        messages[name],
                                        only_one_item=True)])
                 html_check_msg = body.appendChild(
                     html_result.createElement("p"))
                 html_check_msg.appendChild(html_result.createTextNode("%s" % \
                                                                       capitalize(longname.strip())))
                 body.appendChild(explanation_text(from_xpath("explanation",
                                                                        messages[name],
                                                                        only_one_item=True)))
             else:
                 raise Exception("Test %s not found in the message catalogs")
    PrettyPrint(html_result) # TODO: disable the XML declaration if --partial          

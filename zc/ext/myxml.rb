# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2003/12/15 10:58:17
# REVISION    : $Revision$ 
# DATE        : $Date$
#
# CONTRIBUTORS: (see also CREDITS file)
#
#
# LICENSE     : GPL v2 (or MIT/X11-like after agreement)
# COPYRIGHT   : AFNIC (c) 2003
#
# This file is part of ZoneCheck.
#
# ZoneCheck is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# ZoneCheck is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ZoneCheck; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#


# XML_CATALOG_FILES=~/Repository/zonecheck/zc/data/catalog.xml


# type 
#  - string => xpath (but only yield elements)
#  - false  => elements
#  - true   => nodes


module MyXML
    Implementation = (Proc::new {
			  if $zc_xml_parser
			      $zc_xml_parser.intern
			  else
			      begin
				  require 'xml/libxml'
				  :libxml
			      rescue LoadError
				  :rexml
			      end
			  end
		      }).call

    class Node
	class Element < Node ; end
	class Text    < Node ; end
	class Comment < Node ; end

	def child(type=false, idx=1)
	    each(type) { |node| 
		return node if (idx -= 1) <= 0 }
	    return nil
	end

	def to_a(type=false)
	    res = []
	    each(type) { |node| res << node }
	    res
	end
    end
end


case MyXML::Implementation
when :libxml

#-- BEGIN: libxml specific --------------------------------------------
# Define XML_CATALOG_FILES to point to our catalog
ENV['XML_CATALOG_FILES'] = ((ENV['XML_CATALOG_FILES'] || '').split(/:/, -1) \
			    << "#{ZC_DIR}/data/catalog.xml").uniq.join(':')
$dbg.msg(DBG::INIT, "Using XML_CATALOG_FILES=#{ENV['XML_CATALOG_FILES']}")


require 'xml/libxml'

module MyXML
    class Document
	def initialize(doc)
	    @parser = XML::Parser::new
	    case doc
	    when String	then @parser.filename	= doc
	    when IO	then @parser.io		= doc
	    else raise ArgumentError, "String or IO expected"
	    end
	    @doc = @parser.parse
	end

	def root		; Node::create(@doc.root)	; end
    end

    class Node
	class Element < Node
	    def name		; @node.name			; end
	    def [](attr)	; @node[attr]			; end
	end

	def self.create(node)
	    klass = case node.node_type
		    when XML::Tree::ELEMENT_NODE	then Element
		    when XML::Tree::TEXT_NODE		then Text
		    when XML::Tree::COMMENT_NODE	then Comment
		    else				     Node
		    end
	    klass::new(node)
	end

	def initialize(node)	; @node = node			; end

	def value		; @node.content			; end
	def text		; @node.to_s			; end

	def parent		; Node::create(@node.parent)	; end

	def empty?(type=:element)
	    case type
	    when String
		@node.find(type).each { return false } ; return true
	    when :element
		node = @node.child
		while ! node.nil?
		    return true if node.node_type == XML::Tree::ELEMENT_NODE
		    node = node.next
		end
		false
	    when :child
		@node.child?
	    end
	end


	def each(type=:element)
	    case type
	    when String
		@node.find(type).each { |node|
		    if node.node_type == XML::Tree::ELEMENT_NODE
			yield Node::create(node) 
		    end
		}
	    when :element
		node = @node.child
		while ! node.nil?
		    if node.node_type == XML::Tree::ELEMENT_NODE
			yield Node::create(node) 
		    end
		    node = node.next
		end
	    when :child
		node = @node.child
		while ! node.nil?
		    yield Node::create(node) 
		    node = node.next
		end		
	    end
	end
    end
end
#-- END: libxml specific ----------------------------------------------


when :rexml

#-- BEGIN: REXML specific ---------------------------------------------
require 'rexml/document'

module MyXML
    class Document
	def initialize(doc)	; @doc=REXML::Document::new(doc); end
	def root		; Node::create(@doc.root)	; end
    end

    class Node
	class Element < Node
	    def name		; @node.name			; end
	    def [](attr)	; @node.attributes[attr]	; end
	end

	def self.create(node)
	    klass = case node
		    when REXML::Element		then Element
		    when REXML::Text		then Text
		    when REXML::Comment		then Comment
		    else			     Node
		    end
	    klass::new(node)
	end

	def initialize(node)	; @node = node			; end

	def value		; @node.value			; end
	def text		; @node.text			; end

	def parent		; Node::create(@node.parent)	; end

	def empty?(type=:element)
	    case type
	    when String
		@node.elements.each(type) { return false } ; return true
	    when :element
		! @node.elements.empty?
	    when :child
		! @node.empty?
	    end
	end

	def each(type=:element)
	    case type
	    when String
		@node.elements.each(type) { |node| yield Node::create(node) }
	    when :element
		@node.elements.each       { |node| yield Node::create(node) }
	    when :child
		@node.each_child          { |node| yield Node::create(node) }
	    end
	end
    end
end
#-- END: REXML specific -----------------------------------------------

else
    raise "Unsupported XML parser (#{MyXML::Implementation})"
end


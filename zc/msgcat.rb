# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2002/08/02 13:58:17
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

require 'ext/myxml'
require 'dbg'


##
## Message catalog for I18N/L10N
##
##
## WARN: this file is not localized
##
## BUGFIX:
##  - method readfile: inode is always 0 on Windows
##      we replace the inode number by the filename if the inode is 0
##

# BUG: @lang / @language / @country?
class MsgCat
    TAG		= 'tag'
    CHECK	= 'check'
    TEST	= 'test'

    NAME	= 'name'
    FAILURE	= 'failure'
    SUCCESS	= 'success'
    EXPLANATION	= 'explanation'
    DETAILS	= 'details'


    ##
    ## Exception: the corresponding message catalog is not installed
    ##
    class NoCatalogFound < StandardError
    end


    ##
    ## Exception: Syntax error, while parsing the file
    ##
    class SyntaxError < StandardError
    end


    ##
    ## Exception: no message for the 'tag'
    ##
    class EntryNotFound < StandardError
    end


    #
    # Initializer
    #
    def initialize(directory, dfltlang)
	$dbg.msg(DBG::LOCALE) { 'creating message catalogue' }
	$dbg.msg(DBG::LOCALE) {"fallback for language is set to '#{dfltlang}'"}
	@dfltlang	= dfltlang
	@directory	= directory
	@loaded		= {}
	@catfiles	= []
	@language	= nil
	@country	= nil
	clear
    end
    
    attr_writer :language, :country


    def clear
	@tag		= {}
	@check		= {}
	@test		= {}
	@shortcut	= { EXPLANATION => {}, DETAILS => {} }
    end

    #
    # Test if a file catalog is available
    #
    def available?(where)
        filepath(where).each { |fp| return true if File::readable?(fp) }
        false
    end



    #
    # Read catalog (from the template filename)
    #  (the occurence of %s is replaced by the language name)
    #
    def read(where)
        filepath(where).each { |fp|
	    if File::readable?(fp)
                res = readfile(fp)
		@catfiles << where unless res.nil?
                return res
            end
	}
        raise NoCatalogFound, "No valid catalog found for #{@lang}"
    end
	

    #
    # Get message associated with the 'tag'
    #
    def get(tag, type=TAG, subtype=nil)
	$dbg.msg(DBG::LOCALE) { 
	    category = type != TAG ? " (#{type}/#{subtype})" : ''
	    "requesting locale for: #{tag}#{category}"
	}
	sameas = nil
	begin
	    case type
	    when TAG
		@tag.fetch(tag)
	    when CHECK
		res = @check.fetch(tag)[subtype]
		if res && (sameas = res['sameas'])
		    res = case sameas
			  when /^shortcut:(.*)$/
			      @shortcut.fetch(subtype).fetch($1)
			  else
			      @check.fetch(sameas).fetch(subtype)
			  end
		end
		res
	    when TEST
		@test.fetch(tag)[subtype]
	    end
	rescue IndexError
	    category = type != TAG ? " (#{type}/#{subtype})" : ''
	    xcp = if sameas.nil?
		"Entity '#{tag}'#{category} has not been defined/localized"
		  else
	        "Entity '#{tag}'#{category} doesn't have a link to '#{sameas}'"
		  end
	    raise EntryNotFound, xcp
	end
    end



    #
    # Reload the message catalogs
    #  (allowing to take into account a new locale)
    #
    def reload
	$dbg.msg(DBG::LOCALE, 'reloading message catalogue')
	clear
	@loaded		= {}
	@catfiles.each { |where| 
 	    catch(:loaded) {
		filepath(where).each { |fp|
		    if File::readable?(fp)
			readfile(fp) ; throw :loaded
		    end
		}
		raise NoCatalogFound, "No valid catalog found for #{@lang}"
	    }
        }
    end

    ## PRIVATE ##
    private

    #
    # Establish the possible filepaths from the template file
    #  - %s is replace by lang
    #  - if not fullpath the default directory is prepend
    # 
    # WARN: An array is returned has for exemple we could need to
    #       test for fr_CA and next fr
    #
    def filepath(where)
	where = "#{@directory}/#{where}"  unless where[0] == ?/

	fp = []
	if @language
	    fp << "#{@language}_#{@country}" if @country
	    fp << @language
	end
	fp << @dfltlang
	fp.collect { |x| where % x }
    end


    #
    # Read catalog file
    #  (return false if the file was already loaded, true otherwise)
    #
    def readfile(msgfile)
	# Check for already loaded catalog
	file_stat = File::stat(msgfile)
	file_id   = [ file_stat.dev, file_stat.ino != 0 ? file_stat.ino \
	                                                : msgfile ]
	if @loaded.has_key?(file_id)
	    $dbg.msg(DBG::LOCALE) { "file already loaded: #{msgfile}" }
	    return false
	end


	# Read message catalogue
	$dbg.msg(DBG::LOCALE, "reading file: #{msgfile}")

	prefix   = nil
	lineno   = 0

	File::open(msgfile) { |io|
	    doc = MyXML::Document::new(io)
	    root = doc.root

	    # Tag
	    root.each('//tag')  { |element| 
		# create prefix from parent sections
		prefix = ''
		xmlsection = element.parent
		while xmlsection.name == 'section'
		    prefix = xmlsection['name'] + ':' + prefix
		    xmlsection = xmlsection.parent
		end

		name = prefix + element['name']
		$dbg.msg(DBG::LOCALE) { "locale tag: #{name}" }
		@tag[name] = element.text
	    }

	    # Shortcut
	    root.each('shortcut')  { |shortcut|
		shortcut.each { |element|
		    name	= element['name']
		    @shortcut[element.name][name] = element
		}
	    }

	    # Check
	    root.each("check")  { |element|
		checkname	= element['name']
		name		= element.child(NAME)
		success		= element.child(SUCCESS)
		failure		= element.child(FAILURE)
		explanation	= element.child(EXPLANATION)
		details		= element.child(DETAILS)

		if explanation['sameas'].nil?
		    explanation = nil unless explanation.empty?
		end
		
		if details['sameas'].nil?
		    details     = nil unless details.empty?
		end

		@check[checkname] = {
		    NAME	=> name,
		    SUCCESS	=> success,	FAILURE	=> failure,
		    EXPLANATION => explanation,	DETAILS	=> details }
	    }

	    # Test
	    root.each('test')  { |element|
		testname	= element['name']
		name		= element.child(NAME)

		@test[testname] = {
		    NAME	=> name }
	    }
	}
	# Consider the file loaded
	@loaded[file_id] = true

	return true
    end
end


#
# Include the 'with_msgcat' facility in every objects
#
def with_msgcat(*msgcat_list)
    return unless $mc && $mc.kind_of?(MsgCat)
    msgcat_list.each { |msgcat| $mc.read(msgcat) }
end

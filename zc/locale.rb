# $Id$

# 
# CONTACT     : zonecheck@nic.fr
# AUTHOR      : Stephane D'Alu <sdalu@nic.fr>
#
# CREATED     : 2003/08/29 14:10:22
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

class Locale
    LANGRegex	= /^(\w+?)(?:_(\w+))?(?:\.([\w\-]+))?$/

    #
    # Normalize lang
    #  (and raise exception is the parameter is suspicious)
    #  The settings are based on: LanguageCode_CountryCode.Encoding
    #
    def self.normlang(lng)
	unless lng =~ LANGRegex
	    raise ArgumentError, "Suspicious language selection: #{lng}"
	end
	lang  =       $1.downcase
        lang += '_' + $2.upcase   if $2
        lang += '.' + $3.downcase if $3
        lang.untaint
    end

    #
    # Split lang between Language, Country, Encoding
    #
    def self.splitlang(lng)
	unless lng =~ LANGRegex
	    raise ArgumentError, "Suspicious language selection: #{lng}"
	end
        [ $1, $2, $3 ]
    end


    #
    # Initializer
    #
    def initialize
	@actions	= {}

	@lang		= nil
        @language	= nil
        @country	= nil
        @encoding	= nil

	self.lang = ENV['LANG'] if ENV['LANG']
    end

    attr_reader :lang, :language, :country, :encoding

    def lang=(lng)
	ln, ct, en = Locale::splitlang(Locale::normlang(lng))
	evlist = []
	evlist << 'lang'	if (@language != ln) || (@country != ct)
	evlist << 'encoding'	if (@encoding != en)
	@lang, @language, @country, @encoding = lng, ln, ct, en
	$dbg.msg(DBG::LOCALE) { "locale set to #{lng}" }
	notify(*evlist)
    end

    def watch(event, action)
	(@actions[event] ||= []) << action
    end

    def notify(*event)
	event.each { |ev|
	    @actions[ev].each { |a| a.call } if @actions.has_key?(ev) }
    end
end

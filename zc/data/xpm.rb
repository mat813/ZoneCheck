# $Id$

# 
# AUTHOR : Stephane D'Alu <sdalu@nic.fr>
# CREATED: 2002/08/02 13:58:17
#
# COPYRIGHT: AFNIC (c) 2003
# CONTACT  : zonecheck@nic.fr
# LICENSE  : GPL v2.0
#
# $Revision$ 
# $Date$
#
# CONTRIBUTORS:
#   - All graphics (except Book_* and Minipage) are from:
#      David Barou <david.barou@nic.fr>
#   - Book_open, Book_closed and Minipage are from ruby-gtk
#
    

module ZCData
    module XPM
	Book_open = [
	    "16 16 4 1",
	    "  c None s None", ". c black", "X c #808080", "o c white",

	    "                ",
	    "  ..            ",
	    " .Xo.    ...    ",
	    " .Xoo. ..oo.    ",
	    " .Xooo.Xooo...  ",
	    " .Xooo.oooo.X.  ",
	    " .Xooo.Xooo.X.  ",
	    " .Xooo.oooo.X.  ",
	    " .Xooo.Xooo.X.  ",
	    " .Xooo.oooo.X.  ",
	    "  .Xoo.Xoo..X.  ",
	    "   .Xo.o..ooX.  ",
	    "    .X..XXXXX.  ",
	    "    ..X.......  ",
	    "     ..         ",
	    "                "
	]

	Book_closed = [
	    "16 16 6 1",
	    "  c None s None", ". c black", "X c red", "o c yellow",
	    "O c #808080", "# c white",

	    "                ",
	    "       ..       ",
	    "     ..XX.      ",
	    "   ..XXXXX.     ",
	    " ..XXXXXXXX.    ",
	    ".ooXXXXXXXXX.   ",
	    "..ooXXXXXXXXX.  ",
	    ".X.ooXXXXXXXXX. ",
	    ".XX.ooXXXXXX..  ",
	    " .XX.ooXXX..#O  ",
	    "  .XX.oo..##OO. ",
	    "   .XX..##OO..  ",
	    "    .X.#OO..    ",
	    "     ..O..      ",
	    "      ..        ",
	    "                " 
	]

	Minipage = [
	    "16 16 4 1",
	    "  c None s None", ". c black", "X c white", "o c #808080",

	    "                ",
	    "   .......      ",
	    "   .XXXXX..     ",
	    "   .XoooX.X.    ",
	    "   .XXXXX....   ",
	    "   .XooooXoo.o  ",
	    "   .XXXXXXXX.o  ",
	    "   .XooooooX.o  ",
	    "   .XXXXXXXX.o  ",
	    "   .XooooooX.o  ",
	    "   .XXXXXXXX.o  ",
	    "   .XooooooX.o  ",
	    "   .XXXXXXXX.o  ",
	    "   ..........o  ",
	    "    oooooooooo  ",
	    "                " 
	]

	Info = [
	    "16 16 50 1",
	    "  c #7C5719", ". c #504F4C", "X c #545250", "o c #5A5956",
	    "O c gray40",  "+ c #73716E", "@ c #777571", "# c #797774",
	    "$ c #0066B2", "% c #835C1A", "& c #8D631C", "* c #91661D",
	    "= c #9B6D1F", "- c #A27120", "; c #B47E24", ": c #84827E",
	    "> c #C78B27", ", c #D4952A", "< c #DF9E31", "1 c #E5A539",
	    "2 c #EDAE44", "3 c #F5B64C", "4 c #F5BA56", "5 c #F8BD5C",
	    "6 c #F9C46B", "7 c #FACB7B", "8 c #908E89", "9 c #96938F",
	    "0 c #ADAAA5", "q c #B3B0AB", "w c #B8B5B0", "e c #BCB9B4",
	    "r c #C7C3BE", "t c #FACD83", "y c #FAD18B", "u c #FBD494",
	    "i c #CBC8C2", "p c #D3CFC9", "a c #D4D0CA", "s c #DEDAD5",
	    "d c #E0DCD6", "f c #E7E4DE", "g c #EBE7E1", "h c #EEEAE4",
	    "j c #F1EEE7", "k c #F4F2ED", "l c #F6F4F0", "z c #F9F8F5",
	    "x c gray100", "c c None",

	    "cccccccccccccccc",
	    "cccccty7642ccccc",
	    "ccccuzzllhd1cccc",
	    "cccuzz$$hhdp<ccc",
	    "ccuzzj$$hhhpr,cc",
	    "ctzzjhhhhhhgie,c",
	    "cyzj$$$$hhhhgq>c",
	    "c7lhhh$$hhhhh0;c",
	    "c6khhh$$hhhhh9-c",
	    "c5jhhh$$hhhhd+*c",
	    "c3gfhh$$hhhs:O=c",
	    "cc2s$$$$$$s#o&cc",
	    "ccc1aaghhs@.%ccc",
	    "cccc<rw08OX cccc",
	    "ccccc,>;=%&ccccc",
	    "cccccccccccccccc"
	]

	Warning = [
	    "16 16 64 1",
	    "  c black",   ". c #003156", "X c #00345B", "o c #00365E",
	    "O c #003E6C", "+ c #004274", "@ c #00497F", "# c #664714",
	    "$ c #795518", "% c #7F5919", "& c #004B83", "* c #00508C",
	    "= c #0C5185", "- c #085C9B", "; c #1A659D", ": c #2E73A6",
	    "> c #2C79B2", ", c #3883BB", "< c #468DC2", "1 c #4A94C5",
	    "2 c #5292C2", "3 c #6699CC", "4 c #77ADD6", "5 c #7FB2D8",
	    "6 c #835C1A", "7 c #8A601B", "8 c #91661D", "9 c #A07429",
	    "0 c #AC7922", "q c #B57B21", "w c #B7822A", "e c #BE882D",
	    "r c #B3883F", "t c #C18726", "y c #C68A27", "u c #E8A22E",
	    "i c #EFA82F", "p c #F1AA32", "a c #F7AD31", "s c #F4B03F",
	    "d c #CCA25C", "f c #D8A248", "g c #D9AD64", "h c #F8B442",
	    "j c #E8BD74", "k c #85B5D9", "l c #84B5DA", "z c #91BDDE",
	    "x c #A5C9E4", "c c #ABCDE6", "v c #B3D1E8", "b c #EAC485",
	    "n c #FBD594", "m c #FBD89C", "M c #F5D6A4", "N c #F9DEB1",
	    "B c #F8E1BA", "V c #FDE7C3", "C c #FDEACA", "Z c #FDECCF",
	    "A c #FEF0D9", "S c #FEF2DE", "D c gray100", "F c None",

	    "FFFFFFF1FFFFFFFF",
	    "FFFFFFF5<FFFFFFF",
	    "FFFFFFlN2FFFFFFF",
	    "FFFFFFvBj>FFFFFF",
	    "FFFFFzSng;FFFFFF",
	    "FFFFFvA fe-FFFFF",
	    "FFFFlZm pw*FFFFF",
	    "FFFFcZh ay0*FFFF",
	    "FFFlZma ai0&FFFF",
	    "FFFcZha aay0*FFF",
	    "FF5Zmaa aai0&FFF",
	    "FFxChaaaaaayq*FF",
	    "F4Vnaaa aaait0*F",
	    "FlMsaaaaaaaau7+F",
	    "3bdr9876666$##%@",
	    ",:=+OOoooooo..X+"
	]

	Fatal = [
	    "16 16 86 1",
	    "  c #002846", ". c #003054", "X c #00355C", "o c #003A65",
	    "O c #003E6D", "+ c #004274", "@ c #004679", "# c #513910",
	    "$ c #604313", "% c #694915", "& c #765317", "* c #7A5518",
	    "= c #624920", "- c #004B83", "; c #00508B", ": c #005594",
	    "> c #005899", ", c #0066B2", "< c #1169AA", "1 c #146EB2",
	    "2 c #1271B7", "3 c #1B73B5", "4 c #287BB9", "5 c #2B7EBC",
	    "6 c #2B80BF", "7 c #3A88C3", "8 c #3F8BC4", "9 c #4C94C9",
	    "0 c #5196CA", "q c #5C9DCE", "w c #66A3D1", "e c #6BA6D2",
	    "r c #73ABD5", "t c #865E1B", "y c #8A601B", "u c #96691E",
	    "i c #A07020", "p c #A17120", "a c #AA7722", "s c #B37E24",
	    "d c #BF8626", "f c #B98632", "g c #C98D29", "h c #CC8F29",
	    "j c #D1932A", "k c #D4952B", "l c #DE9B2C", "z c #D79A33",
	    "x c #D69A36", "c c #DA9E38", "v c #E8A22E", "b c #ECA630",
	    "n c #F0AB37", "m c #F7AD31", "M c #E1A642", "N c #EAB355",
	    "B c #EDB250", "V c #F2B95A", "C c #F8BB54", "Z c #F1BC62",
	    "A c #F7BE60", "S c #F8C56E", "D c #F7C573", "F c #85B6DA",
	    "G c #8DBBDD", "H c #92BEDE", "J c #9EC5E2", "K c #A1C7E3",
	    "L c #A7CBE5", "P c #B9D5EA", "I c #BCD7EB", "U c #F9CE85",
	    "Y c #FAD089", "T c #FBD492", "R c #FCDCA8", "E c #FCDFAD",
	    "W c #FCE1B3", "Q c #C4DCED", "! c #D5E6F2", "~ c #FDE7C2",
	    "^ c #E0ECF6", "/ c #EFF5FA", "( c #F1F1F0", ") c #F3F8FB",
	    "_ c gray100","` c None",

	    "`````qwq9753````",
	    "````rWRTUSVN<```",
	    "```HWWRYDABMc>``",
	    "``J~~WCmmmncjh>`",
	    "`wRETC,,m,,bgdd:",
	    "`0TUmm,,m,,mlaa-",
	    "`8DZnmmmmmmmhuu@",
	    "`4NMxkvmmmjy$$&O",
	    "`1<zhddlli%##=.@",
	    "!``>>;siy&$ .o``",
	    "q````:fit*X(```Q",
	    ",8F!``:-++`)QHq6",
	    "`PF76qJ!^Kr80GI/",
	    ")```!e7226r!````",
	    "9GF76qJ!^Kr80GLK",
	    ",8F!```````)QH00"
	]

	Element = [
	    "16 16 65 1",
	    " 	c None",
	    ".	c #003B67", "+	c #FFFFFF", "@	c #CB8E28", "#	c #9E6F20",
	    "$	c #2075B4", "%	c #86B6DA", "&	c #F9C46A", "*	c #5296CA",
	    "=	c #01518C", "-	c #B17C23", ";	c #E1A94D", ">	c #8A6F43",
	    ",	c #FBD596", "'	c #F7AD31", ")	c #0C609F", "!	c #65A3D0",
	    "~	c #4C94C9", "{	c #856227", "]	c #DD9D31", "^	c #FACB7B",
	    "/	c #00477C", "(	c #BC8427", "_	c #9D8254", ":	c #AD7922",
	    "<	c #72AAD4", "[	c #EEB555", "}	c #015797", "|	c #F7D295",
	    "1	c #136BAD", "2	c #2A7FBE", "3	c #EDA62F", "4	c #5A9CCD",
	    "5	c #F5C77A", "6	c #004476", "7	c #004B83", "8	c #FCDCA6",
	    "9	c #C58B28", "0	c #05538E", "a	c #E9A42E", "b	c #EDB85F",
	    "c	c #A47320", "d	c #F7B13C", "e	c #6EA8D3", "f	c #3381BC",
	    "g	c #FAC772", "h	c #DDA13B", "i	c #054879", "j	c #529CCE",
	    "k	c #6AA5D0", "l	c #055693", "m	c #FACE84", "n	c #00426B",
	    "o	c #CE9429", "p	c #9F7022", "q	c #84B5DE", "r	c #B88125",
	    "s	c #075FA1", "t	c #BD8C29", "u	c #7BB0D7", "v	c #025B9E",
	    "w	c #156DAF", "x	c #6699CC", "y	c #004578", "z	c #C88F30",

	    "                ",
	    "         2      ",
	    "         ~f     ",
	    "         k5$    ",
	    "         %|b1   ",
	    "4u<!4~~4k%^[hs  ",
	    "e8,m^&gg^&dd]@} ",
	    "*5''''''''''39(v",
	    "f;zr:cc:-@33:#7 ",
	    "w)=7/66//79c{y  ",
	    "         =p>n   ",
	    "         0_.    ",
	    "         0i     ",
	    "         l      ",
	    "                ",
	    "                "
	]


	Zone = [
	    "16 16 67 1",
	    "  c #004272", ". c #00477C", "X c #004C84", "o c #00508C",
	    "O c #005493", "+ c #00599C", "@ c #0361A6", "# c #0063AC",
	    "$ c #0763A8", "% c #0063B5", "& c #0868B0", "* c #0A6CB4",
	    "= c #0D6DB5", "- c #126AAC", "; c #196BB5", ": c #1973B6",
	    "> c #2078BA", ", c #287DBD", "< c #3183C1", "1 c #3586C2",
	    "2 c #3988C3", "3 c #418DC6", "4 c #4F95CA", "5 c #5A9CCD",
	    "6 c #6EA8D3", "7 c #71AAD4", "8 c #79AFD7", "9 c #835C1A",
	    "0 c #8D631C", "q c #93671D", "w c #9C6D1F", "e c #A07020",
	    "r c #A37220", "t c #A97621", "y c #AD7922", "u c #B47E24",
	    "i c #B88125", "p c #BA8225", "a c #C08626", "s c #C68A27",
	    "d c #CC8F29", "f c #CE912A", "g c #D2932A", "h c #D9992E",
	    "j c #DF9C2D", "k c #DC9C31", "l c #E6A230", "z c #E6A537",
	    "x c #EBA530", "c c #EFAA35", "v c #F6AD32", "b c #F1AD3C",
	    "n c #F6B03B", "m c #F1B043", "M c #F7B444", "N c #F1B349",
	    "B c #F8B749", "V c #F8BA51", "C c #F9BD5A", "Z c #F9C164",
	    "A c #F9C265", "S c #F9C46B", "D c #F9C671", "F c #FACB7B",
	    "G c #FACF87", "H c gray100", "J c None",

	    "JJJJJJJJJJJJJJJJ",
	    "JJJJJZ31,NbJJJJJ",
	    "JJJJDFDACNzzJJJJ",
	    "JJJ5GFA<VmzhhJJJ",
	    "JJF8GDCBMb$+OgJJ",
	    "J487FAV:=&@+OaOJ",
	    "J56FSCM*v##+OXXJ",
	    "J4FSCBnv%##+o.XJ",
	    "J3DAVMv%%#+dXr.J",
	    "J23CBnn##+dptq J",
	    "J,2,:bcx+due00tJ",
	    "JJ>:;zljOpe09wJJ",
	    "JJJ;-zhfatq9wJJJ",
	    "JJJJ$kfayw0 JJJJ",
	    "JJJJJjgsptyJJJJJ",
	    "JJJJJJJJJJJJJJJJ"
	]

	Primary = [
	    "16 16 36 1",
	    "  c #573D11", ". c #745117", "X c #0066B2", "o c #835C1A",
	    "O c #8C621C", "+ c #93671D", "@ c #976A1E", "# c #9A6C1F",
	    "$ c #9E6F1F", "% c #A57321", "& c #AE7A23", "* c #BD8425",
	    "= c #BE8526", "- c #C28826", "; c #CB8F2A", ": c #CD902A",
	    "> c #DB9C33", ", c #EAA83A", "< c #EBA93B", "1 c #F7AD31",
	    "2 c #E1A541", "3 c #EBAD44", "4 c #EDAF47", "5 c #EFB34D",
	    "6 c #F4B750", "7 c #F7BC58", "8 c #F9C061", "9 c #F9C46C",
	    "0 c #FAC978", "q c #FACF86", "w c #FAD08A", "e c #FBD698",
	    "r c #FBD89D", "t c #FCE1B3", "y c gray100",   "u c None",

	    "uuuuuuuuuuuuuuuu",
	    "uuuuuuuuuuuuuuuu",
	    "uuqeeq0998864<uu",
	    "uuetrwXX98752>uu",
	    "uuwrXXXX1111::uu",
	    "uuqq11XX1111--uu",
	    "uu0011XX1111&&uu",
	    "uu9911XX1111%%uu",
	    "uu9911XX1111$$uu",
	    "uu9911XX1111$$uu",
	    "uu8811XX1111##uu",
	    "uu77XXXXXX11OOuu",
	    "uu6511111111.ouu",
	    "uu32:*&%$@O. .uu",
	    "uu<>;*&%$@Oo.+uu",
	    "uuuuuuuuuuuuuuuu"
	]

	Secondary = [
	    "16 16 36 1",
	    "  c #573D11", ". c #745117", "X c #0066B2", "o c #835C1A",
	    "O c #8C621C", "+ c #93671D", "@ c #976A1E", "# c #9A6C1F",
	    "$ c #9E6F1F", "% c #A57321", "& c #AE7A23", "* c #BD8425",
	    "= c #BE8526", "- c #C28826", "; c #CB8F2A", ": c #CD902A",
	    "> c #DB9C33", ", c #EAA83A", "< c #EBA93B", "1 c #F7AD31",
	    "2 c #E1A541", "3 c #EBAD44", "4 c #EDAF47", "5 c #EFB34D",
	    "6 c #F4B750", "7 c #F7BC58", "8 c #F9C061", "9 c #F9C46C",
	    "0 c #FAC978", "q c #FACF86", "w c #FAD08A", "e c #FBD698",
	    "r c #FBD89D", "t c #FCE1B3", "y c gray100", "u c None",

	    "uuuuuuuuuuuuuuuu",
	    "uuuuuuuuuuuuuuuu",
	    "uuqeeq0998864<uu",
	    "uuetrXXXX8752>uu",
	    "uuwrXX11XX11::uu",
	    "uuqq1111XX11--uu",
	    "uu001111XX11&&uu",
	    "uu99111XX111%%uu",
	    "uu9911XX1111$$uu",
	    "uu991XX11111$$uu",
	    "uu88XX111111##uu",
	    "uu77XXXXXX11OOuu",
	    "uu6511111111.ouu",
	    "uu32:*&%$@O. .uu",
	    "uu<>;*&%$@Oo.+uu",
	    "uuuuuuuuuuuuuuuu"
	]


	Reference = [
	    "16 16 10 1",
	    "  c #0066B2", ". c #ABBEC4", "X c #E6DECD", "o c #EBE5D7",
	    "O c #EEE9DE", "+ c #F0ECE5", "@ c #F6F3EF", "# c #F7F4F0",
	    "$ c gray100", "% c None",

	    "%%%    %%%%%%%%%",
	    "%%% @@ %%%%%%%%%",
	    "%%  ++  %%%%%%%%",
	    "%  +++@ %%%%%%%%",
	    "% #++++  %%%%%%%",
	    "  +++++@        ",
	    " #+++++  XXXXXO ",
	    "  +++++ .XXXXX  ",
	    "%  +++  XXXXXX  ",
	    "%  o++ .XXXXXX  ",
	    "%   +  XXXXXX   ",
	    "%%    .XXXXXX  %",
	    "%%%        XX  %",
	    "%%%%% XXXX     %",
	    "%%%%%%    OoX %%",
	    "%%%%%%%%%%    %%"
	]

	Detail = [
	    "16 16 46 1",
	    "  c None",    ". c #DBD7D1", "+ c #94928E", "@ c #9F6F20",
	    "# c #E4E1DC", "$ c #F9BF5D", "% c #C2C0BB", "& c #ABA8A3",
	    "* c #868380", "= c #999999", "- c #375395", "; c #C78B27",
	    "> c #FCDFB0", ", c #EEEAE4", "' c #000000", ") c #FACF86",
	    "! c #28458A", "~ c #47609D", "{ c #B37E24", "] c #F5F3EE",
	    "^ c #F9C368", "/ c #BCBAB5", "( c #2E4C93", "_ c #DFDCD5",
	    ": c #2C4784", "< c #AA7722", "[ c #B5B2AC", "} c #3B5799",
	    "| c #CDC9C3", "1 c #D5D1CB", "2 c #F0EDE6", "3 c #E6E3DD",
	    "4 c #2A488C", "5 c #000000", "6 c #4B65A4", "7 c #000000",
	    "8 c #2F4984", "9 c #F2EFEB", "0 c #E3DFD9", "a c #F9C671",
	    "b c #C6C3BD", "c c #D6D3CD", "d c #000000", "e c #345195",
	    "f c #445E9D", "g c #26417F",

	    "                ",
	    "    !!!!        ",
	    "  44003_8g      ",
	    "  4_3299_8      ",
	    " (.1_,,]9.g     ",
	    " e|[_222]#:     ",
	    " }b=|2229#:     ",
	    " fc=+b.###!     ",
	    "  ~%+*&1_4>     ",
	    "  66|/b.4$>)    ",
	    "    6f-( ;<aa   ",
	    "          <<aa  ",
	    "           {<aa ",
	    "            {@^)",
	    "             {{ ",
	    "                " ]
    end
end
